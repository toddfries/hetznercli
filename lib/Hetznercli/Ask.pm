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

package Hetznercli::Ask;

use strict;
use warnings;

# xmessage separates buttons with commas and a label from its value with
# a colon, so neither may appear inside a label or a value.
sub buttons {
	my ($pairs) = @_;
	return undef if ref($pairs) ne 'ARRAY' || !@{ $pairs };
	my @parts;
	foreach my $p (@{ $pairs }) {
		return undef if ref($p) ne 'ARRAY' || @{ $p } != 2;
		my ($label, $value) = @{ $p };
		return undef if !defined($label) || !defined($value);
		return undef if $label =~ /[,:\s]/ || $value =~ /[,:\s]/;
		return undef if $label eq '' || $value eq '';
		push @parts, "$label:$value";
	}
	return join(',', @parts);
}

# Blocks until the button is clicked. There is no timer.
# $default_label is the xmessage -default label (Enter), not the value.
# Returns the value, or undef when xmessage cannot run.
sub choose {
	my ($text, $pairs, $default_label) = @_;
	my $buttons = buttons($pairs);
	return undef if !defined($buttons);
	my $path = "/tmp/hcli-ask-$$.txt";
	open my $fh, '>', $path or return undef;
	print {$fh} (defined($text) ? $text : '');
	close $fh;
	if (!defined($ENV{DISPLAY}) || $ENV{DISPLAY} eq '') {
		$ENV{DISPLAY} = ':0';
	}
	my @cmd = ('/usr/X11R6/bin/xmessage', '-print');
	if (defined($default_label) && $default_label ne '') {
		push @cmd, '-default', $default_label;
	}
	push @cmd, '-buttons', $buttons, '-file', $path;
	my $pid = open my $pipe, '-|', @cmd;
	if (!$pid) {
		unlink $path;
		return undef;
	}
	local $/;
	my $out = <$pipe>;
	close $pipe;
	my $rc = $?;
	unlink $path;
	return undef if $rc != 0;
	$out = '' if !defined($out);
	chomp $out;
	return $out;
}

1;
