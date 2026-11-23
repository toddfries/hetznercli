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

package Hetznercli::Subnet;

use strict;
use warnings;

sub _mask64 {
	my ($mask) = @_;
	return 0 if !defined($mask);
	return 1 if $mask =~ /^\d+$/ && $mask == 64;
	return 0;
}

# List rows are {subnet=>{ip,mask,gateway,server_number}} or the inner hash.
sub rows {
	my ($parsed) = @_;
	return () if ref($parsed) ne 'ARRAY';
	my @out;
	foreach my $row (@{ $parsed }) {
		next if ref($row) ne 'HASH';
		my $one = (ref($row->{subnet}) eq 'HASH') ? $row->{subnet} : $row;
		next if ref($one) ne 'HASH';
		push @out, $one;
	}
	return @out;
}

# Gateway for this server. A /64 wins when the server has more than one row.
sub gateway_for {
	my ($rows, $server_number) = @_;
	return undef if !defined($server_number) || $server_number eq '';
	return undef if ref($rows) ne 'ARRAY';
	my $fallback;
	foreach my $row (@{ $rows }) {
		next if ref($row) ne 'HASH';
		next if !defined($row->{server_number});
		next if "$row->{server_number}" ne "$server_number";
		if (_mask64($row->{mask})) {
			return $row->{gateway};
		}
		$fallback = $row->{gateway} if !defined($fallback);
	}
	return $fallback;
}

1;
