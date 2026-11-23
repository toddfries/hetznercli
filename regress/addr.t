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

# purpose: regress public v6 inference from a Robot /64
# usage: prove regress/addr.t
# exit codes: 0 all assertions passed, non-zero a test failed
#
# No name lookup.

use strict;
use warnings;

use FindBin;
use Test::More;
use lib "$FindBin::Bin/../lib";
use Hetznercli::Addr;

is(Hetznercli::Addr::host_from_prefix('2a01:4f8:2190:1993::'),
	'2a01:4f8:2190:1993::2', 'pxj prefix');
is(Hetznercli::Addr::host_from_prefix('2a01:4f8:13b:1995::/64'),
	'2a01:4f8:13b:1995::2', 'a different prefix with a mask');
ok(!defined(Hetznercli::Addr::host_from_prefix(undef)), 'missing prefix');
ok(!defined(Hetznercli::Addr::host_from_prefix('')), 'empty prefix');

is(Hetznercli::Addr::host_from_server({
	server_ipv6_net => '2a01:4f8:2190:1993::',
}), '2a01:4f8:2190:1993::2', 'server_ipv6_net');

is(Hetznercli::Addr::host_from_server({
	server => { server_ipv6_net => '2a01:4f8:13b:1995::' },
}), '2a01:4f8:13b:1995::2', 'wrapped server object');

is(Hetznercli::Addr::host_from_server({
	subnet => [
		{ ip => '2a01:4f8:2190:1993::', mask => 64 },
	],
}), '2a01:4f8:2190:1993::2', 'subnet mask 64 when the net field is absent');

is(Hetznercli::Addr::host_from_server({
	subnet => [
		{ subnet => { ip => '2a01:4f8:13b:1995::', mask => '64' } },
	],
}), '2a01:4f8:13b:1995::2', 'wrapped subnet and a string mask');

ok(!defined(Hetznercli::Addr::host_from_server({ subnet => [] })),
	'no prefix means no address');
ok(!defined(Hetznercli::Addr::host_from_server({
	subnet => [{ ip => '192.0.2.0', mask => 24 }],
})), 'an address that is not a /64 is not the host');

done_testing;
