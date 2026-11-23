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

package Hetznercli::Fail;

use strict;
use warnings;

# A Robot error document is {error=>{status,code,message}}.
# Missing data is exit 2. Any other error is exit 1.
# A normal document returns undef.
sub classify {
	my ($parsed) = @_;
	return undef if ref($parsed) ne 'HASH';
	return undef if ref($parsed->{error}) ne 'HASH';
	my $status = $parsed->{error}{status};
	my $code = $parsed->{error}{code} || '';
	my $exit = 1;
	if ((defined($status) && $status =~ /^\d+$/ && $status == 404)
		|| $code eq 'NOT_FOUND') {
		$exit = 2;
	}
	return {
		status => (defined($status) ? $status : ''),
		code => $code,
		message => ($parsed->{error}{message} || ''),
		exit => $exit,
	};
}

1;
