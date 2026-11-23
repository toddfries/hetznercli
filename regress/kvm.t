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

# purpose: regress the serial kvm argv
# usage: prove regress/kvm.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# This file does not exec kvm.

use strict;
use warnings;

use FindBin;
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Kvm;

sub drives {
	my (@argv) = @_;
	my @d;
	for (my $i = 0; $i < @argv; $i++) {
		push @d, $argv[$i + 1] if $argv[$i] eq '-drive';
	}
	return @d;
}

my $iso = '/tmp/proxmox-ve_9.2-1-serial.iso';
my @two = Hetznercli::Kvm::argv(
	disks => ['/dev/nvme0n1', '/dev/nvme1n1'],
	iso => $iso,
);
my $line = join(' ', @two);
unlike($line, qr/(^|\s)-vnc(\s|=|$)/, 'no vnc');
like($line, qr/-serial tcp:127\.0\.0\.1:2111,server=on,wait=off/, 'serial');
like($line, qr/-monitor tcp:127\.0\.0\.1:1111,server=on,wait=off/, 'monitor');
like($line, qr/-nographic/, 'nographic');

my @d = drives(@two);
is(scalar(grep { /media=cdrom/ && /index=2/ && /\Q$iso\E/ } @d), 1,
	'cdrom is index 2');
ok((grep { $_ =~ m{file=/dev/nvme0n1,index=0,media=disk} } @d), 'first disk index 0');
ok((grep { $_ =~ m{file=/dev/nvme1n1,index=1,media=disk} } @d), 'second disk index 1');
ok(!grep(/ahci/, @two), 'two disks do not add ahci');
is(scalar(grep { /index=2/ } @d), 1, 'only the cdrom uses index 2');

my @three = Hetznercli::Kvm::argv(
	disks => ['/dev/nvme0n1', '/dev/nvme1n1', '/dev/sda'],
	iso => $iso,
);
my @d3 = drives(@three);
ok((grep { m{file=/dev/sda,index=3,media=disk} } @d3),
	'third disk skips the cdrom index');
ok((grep { $_ eq '-device' } @three), 'third disk uses a device');
is(scalar(grep { $_ eq 'ahci,id=dc0' } @three), 1, 'one ahci bus');
ok((grep { $_ eq 'ide-drive,drive=sdd0,bus=dc0.0' } @three), 'ahci unit 0');
is(scalar(grep { /index=2/ } @d3), 1, 'third disk does not take index 2');

done_testing;
