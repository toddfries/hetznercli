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

package Hetznercli::Kvm;

use strict;
use warnings;

# Index 2 is the CD-ROM. Disk 0 and 1 use 0 and 1. Later disks start at 3.
sub disk_index {
	my ($i) = @_;
	return $i < 2 ? $i : $i + 1;
}

sub argv {
	my (%o) = @_;
	my $disks = $o{disks} || [];
	my $iso = $o{iso};
	die "iso required\n" if !defined($iso) || $iso eq '';
	my $mem = defined($o{mem}) ? $o{mem} : 2048;

	my @argv = (
		'kvm', '-smp', '2', '-usb', '-device', 'usb-tablet', '-no-fd-bootchk',
	);
	my $ahci = 0;
	foreach my $i (0 .. $#$disks) {
		my $idx = disk_index($i);
		my $path = $disks->[$i];
		if ($i < 2) {
			push @argv, '-drive', "file=$path,index=$idx,media=disk,format=raw";
		} else {
			if (!$ahci) {
				push @argv, '-device', 'ahci,id=dc0';
				$ahci = 1;
			}
			my $unit = $i - 2;
			push @argv, '-drive',
				"id=sdd$unit,file=$path,index=$idx,media=disk,format=raw";
			push @argv, '-device', "ide-drive,drive=sdd$unit,bus=dc0.$unit";
		}
	}
	push @argv, '-drive', "file=$iso,index=2,media=cdrom,format=raw";
	push @argv, '-boot', 'once=d,order=c,menu=on';
	push @argv, '-m', $mem;
	push @argv, '-serial', 'tcp:127.0.0.1:2111,server=on,wait=off';
	push @argv, '-monitor', 'tcp:127.0.0.1:1111,server=on,wait=off';
	push @argv, '-nographic';
	push @argv, '-net', 'nic';
	push @argv, '-net',
		'user,hostfwd=tcp::2022-:22,hostfwd=tcp::3022-:2022,hostfwd=tcp::8006-:8006';
	return @argv;
}

1;
