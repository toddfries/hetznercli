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

package Hetznercli::Addr;

use strict;
use warnings;

# Hetzner hands the server a /64. The host address is that prefix with
# interface id 2. This does not look up a name.
sub host_from_prefix {
	my ($prefix) = @_;
	return undef if !defined($prefix) || $prefix eq '';
	$prefix =~ s{/\d+\z}{};
	$prefix =~ s/:+\z//;
	return undef if $prefix eq '';
	return $prefix . '::2';
}

sub _inner {
	my ($payload) = @_;
	return undef if ref($payload) ne 'HASH';
	if (ref($payload->{server}) eq 'HASH') {
		return $payload->{server};
	}
	return $payload;
}

sub _mask64 {
	my ($mask) = @_;
	return 0 if !defined($mask);
	return 1 if $mask =~ /^\d+$/ && $mask == 64;
	return 0;
}

sub host_from_server {
	my ($payload) = @_;
	my $server = _inner($payload);
	return undef if !$server;
	if (defined($server->{server_ipv6_net}) && $server->{server_ipv6_net} ne '') {
		return host_from_prefix($server->{server_ipv6_net});
	}
	my $subs = $server->{subnet};
	return undef if ref($subs) ne 'ARRAY';
	foreach my $row (@{ $subs }) {
		my $sub = $row;
		if (ref($row) eq 'HASH' && ref($row->{subnet}) eq 'HASH') {
			$sub = $row->{subnet};
		}
		next if ref($sub) ne 'HASH';
		next if !_mask64($sub->{mask});
		return host_from_prefix($sub->{ip});
	}
	return undef;
}

1;
