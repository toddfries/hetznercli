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

# purpose: regress gateway lookup from the subnet list
# usage: prove regress/subnet.t
# exit codes: 0 all assertions passed, non-zero a test failed

use strict;
use warnings;

use FindBin;
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Subnet;

my @rows = Hetznercli::Subnet::rows([
	{ subnet => {
		ip => '2a01:4f8:2190:1993::', mask => 64,
		gateway => 'fe80::1', server_number => 3119434,
	} },
	{ subnet => {
		ip => '168.119.135.192', mask => 27,
		gateway => '168.119.135.193',
	} },
	{ subnet => {
		ip => '10.0.0.0', mask => 29,
		gateway => '10.0.0.1', server_number => 3119434,
	} },
]);

is(scalar @rows, 3, 'wrapped subnet rows unwrap');
is(Hetznercli::Subnet::gateway_for(\@rows, 3119434), 'fe80::1',
	'a /64 gateway wins over another row for the same server');
ok(!defined(Hetznercli::Subnet::gateway_for(\@rows, 1)),
	'an unmatched server has no gateway');
ok(!defined(Hetznercli::Subnet::gateway_for(\@rows, undef)),
	'a missing server number has no gateway');

my @bare = Hetznercli::Subnet::rows([
	{ ip => '2a01:4f8:13b:1995::', mask => '64',
		gateway => 'fe80::2', server_number => 2424209 },
]);
is(Hetznercli::Subnet::gateway_for(\@bare, 2424209), 'fe80::2',
	'a bare row and a string mask still match');

done_testing();
