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

# purpose: regress disk specs, including a host that is not pxj
# usage: prove regress/layout.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# Fixtures are local. This file does not create a pool.

use strict;
use warnings;

use FindBin;
use JSON::PP ();
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Layout;
use Hetznercli::Kvm;

my $dir = "$FindBin::Bin/fixtures";

sub load {
	my ($name) = @_;
	open my $fh, '<', "$dir/$name" or die $!;
	local $/;
	return JSON::PP->new->decode(scalar <$fh>);
}

my $pxj = Hetznercli::Layout::plan(load('pxj-inventory.json'), load('pxj-spec.json'));
ok(!$pxj->{error}, 'pxj spec plans') or diag($pxj->{error});
is($pxj->{hdsize}, '512G', 'pxj hdsize');
is_deeply($pxj->{install_disks}, ['/dev/nvme0n1', '/dev/nvme1n1'],
	'pxj install disks are the two nvme');
is(scalar @{ $pxj->{data_disks} }, 14, 'pxj data disks are the fourteen hdds');
ok(!grep(m{/nvme}, @{ $pxj->{data_disks} }), 'nvme are not data disks');
is($pxj->{level}, 'raidz2', 'pxj level');
is($pxj->{special}, 1, 'pxj names a special mirror');

my @tails = ('/dev/disk/by-id/nvme-fixture-0-part4',
	'/dev/disk/by-id/nvme-fixture-1-part4');
my $pool = Hetznercli::Layout::zpool_command($pxj, \@tails);
ok(!$pool->{error}, 'pxj zpool') or diag($pool->{error});
my @z = @{ $pool->{argv} };
is($z[0], 'zpool', 'zpool command');
ok((grep { $_ eq 'raidz2' } @z), 'raidz2');
ok((grep { $_ eq 'special' } @z), 'special');
ok((grep { $_ eq 'mirror' } @z), 'special is a mirror');
ok((grep { $_ eq $tails[0] } @z), 'first tail');
ok((grep { $_ eq $tails[1] } @z), 'second tail');
foreach my $disk (@{ $pxj->{data_disks} }) {
	ok((grep { $_ eq $disk } @z), "pool contains $disk");
}
ok(!grep({ $_ eq 'cache' } @z), 'no cache device');
ok(!grep({ $_ eq 'log' } @z), 'no log device');
ok(!grep(/special_small_blocks/, join(' ', @z)), 'small blocks stay off');

my $need_tails = Hetznercli::Layout::zpool_command($pxj, []);
like($need_tails->{error}, qr/two tail/, 'special mirror without tails is refused');

my $check = Hetznercli::Layout::checklist($pxj);
like($check, qr/hdsize: 512G/, 'checklist names hdsize');
like($check, qr/special_small_blocks stays unset/, 'checklist leaves small blocks unset');
like($check, qr/Set reverse DNS on the host v6/, 'checklist sets reverse DNS');
like($check, qr/host name plus \.rescue/, 'checklist names the rescue ssh alias');
like($check, qr/Pin the physical NIC by PCI path/, 'checklist pins the NIC');
like($check, qr/~\/\.config\/hetzner\/todd\.conf/, 'checklist reads the todd hash file');

my @kvm = Hetznercli::Kvm::argv(
	disks => $pxj->{install_disks},
	iso => '/tmp/proxmox-ve_9.2-1-serial.iso',
);
my $kvm = join(' ', @kvm);
like($kvm, qr{/dev/nvme0n1}, 'kvm sees nvme0');
like($kvm, qr{/dev/nvme1n1}, 'kvm sees nvme1');
unlike($kvm, qr{/dev/sd}, 'kvm does not see the hdds');

my $small = Hetznercli::Layout::plan(
	load('small-inventory.json'), load('small-spec.json'));
ok(!$small->{error}, 'small spec plans') or diag($small->{error});
is_deeply($small->{install_disks}, ['/dev/disk/by-id/ata-small-a'],
	'small host installs to one disk');
is($small->{special}, 0, 'small spec has no special role');
is_deeply($small->{data_disks}, [], 'small spec has no data pool');
my $small_pool = Hetznercli::Layout::zpool_command($small, []);
is_deeply($small_pool->{argv}, [], 'small zpool line is empty');
my @small_kvm = Hetznercli::Kvm::argv(
	disks => $small->{install_disks},
	iso => '/tmp/proxmox-ve_9.2-1-serial.iso',
);
isnt(join(' ', @small_kvm), $kvm, 'a different layout produces a different kvm line');

my $spare = Hetznercli::Layout::plan(load('pxj-inventory.json'), {
	install => { role => 'mirror', match => 'nvme', hdsize => '512G' },
	data => { level => 'raidz2', match => 'rest', spare => 1 },
});
like($spare->{error}, qr/spare/, 'a spare request is refused');

my $missing = Hetznercli::Layout::plan(load('small-inventory.json'), {
	install => { role => 'single', disks => ['/dev/sdz'] },
});
like($missing->{error}, qr{/dev/sdz}, 'a missing disk is refused');

my $cache = Hetznercli::Layout::plan(load('pxj-inventory.json'), {
	install => { role => 'mirror', match => 'nvme', hdsize => '512G' },
	data => { level => 'raidz2', match => 'rest', spare => 0, special => 'cache' },
});
like($cache->{error}, qr/unknown special/, 'cache is not a special role');

done_testing;
