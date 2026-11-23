#!/usr/bin/perl
# Copyright (c) 2026 Todd T. Fries <todd@fries.net>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# purpose: regress vSwitch membership delta, interface render, and lan pick
# usage: prove regress/vswitch.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# Fixtures are local. This file does not POST.

use strict;
use warnings;

use FindBin;
use JSON::PP ();
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Vswitch;

my $dir = "$FindBin::Bin/fixtures";

sub slurp {
	my ($path) = @_;
	open my $fh, '<', $path or die $!;
	local $/;
	return scalar <$fh>;
}

my $rows = JSON::PP->new->decode(slurp("$dir/vswitches.json"));
my @miss = Hetznercli::Vswitch::missing($rows, 2424209, 3119434);
is(scalar @miss, 5, 'target is missing the five reference vSwitches');
is($miss[0]{id}, 9352, 'first missing id');
is($miss[4]{vlan}, 4004, 'vlan 4004 is in the Robot set');
ok(!grep({ $_->{id} == 1 } @miss), 'a vSwitch the reference is not on is not proposed');

my @unknown = Hetznercli::Vswitch::unknown_membership([
	{ id => 9352, vlan => 4000, name => 'Internal storage' },
]);
is_deeply(\@unknown, [9352], 'a list row with no server array is unknown');
is(scalar Hetznercli::Vswitch::unknown_membership($rows), 0,
	'a row with a server array is known');

my @detail = Hetznercli::Vswitch::missing([{
	id => 9352, vlan => 4000, name => 'Internal storage',
	server => [
		{ server_ip => undef, server_number => 2424209, status => 'ready' },
		{ server_ip => undef, server_number => 558374, status => 'ready' },
	],
}], 2424209, 3119434);
is($detail[0]{id}, 9352, 'detail membership uses server_number');

$rows->[0]{server} = [
	@{ $rows->[0]{server} },
	{ server_number => 3119434 },
];
my @left = Hetznercli::Vswitch::missing($rows, 2424209, 3119434);
ok(!grep({ $_->{id} == 9352 } @left), 'an existing membership is not proposed again');
is(scalar @left, 4, 'the other four remain');

my $rendered = Hetznercli::Vswitch::render(slurp("$dir/pxi-interfaces"), {
	nic => 'enp6s0',
	public_v6 => '2a01:4f8:2190:1993::2',
	lan_addr => '10.10.0.18',
});
ok(!$rendered->{error}, 'render') or diag($rendered->{error});
my $text = $rendered->{text};
like($text, qr/bridge-ports enp6s0/, 'target nic');
like($text, qr/address 2a01:4f8:2190:1993::2\/64/, 'target public v6');
like($text, qr/address 10\.10\.0\.18\/24/, 'target lan address');
like($text, qr/address fe80::2\/32/, 'link-local address');
like($text, qr/gateway fe80::1/, 'link-local gateway');
like($text, qr/vmbr4000/, 'vlan 4000 bridge');
like($text, qr/vmbr4001/, 'vlan 4001 bridge');
like($text, qr/vmbr4002/, 'vlan 4002 bridge');
like($text, qr/vmbr4003/, 'vlan 4003 bridge');
unlike($text, qr/vmbr4004/, 'vlan 4004 has no iface on the reference');
unlike($text, qr/ens18/, 'qemu user-net iface is not copied');
unlike($text, qr/10\.0\.2\.15/, 'qemu user-net address is not copied');
unlike($text, qr/enp0s31f6/, 'reference nic is not copied');
unlike($text, qr/10\.10\.0\.17/, 'reference lan address is not copied');
unlike($text, qr/2a01:4f8:13b:1995/, 'reference public prefix is not copied');
is_deeply($rendered->{vlans}, [qw(4000 4002 4003 4001)],
	'vlan order follows the reference');

my $hosts = <<'EOF';
# vlan4000
10.10.0.7 px7
10.10.0.17 pxi
10.10.0.100 plesk0
EOF
is(Hetznercli::Vswitch::next_lan($hosts, {}), '10.10.0.8',
	'search starts at .7 and skips listed addresses');
is(Hetznercli::Vswitch::next_lan($hosts, { '10.10.0.8' => 1 }), '10.10.0.9',
	'a ping reply rejects an unlisted address');

my $full = join("\n", map { "10.10.0.$_ x" } (7 .. 17));
$full .= "\n10.10.0.100 plesk0\n";
is(Hetznercli::Vswitch::next_lan($full, {}), '10.10.0.18',
	'current hosts file recommends .18');
is(Hetznercli::Vswitch::next_lan($full . "10.10.0.18 pxj\n", {}), '10.10.0.19',
	'a listed address is not reused when the ping is quiet');

done_testing;
