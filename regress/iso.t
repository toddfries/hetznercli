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

# purpose: regress ISO selection and the serial-menu transform
# usage: prove regress/iso.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# Fixtures are local. This file does not download an ISO.

use strict;
use warnings;

use FindBin;
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Iso;

my $dir = "$FindBin::Bin/fixtures";

sub slurp {
	my ($path) = @_;
	open my $fh, '<', $path or die "open $path: $!";
	local $/;
	return scalar <$fh>;
}

my $rec = Hetznercli::Iso::recommend(slurp("$dir/sha256sums"));
is($rec->{recommended}{name}, 'proxmox-ve_9.2-1.iso', 'newest VE iso');
is($rec->{recommended}{sha256},
	'4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c',
	'sha256 from the sums file');
is($rec->{url}, 'https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso',
	'direct iso url');
my @names = map { $_->{name} } @{ $rec->{choices} };
ok(!grep(/arm64/, @names), 'arm64 iso is dropped');
ok(!grep(/mail/, @names), 'non-VE iso is dropped');
is($names[0], 'proxmox-ve_9.2-1.iso', 'choices are newest first');
is($names[1], 'proxmox-ve_9.1-1.iso', '9.1 follows 9.2');
is($names[2], 'proxmox-ve_8.4-1.iso', '8.4 follows 9.1');

my $order = Hetznercli::Iso::recommend(<<'EOF');
aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa  proxmox-ve_9.2-1.iso
bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  proxmox-ve_9.10-1.iso
EOF
is($order->{recommended}{name}, 'proxmox-ve_9.10-1.iso',
	'numeric version order, not string order');

my $html = Hetznercli::Iso::recommend(slurp("$dir/index.html"));
is($html->{recommended}{name}, 'proxmox-ve_9.2-1.iso', 'index html newest VE');
ok(!defined($html->{recommended}{sha256}), 'index html has no hash');
ok(!grep(/arm64/, map { $_->{name} } @{ $html->{choices} }),
	'index html drops arm64');

my $grub = Hetznercli::Iso::serial_grub(slurp("$dir/grub.cfg"));
like($grub, qr/^serial --unit=0 --speed=115200$/m, 'serial unit');
like($grub, qr/^terminal_input serial$/m, 'terminal input');
like($grub, qr/^terminal_output serial$/m, 'terminal output');
like($grub, qr/linux \/boot\/linux26 ro ramdisk_size=16777216 console=ttyS0,115200/,
	'kernel console');
my $again = Hetznercli::Iso::serial_grub($grub);
is(scalar(() = $again =~ /^serial --unit=0 --speed=115200$/mg), 1,
	'serial header is not doubled');
is(scalar(() = $again =~ /console=ttyS0,115200/g), 1,
	'console argument is not doubled');

my @xo = Hetznercli::Iso::xorriso_argv(
	'/tmp/proxmox-ve_9.2-1.iso',
	'/tmp/proxmox-ve_9.2-1-serial.iso',
	'/tmp/grub.cfg',
);
is_deeply(\@xo, [
	'xorriso',
	'-indev', '/tmp/proxmox-ve_9.2-1.iso',
	'-outdev', '/tmp/proxmox-ve_9.2-1-serial.iso',
	'-map', '/tmp/grub.cfg', '/boot/grub/grub.cfg',
	'-boot_image', 'any', 'replay',
], 'xorriso injects the menu and keeps the boot image');

done_testing;
