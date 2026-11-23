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

# purpose: regress hmarket filters, disk-size parsing, and getjson file choice
# usage: prove regress/hmarket.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# Fixtures are local. This file does not contact Hetzner.

use strict;
use warnings;
use FindBin;
use File::Temp qw(tempdir);
use JSON::PP qw(encode_json);
use Date::Manip::Date;
use Test::More;

my $root = "$FindBin::Bin/..";
my $hmarket = "$root/hmarket";

my $check = `$^X -c $hmarket 2>&1`;
like($check, qr/syntax OK/, 'hmarket compiles');

my $past = 1;
my $future = 2000000000;
my $past_aka = aka($past);
my $future_aka = aka($future);

my $fixture = encode_json({ server => [
	srv(1001, 64, 40, 0, $past, 1, ['6.0 TB Enterprise HDD', '6.0 TB Enterprise HDD']),
	srv(1002, 32, 29, 1, $past, 1, ['512 GB Enterprise HDD', '512 GB Enterprise HDD']),
	srv(1003, 64, 20, 0, $past, 1, ['512 GB SSD', '512 GB SSD']),
	srv(1004, 8, 10, 0, $past, 0, ['1 TB Enterprise HDD']),
	srv(1005, 16, 100, 0, $past, 1, ['1.5 TB Enterprise HDD']),
	srv(1006, 128, 50, 0, $future, 1, [
		'2 TB Enterprise HDD', '2 TB Enterprise HDD',
		'2 TB Enterprise HDD', '2 TB Enterprise HDD',
	]),
	srv(1007, 64, 80, 0, $past, 1, ['mystery', '4 TB Enterprise HDD']),
] });

my $dir = tempdir(CLEANUP => 1);
my $jsonxz = write_xz("$dir/market.json", $fixture);

my ($rc, $out) = run($dir, '-o', "jsonfile=$jsonxz");
is($rc, 0, 'default fixture run exits 0');
is_deeply([ids($out)], [qw(1001 1002 1005 1006 1007)],
	'default keeps ecc enterprise disks and drops ssd plus non-ecc');
like($out, qr/disk=mystery !match/, 'unparsed disk text is reported');
my %row = map { $_->{id} => $_ } rows($out);
is($row{1001}{disk}, 12000, 'two 6.0 TB disks sum to 12000 GB');
is($row{1001}{count}, 2, 'two TB disks count as 2');
is($row{1001}{pptb}, pptb(40, 12000), 'price per TB uses parsed GB');
like($row{1001}{line}, qr/reload aka \Q$past_aka\E/, 'past non-fixed stamp says reload');
is($row{1002}{disk}, 1024, 'two 512 GB disks sum to 1024');
is($row{1002}{pptb}, pptb(29, 1024), 'GB disks feed price per TB');
like($row{1002}{line}, qr/fixed aka \Q$past_aka\E/, 'past fixed stamp says fixed');
is($row{1005}{disk}, 1500, '1.5 TB is 1500 GB');
is($row{1005}{count}, 1, 'single disk counts as 1');
is($row{1006}{disk}, 8000, 'four 2 TB disks sum to 8000 GB');
is($row{1006}{count}, 4, 'four disks count as 4');
like($row{1006}{line}, qr/\d+d\s+\d+:\d{2}:\d{2} aka \Q$future_aka\E/,
	'future stamp counts down to the parsed date');

($rc, $out) = run($dir, '-e', 0, '-o', "jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1001 1002 1004 1005 1006 1007)],
	'-e 0 keeps a non-ecc enterprise server');

($rc, $out) = run($dir, '-s', 10000, '-o', "jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1001)], '-s is a minimum parsed storage');

($rc, $out) = run($dir, '-p', 40, '-o', "jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1001 1002)], '-p is a maximum price');

($rc, $out) = run($dir, '-m', 64, '-o', "jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1001 1006 1007)], '-m is a minimum RAM');

($rc, $out) = run($dir, '-c', 4, '-o', "jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1006)], '-c is a minimum disk count');

($rc, $out) = run($dir, '-o', "fixed=1;jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1002)], '-o fixed=1 keeps fixed_price servers');

($rc, $out) = run($dir, '-o', "id=1001,1005;jsonfile=$jsonxz");
is_deeply([ids($out)], [qw(1001 1005)], '-o id= accepts a comma list');
unlike($out, qr/!match/, 'id filter skips other servers before disk parsing');

($rc, $out) = run($dir, '-v', '-o', "id=1001;jsonfile=$jsonxz");
like($out, qr/opening \Q$jsonxz\E/, 'getjson honors -o jsonfile=');
like($out, qr/dc: 'FSN1-DC13' cpu: Test CPU/, 'verbose prints datacenter and cpu');
like($out, qr/id 1001: \$VAR1/, '-o id= turns on the verbose dump');

my $gap = tempdir(CLEANUP => 1);
mkdir "$gap/data" or die $!;
write_xz("$gap/data/0.json", encode_json({ server => [
	srv(2000, 64, 40, 0, $past, 1, ['1 TB Enterprise HDD']),
] }));
write_xz("$gap/data/2.json", encode_json({ server => [
	srv(2002, 64, 40, 0, $past, 1, ['1 TB Enterprise HDD']),
] }));
($rc, $out) = run($gap, '-v');
like($out, qr/opening data\/0\.json\.xz/, 'getjson stops at the first missing index');
is_deeply([ids($out)], [qw(2000)], 'a gap hides the higher snapshot');

my $seq = tempdir(CLEANUP => 1);
mkdir "$seq/data" or die $!;
write_xz("$seq/data/0.json", encode_json({ server => [
	srv(3000, 64, 40, 0, $past, 1, ['1 TB Enterprise HDD']),
] }));
write_xz("$seq/data/1.json", encode_json({ server => [
	srv(3001, 64, 40, 0, $past, 1, ['1 TB Enterprise HDD']),
] }));
($rc, $out) = run($seq, '-v');
like($out, qr/opening data\/1\.json\.xz/, 'getjson reads the highest consecutive snapshot');
is_deeply([ids($out)], [qw(3001)], 'the newest consecutive snapshot is the one shown');

my $empty = tempdir(CLEANUP => 1);
($rc, $out) = run($empty);
ok($rc != 0, 'missing snapshots fail');
like($out, qr/Cant open \.nonexistent/, 'getjson names the missing default file');

($rc, $out) = run($empty, '-o', 'jsonfile=/no/such/market.json.xz');
ok($rc != 0, 'missing -o jsonfile= fails');
like($out, qr/Cant open \/no\/such\/market\.json\.xz/, 'getjson names the requested file');

snapshot_smoke();

for my $sh (qw(hmktst hmktvm hmktvm-picky update_data)) {
	my $path = "$root/$sh";
	if (!-f $path) {
		ok(1, "$sh absent");
		next;
	}
	my $err = `sh -n $path 2>&1`;
	is($?, 0, "$sh passes sh -n");
	is($err, '', "$sh has no shell diagnostics");
}

my $grok = `$^X -c $root/grok-market 2>&1`;
if ($grok =~ /Can't locate Hetzner\/Robot\.pm/) {
	ok(1, 'grok-market still needs Hetzner::Robot, which is not installed');
} elsif ($grok =~ /syntax OK/) {
	ok(1, 'grok-market compiles');
} else {
	ok(0, "unexpected perl -c grok-market: $grok");
}

done_testing();

sub srv {
	my ($id, $ram, $price, $fixed, $ts, $ecc, $hr) = @_;
	return {
		id => $id,
		key => $id,
		name => 'Server Auction',
		ram_size => $ram,
		ram => ["${ram}G"],
		hdd_size => 1,
		hdd_count => scalar(@$hr),
		hdd_arr => $hr,
		hdd_hr => $hr,
		price => $price,
		next_reduce_timestamp => $ts,
		datacenter => '  FSN1-DC13  ',
		is_ecc => $ecc ? JSON::PP::true() : JSON::PP::false(),
		fixed_price => $fixed ? JSON::PP::true() : JSON::PP::false(),
		cpu => 'Test CPU',
		cat_id => 1,
		information => ['NIC 1 Gbit'],
	};
}

sub aka {
	my ($ts) = @_;
	my $d = Date::Manip::Date->new();
	$d->parse_format('%s', $ts);
	return $d->printf('%Y%m%d %H:%M:%S');
}

sub pptb {
	my ($price, $dsize) = @_;
	return sprintf('%.3f', ($price * 1.0) / ($dsize / 1000.0));
}

sub write_xz {
	my ($path, $json) = @_;
	open my $fh, '>', $path or die "write $path: $!";
	print $fh $json;
	close $fh or die $!;
	system('xz', '-f', $path) == 0 or die "xz $path failed";
	return "$path.xz";
}

sub run {
	my ($cwd, @args) = @_;
	my $pid = open(my $fh, '-|');
	die "fork: $!" unless defined $pid;
	if ($pid == 0) {
		chdir $cwd or die "chdir $cwd: $!";
		open STDERR, '>&STDOUT' or die $!;
		exec $^X, $hmarket, @args;
		die "exec: $!";
	}
	local $/;
	my $out = <$fh> // '';
	close $fh;
	return ($? >> 8, $out);
}

sub rows {
	my ($out) = @_;
	my @rows;
	for my $line (split /\n/, $out) {
		next unless $line =~ /^\s*\d+\s/;
		my @f = split ' ', $line;
		push @rows, {
			id => $f[0],
			ram => $f[1],
			disk => $f[2],
			count => $f[3],
			price => $f[4],
			pptb => $f[5],
			line => $line,
		};
	}
	return @rows;
}

sub ids {
	my ($out) = @_;
	return map { $_->{id} } rows($out);
}

sub snapshot_smoke {
	my $n = 0;
	my $highest;
	while (-f "$root/data/$n.json.xz") {
		$highest = "$root/data/$n.json.xz";
		$n++;
	}
	if (!defined $highest) {
		ok(1, 'no local auction snapshots to smoke-test');
		return;
	}
	open my $xz, '-|', 'xzcat', $highest or die "xzcat: $!";
	local $/;
	my $raw = <$xz>;
	close $xz;
	my $doc = JSON::PP->new->decode($raw);
	my $id;
	for my $e (@{ $doc->{server} || [] }) {
		my $hr = join ' ', @{ $e->{hdd_hr} || [] };
		next unless $e->{is_ecc} && $hr =~ /Enterprise HDD/;
		$id = $e->{id};
		last;
	}
	if (!defined $id) {
		ok(1, "no enterprise ecc server in $highest");
		return;
	}
	my ($rc2, $out2) = run($root, '-o', "id=$id");
	is($rc2, 0, "snapshot smoke id $id exits 0");
	is_deeply([ids($out2)], [$id], "snapshot smoke shows server $id");
}
