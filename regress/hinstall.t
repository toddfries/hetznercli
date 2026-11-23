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

# purpose: regress the offline hinstall print
# usage: prove regress/hinstall.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# No network, no Robot write, no kvm.

use strict;
use warnings;

use FindBin;
use Test::More;

my $root = "$FindBin::Bin/..";
my $fix = "$FindBin::Bin/fixtures";

sub run {
	my (@args) = @_;
	my @cmd = ('perl', "$root/hinstall", @args);
	my $pid = open my $fh, '-|';
	die "open: $!" if !defined($pid);
	if ($pid == 0) {
		open STDERR, '>&STDOUT' or exit 127;
		exec @cmd or exit 127;
	}
	local $/;
	my $out = <$fh>;
	close $fh;
	return ($? >> 8, $out // '');
}

my ($rc, $out) = run(
	'--offline',
	'--server', '3119434',
	'--reference', '2424209',
	'--sums', "$fix/sha256sums",
	'--vswitch-file', "$fix/vswitches.json",
	'--inventory', "$fix/pxj-inventory.json",
	'--spec', "$fix/pxj-spec.json",
	'--interfaces', "$fix/pxi-interfaces",
	'--nic', 'enp6s0',
	'--public-v6', '2a01:4f8:2190:1993::2',
	'--lan', '10.10.0.18',
);
is($rc, 0, 'offline print exits 0') or diag($out);
like($out, qr/proxmox-ve_9\.2-1\.iso .* recommended/, 'recommended iso');
like($out, qr/9352 vlan 4000/, 'vSwitch delta');
like($out, qr/not posting vSwitch membership/, 'no post');
like($out, qr/Advanced hdsize: 512G/, 'hdsize checklist');
like($out, qr/kvm: .* -serial tcp:127\.0\.0\.1:2111,server=on,wait=off/, 'kvm line');
unlike($out, qr/ -vnc /, 'printed kvm line has no vnc');
like($out, qr{/dev/nvme0n1}, 'kvm install disk');
unlike($out, qr{kvm:.* /dev/sda}, 'kvm line omits the hdds');
like($out, qr/special mirror/, 'zpool names the special mirror');
my ($zpool) = $out =~ /^(zpool after the tails exist: .*)$/m;
like($zpool, qr/raidz2/, 'zpool level');
unlike($zpool, qr/\bcache\b/, 'zpool has no cache device');
unlike($zpool, qr/\blog\b/, 'zpool has no log device');
like($out, qr/enp6s0/, 'draft nic');
unlike($out, qr/10\.10\.0\.17/, 'draft omits the reference lan address');
like($out, qr/not downloading/, 'no download');
like($out, qr/not starting kvm/, 'no kvm');
unlike($out, qr/posted /, 'did not claim a post');

my ($no, $err) = run('--offline', '--yes-vswitch', '--server', '3119434');
isnt($no, 0, 'offline yes-vswitch is refused');
like($err, qr/not posting/, 'refusal says it did not post');

done_testing;
