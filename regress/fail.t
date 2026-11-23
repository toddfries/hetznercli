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

# purpose: regress Robot error classification
# usage: prove regress/fail.t
# exit codes: 0 all assertions passed, non-zero a test failed

use strict;
use warnings;

use FindBin;
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Fail;

my $missing = Hetznercli::Fail::classify({
	error => { status => 404, code => 'NOT_FOUND', message => 'none' },
});
is($missing->{exit}, 2, 'a 404 exits 2');
is($missing->{code}, 'NOT_FOUND', '404 keeps its code');

my $bad = Hetznercli::Fail::classify({
	error => { status => 400, code => 'INVALID_INPUT', message => 'from' },
});
is($bad->{exit}, 1, 'a 400 exits 1');
is($bad->{message}, 'from', '400 keeps its message');

ok(!defined(Hetznercli::Fail::classify([])), 'an array is data');
ok(!defined(Hetznercli::Fail::classify({ traffic => {} })), 'a document is data');
ok(!defined(Hetznercli::Fail::classify(undef)), 'undef is not an error document');

done_testing();
