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

# purpose: regress the six-month traffic window and the POST body
# usage: prove regress/traffic.t
# exit codes: 0 all assertions passed, non-zero a test failed

use strict;
use warnings;

use FindBin;
use POSIX qw(mktime);
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Traffic;

my $nov = mktime(0, 0, 12, 23, 10, 2026 - 1900);
my ($from, $to) = Hetznercli::Traffic::span($nov, 6);
is($from, '2026-06', 'November spans back to June');
is($to, '2026-11', 'the span includes the current month');

my $jan = mktime(0, 0, 12, 15, 0, 2026 - 1900);
($from, $to) = Hetznercli::Traffic::span($jan, 6);
is($from, '2025-08', 'January borrows into the previous year');
is($to, '2026-01', 'January is the end of that span');

my $w = Hetznercli::Traffic::window(now => $nov);
is($w->{type}, 'year', 'monthly totals use type=year');
is($w->{from}, '2026-06', 'default from');
is($w->{to}, '2026-11', 'default to');
is($w->{single_values}, 'true', 'months stay split');

my $over = Hetznercli::Traffic::window(from => '2026-01-15', to => '2026-03-02');
is($over->{from}, '2026-01', 'a day override keeps the month');
is($over->{to}, '2026-03', 'the end day keeps the month');
ok(Hetznercli::Traffic::window(from => 'yesterday', to => '2026-01')->{error},
	'a word is not a date');
ok(Hetznercli::Traffic::window(from => '2026-05')->{error},
	'one end is not a window');
ok(Hetznercli::Traffic::window(from => '2026-08', to => '2026-01')->{error},
	'from after to is refused');

my $form = Hetznercli::Traffic::form($w, [{
	prefix => '2a01:4f8:2190:1993::/64',
	ip => '1.2.3.4',
}]);
is_deeply($form->{'subnet[]'}, ['2a01:4f8:2190:1993::'], 'the mask is stripped');
is_deeply($form->{'ip[]'}, ['1.2.3.4'], 'an ipv4 is sent beside the subnet');
is($form->{from}, '2026-06', 'the form keeps the window');

my $text = Hetznercli::Traffic::format({
	traffic => {
		type => 'year', from => '2026-06', to => '2026-11',
		data => {
			'2a01:4f8:2190:1993::/64' => {
				'2026-06' => { in => 1.5, out => 0.25, sum => 1.75 },
				'2026-07' => { in => 2, out => 1, sum => 3 },
			},
		},
	},
}, [{
	label => '3119434 pxj.fdh.bz',
	prefix => '2a01:4f8:2190:1993::',
}]);
like($text, qr/^traffic year 2026-06 .. 2026-11\n/, 'report names the window');
like($text, qr/3119434 pxj\.fdh\.bz 2a01:4f8:2190:1993::\/64/, 'the prefix is labeled');
like($text, qr/2026-06 in 1\.5000 out 0\.2500 sum 1\.7500/, 'June is a row');
like($text, qr/2026-07 in 2\.0000 out 1\.0000 sum 3\.0000/, 'July is a row');

my $sum = Hetznercli::Traffic::format({
	traffic => {
		type => 'year', from => '2026-06', to => '2026-11',
		data => { '1.2.3.4' => { in => 4, out => 1, sum => 5 } },
	},
}, [{ label => '558374 px9.fdh.bz', ip => '1.2.3.4' }]);
like($sum, qr/558374 px9\.fdh\.bz 1\.2\.3\.4/, 'an ipv4 key uses the server label');
like($sum, qr/total in 4\.0000 out 1\.0000 sum 5\.0000/, 'a single triple is a total');

my $empty = Hetznercli::Traffic::format({
	traffic => { type => 'year', from => '2026-06', to => '2026-11', data => [] },
}, [{ label => '3119434 pxj.fdh.bz', prefix => '2a01:4f8:2190:1993::' }]);
like($empty, qr/^traffic year 2026-06 .. 2026-11\n/, 'an empty list keeps the window');
like($empty, qr/3119434 pxj\.fdh\.bz\n\tno samples\n/, 'an empty list is no samples');
unlike($empty, qr/had no data/, 'an empty list is still a reply');

my $partial = Hetznercli::Traffic::format({
	traffic => {
		type => 'year', from => '2026-06', to => '2026-11',
		data => { '1.2.3.4' => { in => 1, out => 1, sum => 2 } },
	},
}, [
	{ label => '558374 px9.fdh.bz', ip => '1.2.3.4' },
	{ label => '3119434 pxj.fdh.bz', prefix => '2a01:4f8:2190:1993::' },
]);
like($partial, qr/3119434 pxj\.fdh\.bz\n\tno samples\n/,
	'a target missing from the reply is named');

done_testing();
