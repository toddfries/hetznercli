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

# purpose: regress the bring-online plan
# usage: prove regress/bring.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# This file does not edit ssh config and does not ssh.

use strict;
use warnings;

use FindBin;
use File::Temp qw(tempfile);
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Bring;

my $pxj = Hetznercli::Bring::plan(name => 'pxj', hash_status => 'ok');
like($pxj->{text}, qr/HostKeyAlias pxj\.fdh\.bz\.rescue/, 'rescue alias');
like($pxj->{text}, qr/HostKeyAlias pxj\.fdh\.bz\n/, 'installed alias');
like($pxj->{text}, qr/pxj is already done/, 'pxj is not run again');
unlike($pxj->{text}, qr/\$2[aby]\$/, 'the plan does not print a hash');

my $pxk = Hetznercli::Bring::plan(
	name => 'pxk.fdh.bz',
	pci => 'pci-0000:06:00.0',
	nic => 'eno2',
	hash_status => 'ok',
);
ok(!$pxk->{finished}, 'another host is not finished');
like($pxk->{text}, qr/KERNELS=="0000:06:00.0"/, 'udev matches the pci path');
like($pxk->{text}, qr/Path=pci-0000:06:00.0/, 'link file uses the pci path');
like($pxk->{text}, qr/domains=pxk\.fdh\.bz/, 'certificate names the host');
like($pxk->{text}, qr/postmaster\@fdh\.bz/, 'certificate contact');
unlike($pxk->{text}, qr/already done/, 'another host is still pending');

my $need = Hetznercli::Bring::nic_text('pxk', undef, undef);
like($need, qr/Pass -g/, 'a pin without a pci path says so');

ok(Hetznercli::Bring::ssh_present($pxj->{text}, 'pxj'), 'the pxj plan contains its aliases');
my $merged = Hetznercli::Bring::merge_ssh("Host other\n", 'pxk');
is($merged->{status}, 'appended', 'a new alias is appended');
like($merged->{text}, qr/Host r\.pxk\.res/, 'the rescue host is in the append');
my $again = Hetznercli::Bring::merge_ssh($merged->{text}, 'pxk');
is($again->{status}, 'present', 'a second merge does not duplicate');
is($again->{text}, $merged->{text}, 'present text stays put');

is(Hetznercli::Bring::hash_status('/no/such/todd.conf'), 'missing', 'missing hash file');
my ($fh, $path) = tempfile(UNLINK => 1);
print $fh "hash = \$2b\$10\$abcdefghijklmnopqrstuv\n";
close $fh;
is(Hetznercli::Bring::hash_status($path), 'ok', 'a bcrypt line is accepted');
my $shown = Hetznercli::Bring::plan(name => 'pxk', hash_status => 'ok');
unlike($shown->{text}, qr/abcdefghijklmnopqrstuv/, 'the plan omits the hash');

my ($badfh, $badpath) = tempfile(UNLINK => 1);
print $badfh "hash = secret\n";
close $badfh;
is(Hetznercli::Bring::hash_status($badpath), 'bad', 'a plain secret is refused');

my $pub = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmIrgUeyl7qBhiMZmfnACOQsyPGqSFz9+ooF99vN/1N todd@i5.fries.net';
my $remote = Hetznercli::Bring::todd_remote($pub);
like($remote, qr/chpasswd -e/, 'todd setup uses chpasswd -e');
like($remote, qr/read -r hash/, 'the hash arrives on stdin');
like($remote, qr/'\$2a\$'\*/, 'the bcrypt check is a shell pattern');
unlike($remote, qr/\$2b\$10\$/, 'the remote script has no hash value');
is(Hetznercli::Bring::todd_remote('not a key'), '', 'a bad key is refused');

my $acme = Hetznercli::Bring::acme_script('pxk');
like($acme, qr/certificate already issued/, 'an existing certificate stops the order');
like($acme, qr/pvenode acme cert order/, 'the order command is present');
like($acme, qr/postmaster\@fdh\.bz/, 'the account contact is postmaster');

ok(Hetznercli::Bring::normalize('PXJ')->{name} eq 'pxj', 'the short name is lowered');
ok(Hetznercli::Bring::normalize('')->{error}, 'an empty name is refused');

done_testing();
