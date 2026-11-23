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

# purpose: regress the pure subs in hcli (recurse_dump, addvar)
# usage: prove regress/hcli-funcs.t
# exit codes: 0 all assertions passed, non-zero a test failed

use strict;
use warnings;
use FindBin;
use Data::Dumper;
use Test::More;

our $argc;

my $root = "$FindBin::Bin/..";
my $hcli = "$root/hcli";

open my $fh, '<', $hcli or die "open $hcli: $!";
local $/;
my $src = <$fh>;
close $fh;

my $dump_src = extract_sub($src, 'recurse_dump');
my $add_src = extract_sub($src, 'addvar');

eval "no strict 'vars'; $dump_src; $add_src; 1" or die $@;

$argc = 0;
is(addvar('search', 'Ent'), '?search=Ent', 'first addvar starts the query');
is(addvar('min_memory_size', 48), '&min_memory_size=48', 'later addvar joins with &');
is(addvar('min_cpu_benchmark', 5682), '&min_cpu_benchmark=5682', 'third addvar keeps counting');
is(addvar('search', 'a b'), '&search=a b', 'addvar does not escape');

my $dump = recurse_dump({ b => 1, a => [3, 2] });
like($dump, qr/\$VAR1\s*=/, 'recurse_dump uses Data::Dumper VAR1 form');
my $apos = index($dump, "'a'");
my $bpos = index($dump, "'b'");
ok($apos >= 0 && $bpos > $apos, 'recurse_dump sorts keys');
like($dump, qr/\[\s*3,\s*2\s*\]/s, 'recurse_dump keeps array order');

my $check = `$^X -c $hcli 2>&1`;
if ($check =~ /Can't locate WWW\/Hetzner\.pm/) {
	ok(1, 'hcli still needs WWW::Hetzner, which is not installed');
} elsif ($check =~ /syntax OK/) {
	ok(1, 'hcli compiles');
} else {
	ok(0, "unexpected perl -c hcli: $check");
}

done_testing();

sub extract_sub {
	my ($text, $name) = @_;
	my $token = "sub $name {";
	my $start = index($text, $token);
	die "no sub $name in hcli" if $start < 0;
	my $i = index($text, '{', $start);
	my $depth = 0;
	for (my $j = $i; $j < length($text); $j++) {
		my $c = substr($text, $j, 1);
		$depth++ if $c eq '{';
		$depth-- if $c eq '}';
		if ($depth == 0) {
			return substr($text, $start, $j - $start + 1);
		}
	}
	die "unbalanced sub $name";
}
