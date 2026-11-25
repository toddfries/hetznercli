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

# purpose: regress auction stats and the IPv6-only order form
# usage: prove regress/market.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# This file does not POST.

use strict;
use warnings;

use FindBin;
use POSIX qw(strftime);
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Market;

my $p = {
	id => 282323,
	name => 'SB109',
	datacenter => 'FSN1-DC4',
	cpu => 'Intel Core i7 980x',
	cpu_benchmark => 8944,
	memory_size => 24,
	hdd_size => 120,
	hdd_count => 2,
	hdd_text => 'ENT.HDD ECC INIC',
	description => ['2x SSD 120 GB SATA'],
	price => '91.6000',
	price_hourly => '0.1468',
	price_setup => '0.0000',
	traffic => '20 TB',
	next_reduce_date => '2018-05-01 12:22:00',
	next_reduce => 3600,
	network_speed => '100 Mbit/s',
};

ok(Hetznercli::Market::keep($p, { cpu => 8000, mem => 16, disk => 200 }),
	'a server above the floors is kept');
ok(!Hetznercli::Market::keep($p, { cpu => 9000, mem => 16, disk => 200 }),
	'a bench below the floor is dropped');
ok(!Hetznercli::Market::keep($p, { disk => 1000 }),
	'disk below the floor is dropped');
ok(!Hetznercli::Market::keep(undef, {}), 'a missing product is dropped');

my $now = 1_700_000_000;
my $line = Hetznercli::Market::format_row($p, $now);
my $nextr = strftime('%m%d %H:%M', localtime($now + 3600));
like($line, qr/FSN1-4/, 'datacenter column shortens DC');
like($line, qr/\b282323\b/, 'product id');
like($line, qr/\b240\b/, 'disk total is count times size');
like($line, qr/\Q$nextr\E/, 'next reduce is local time from now');
like($line, qr/390\.82667/, 'EUR/TB has five digits after the dot');

my $wide = {
	%{ $p },
	id => 2799696,
	name => 'Server Auction',
	datacenter => 'FSN1-DC14',
	cpu => 'Intel Xeon E5-1650 v3',
	cpu_benchmark => 15463,
	memory_size => 64,
	hdd_size => 512,
	hdd_count => 4,
	price => '66.38',
	traffic => 'unlimited',
};
my $table = Hetznercli::Market::format_table([$wide, $p], $now);
my @rows = split /\n/, $table;
my ($header, $first, $second) = @rows;
is(index($header, 'DC'), index($first, 'FSN1-14'), 'DC header sits on the datacenter');
is(index($header, 'sys'), index($first, 'Server Auction'), 'sys header sits on the name');
is(index($header, 'next'), index($first, $nextr), 'next header sits on the drop time');
is(rindex($header, 'TB'), index($first, 'unlimited'), 'TB header sits on the traffic');
is(index($header, 'CPU info'), index($first, 'Intel Xeon E5-1650 v3'),
	'CPU info header sits on the cpu');
is(index($second, 'SB109'), index($header, 'sys'), 'a shorter name stays under sys');
is(index($second, 'Intel Core i7 980x'), index($header, 'CPU info'),
	'cpu text starts in the same column');

sub _end {
	my ($text, $token) = @_;
	my $at = index($text, $token);
	return -1 if $at < 0;
	return $at + length($token);
}
is(_end($header, 'prodid'), _end($first, '2799696'), 'prodid header ends on the id');
is(_end($header, 'bench'), _end($first, '15463'), 'bench header ends on the benchmark');
is(_end($header, 'disk'), _end($first, '2048'), 'disk header ends on the disk total');
is(_end($header, 'MEM'), _end($first, '64'), 'MEM header ends on the memory');
is(_end($header, 'EUR'), _end($first, '66.38'), 'EUR header ends on the price');
is(_end($header, 'EUR/TB'), _end($first, '33.19000'), 'EUR/TB header ends on the rate');
is(_end($header, 'EUR/TB'), _end($second, '390.82667'),
	'the second row rate ends on EUR/TB');

my $per = Hetznercli::Market::price_per_tb($p);
is(sprintf('%.2f', $per), '390.83', 'price per tebibyte of 240 GB');
ok(!defined(Hetznercli::Market::price_per_tb({ price => 10, hdd_count => 0 })),
	'no disk has no price per TB');

my $stats = Hetznercli::Market::stats($p);
like($stats, qr/^282323 SB109 FSN1-DC4\n/, 'stats lead with id, name, datacenter');
like($stats, qr/bench 8944/, 'stats include the benchmark');
like($stats, qr/2x SSD 120 GB SATA/, 'stats include the description');
like($stats, qr/price per TB 390\.83 EUR/, 'stats include price per TB');
like($stats, qr/next reduce 2018-05-01 12:22:00 \(3600\)/, 'stats include the next drop');

my $built = Hetznercli::Market::order_form(282323,
	'15:28:b0:03:95:f0:77:b3:10:56:15:6b:77:22:a5:bb', 1);
ok(!$built->{error}, 'a rehearsal form builds') or diag($built->{error});
my $form = $built->{form};
is($form->{product_id}, 282323, 'product id');
is($form->{'authorized_key[]'},
	'15:28:b0:03:95:f0:77:b3:10:56:15:6b:77:22:a5:bb', 'stored fingerprint');
is($form->{test}, 'true', 'test=true is the rehearsal');
ok(!exists($form->{password}), 'no password field');
ok(!exists($form->{comment}), 'no comment field');
ok(!exists($form->{'addon[]'}), 'no addon field');
ok(!grep(/addon/, keys %{ $form }), 'the primary ipv4 addon is absent');

my $live = Hetznercli::Market::order_form(282323, 'aa:bb', 0);
ok(!exists($live->{form}{test}), 'a real order omits test');
like(Hetznercli::Market::order_text($live->{form}),
	qr/IPv6-only form/, 'the printed form says ipv6-only');
ok(Hetznercli::Market::order_form(282323, '', 0)->{error},
	'an empty fingerprint is refused');

my @keys = Hetznercli::Market::key_rows([
	{ key => { name => 'rsa', type => 'RSA', fingerprint => '23:ee' } },
	{ key => { name => 'ed', type => 'ED25519', fingerprint => '2e:24' } },
]);
is(scalar @keys, 2, 'wrapped key rows unwrap');
is(Hetznercli::Market::recommend_key(\@keys)->{fingerprint}, '2e:24',
	'an ED25519 key is the recommendation');

my $edge = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts(
		'disk=100:200', 'price=10:40', 'disk.count=2:4'),
	{});
ok(!$edge->{error}, 'a range parses') or diag($edge->{error});
my $bounds = $edge->{keep};
my $keep100 = { price => 20, hdd_count => 2, hdd_size => 50,
	hdd_text => 'ENT.HDD ECC INIC', cpu => 'x' };
my $keep200 = { price => 20, hdd_count => 2, hdd_size => 100,
	hdd_text => 'ENT.HDD ECC INIC', cpu => 'x' };
ok(Hetznercli::Market::keep($keep100, $bounds), 'disk 100 is inside the range');
ok(Hetznercli::Market::keep($keep200, $bounds), 'disk 200 is inside the range');
ok(!Hetznercli::Market::keep({ %$keep100, hdd_size => 49 }, $bounds),
	'disk 98 is below the range');
ok(!Hetznercli::Market::keep({ %$keep100, hdd_size => 101 }, $bounds),
	'disk 202 is above the range');
ok(!Hetznercli::Market::keep({ %$keep100, hdd_count => 1, hdd_size => 100 }, $bounds),
	'one disk is below the count range');

my $tighter = Hetznercli::Market::parse_opts(
	'disk.min=50', 'disk.min=80', 'disk.max=300', 'disk.max=250',
	'price.max=40', 'price.max=15');
is($tighter->{disk_min}, 80, 'a later disk minimum only rises');
is($tighter->{disk_max}, 250, 'a later disk maximum only falls');
is($tighter->{price_max}, 15, 'a later price maximum only falls');
ok(Hetznercli::Market::parse_opts('disk=200:100')->{error},
	'a backward disk range is refused');

my $memr = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('mem=24:64'), {});
ok(!$memr->{error}, 'a mem range parses') or diag($memr->{error});
ok(Hetznercli::Market::keep({ memory_size => 24 }, $memr->{keep}),
	'mem 24 is inside the range');
ok(Hetznercli::Market::keep({ memory_size => 64 }, $memr->{keep}),
	'mem 64 is inside the range');
ok(!Hetznercli::Market::keep({ memory_size => 23 }, $memr->{keep}),
	'mem 23 is below the range');
ok(!Hetznercli::Market::keep({ memory_size => 65 }, $memr->{keep}),
	'mem 65 is above the range');
my $mtight = Hetznercli::Market::parse_opts(
	'mem.min=16', 'mem.min=32', 'mem.max=128', 'mem.max=64');
is($mtight->{mem_min}, 32, 'a later mem minimum only rises');
is($mtight->{mem_max}, 64, 'a later mem maximum only falls');
ok(Hetznercli::Market::parse_opts('mem=64:16')->{error},
	'a backward mem range is refused');
ok(Hetznercli::Market::parse_opts('mem.min=64,mem.max=32')->{error},
	'comma form still refuses mem min above max');

my $both = Hetznercli::Market::parse_opts('re=ECC', 're=ENT');
ok(Hetznercli::Market::keep($p, $both), 'ECC and ENT both match the fixture');
ok(!Hetznercli::Market::keep({ %$p, hdd_text => 'ECC desktop', description => [] }, $both),
	'a second re drops a row that misses ENT');
my $either = Hetznercli::Market::parse_opts('re=(ECC|ENT)');
ok(Hetznercli::Market::keep({ %$p, hdd_text => 'desktop ECC', description => [] }, $either),
	'one re with a bar keeps either tag');
ok(Hetznercli::Market::parse_opts('re=(')->{error}, 'a broken re is refused');
like(Hetznercli::Market::parse_opts('format=custom:%s')->{error},
	qr/not implemented/, 'custom format is reserved');

my $csv = Hetznercli::Market::parse_opts(
	'format=price,disk.min=4096,re=ECC,re=ENT');
ok(!$csv->{error}, 'comma-separated -o pairs parse') or diag($csv->{error});
is($csv->{format}, 'price', 'comma form sets format');
is($csv->{disk_min}, 4096, 'comma form sets disk.min');
is(scalar @{ $csv->{re} }, 2, 'comma form keeps two AND patterns');
ok(Hetznercli::Market::keep($p, $csv), 're=ECC,re=ENT still requires both');
ok(!Hetznercli::Market::keep({ %$p, hdd_text => 'ECC desktop', description => [] }, $csv),
	'comma form still drops a row that misses ENT');
my $inre = Hetznercli::Market::parse_opts('re=foo,bar');
ok(!$inre->{error}, 'a comma inside a regex parses') or diag($inre->{error});
is(scalar @{ $inre->{re} }, 1, 'a comma in a regex stays in the pattern');
ok(Hetznercli::Market::keep({ hdd_text => 'foo,bar', cpu => '', description => [] }, $inre),
	'the regex with a comma matches that haystack');

my $priced = Hetznercli::Market::format_price([$p], $now);
like($priced, qr/ServerID\s+GB\s+GB\s+Price/, 'price format uses the hmarket header');
like($priced, qr/\b282323\b/, 'price format prints the id');
like($priced, qr/\b24\b/, 'price format prints the RAM');
like($priced, qr/\b240\b/, 'price format prints the disk total');
like($priced, qr/\b2\b/, 'price format prints the disk count');
like($priced, qr/381\.667/, 'price format uses three decimal terabyte digits');
my $aka = strftime('%Y%m%d %H:%M:%S', localtime($now + 3600));
like($priced, qr/ 0d  1:00:00 aka \Q$aka\E/, 'price format counts down to the drop');
my $fixed = Hetznercli::Market::format_price([{
	%$p, next_reduce => 0, fixed_price => 1,
}], $now);
like($fixed, qr/fixed aka/, 'a stopped auction prints fixed');
my $reload = Hetznercli::Market::format_price([{
	%$p, next_reduce => 0, fixed_price => 0,
}], $now);
like($reload, qr/reload aka/, 'a past drop without a fixed price prints reload');

my $merged = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('disk.min=1000', 'disk.max=5000'),
	{ disk => 4096 });
is($merged->{keep}{disk}, 4096, 'the CLI disk floor wins when it is higher');
ok(Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('disk.max=1000'),
	{ disk => 4096 })->{error},
	'a CLI floor above disk.max is refused');
my $mraised = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('mem.min=16', 'mem.max=128'),
	{ mem => 48 });
is($mraised->{keep}{mem}, 48, 'the CLI RAM floor wins when it is higher');
ok(Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('mem.max=32'),
	{ mem => 48 })->{error},
	'a CLI RAM floor above mem.max is refused');

my $by_tb = Hetznercli::Market::sort_products([
	{ id => 2, price => 20, hdd_count => 1, hdd_size => 1024 },
	{ id => 1, price => 10, hdd_count => 1, hdd_size => 1024 },
	{ id => 3, price => 1, hdd_count => 0, hdd_size => 0 },
], 'eur/tb');
is($by_tb->[0]{id}, 1, 'eur/tb sort puts the cheaper tebibyte first');
is($by_tb->[1]{id}, 2, 'eur/tb sort keeps the dearer tebibyte second');
is($by_tb->[2]{id}, 3, 'a row with no disk sorts last');
my $desc = Hetznercli::Market::sort_products([
	{ id => 1, price => 10 },
	{ id => 2, price => 20 },
], '-price');
is($desc->[0]{id}, 2, 'a leading minus sorts high price first');
is(Hetznercli::Market::parse_opts('sort=cost_per_tb')->{sort}, 'cost_per_tb',
	'cost_per_tb is a sort alias');
is(Hetznercli::Market::parse_opts('sort=price', 'sort=mem')->{sort}, 'mem',
	'a later sort replaces an earlier one');
ok(Hetznercli::Market::parse_opts('sort=nope')->{error}, 'an unknown sort is refused');
my $from_O = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts(),
	{ sort => 'mem' });
is($from_O->{sort}, 'mem', 'CLI -O fills sort when -o sort is absent');
my $wins = Hetznercli::Market::merge_cli(
	Hetznercli::Market::parse_opts('sort=price'),
	{ sort => 'mem' });
is($wins->{sort}, 'price', '-o sort wins over -O');

is(Hetznercli::Market::cache_ttl([
	{ product => { next_reduce => 60 } },
	{ product => { next_reduce => 4000 } },
]), 60, 'cache ttl is the soonest timer');
is(Hetznercli::Market::cache_ttl([
	{ product => { next_reduce => 4000 } },
]), 1800, 'cache ttl caps at 30 minutes');
is(Hetznercli::Market::cache_ttl([
	{ product => { next_reduce => 0 } },
]), 0, 'a timer at zero makes the cache expire');
is(Hetznercli::Market::cache_ttl([{}]), 1800,
	'a list with no timer uses 30 minutes');

my $cachedir = "/tmp/hcli-cache-$$";
mkdir $cachedir, 0700 or die "mkdir $cachedir: $!";
my $payload = [{ product => { id => 7, next_reduce => 120 } }];
ok(Hetznercli::Market::cache_save($payload, 1_700_000_000, $cachedir),
	'the market list is written to the cache');
my $hit = Hetznercli::Market::cache_load(1_700_000_010, $cachedir);
ok($hit && $hit->[0]{product}{id} == 7, 'a fresh cache is reused');
ok(!Hetznercli::Market::cache_load(1_700_000_130, $cachedir),
	'the cache expires when the timer would reach zero');
unlink Hetznercli::Market::cache_file($cachedir);
rmdir $cachedir;

my $preset = $ENV{HOME} . '/git/sw/hetznercli';
foreach my $sh (qw(hmktst hmktvm hmktvm-picky)) {
	open my $fh, '<', "$preset/$sh" or die "open $sh: $!";
	local $/;
	my $body = <$fh>;
	close $fh;
	unlike($body, qr/hmarket/, "$sh does not call hmarket");
	unlike($body, qr/(?:^|\s)-O(?:\s|=|$)/m, "$sh does not use deprecated -O");
	like($body, qr/-p market\b/, "$sh calls hcli market");
	like($body, qr/format=price/, "$sh asks for the price table");
	like($body, qr/re=ECC,re=ENT/, "$sh ANDs ECC and ENT in one -o");
	like($body, qr/-o [^\n]+,/, "$sh collapses -o pairs with commas");
}

done_testing();
