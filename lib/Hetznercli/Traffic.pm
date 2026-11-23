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

package Hetznercli::Traffic;

use strict;
use warnings;

# Last $months calendar months, including the month of $epoch.
# Returns (YYYY-MM, YYYY-MM) in local time.
sub span {
	my ($epoch, $months) = @_;
	$months = 6 if !defined($months) || $months < 1;
	my @t = localtime($epoch);
	my $y = $t[5] + 1900;
	my $m = $t[4];
	for (1 .. ($months - 1)) {
		$m--;
		if ($m < 0) {
			$m = 11;
			$y--;
		}
	}
	my $end_y = $t[5] + 1900;
	my $end_m = $t[4] + 1;
	return (sprintf('%04d-%02d', $y, $m + 1),
		sprintf('%04d-%02d', $end_y, $end_m));
}

sub _ym {
	my ($s) = @_;
	return undef if !defined($s);
	return $1 if $s =~ /\A(\d{4}-\d{2})(?:-\d{2})?\z/;
	return undef;
}

# type=year asks Robot for monthly totals. single_values splits the window.
# An override must name both ends. A day is kept only as its month.
sub window {
	my (%o) = @_;
	my ($from, $to);
	if (defined($o{from}) || defined($o{to})) {
		if (!defined($o{from}) || !defined($o{to})) {
			return { error => 'from and to are YYYY-MM or YYYY-MM-DD' };
		}
		$from = _ym($o{from});
		$to = _ym($o{to});
		if (!defined($from) || !defined($to)) {
			return { error => 'from and to are YYYY-MM or YYYY-MM-DD' };
		}
	} else {
		my $now = defined($o{now}) ? $o{now} : time();
		($from, $to) = span($now, 6);
	}
	if ($from gt $to) {
		return { error => 'from is after to' };
	}
	return {
		type => 'year',
		from => $from,
		to => $to,
		single_values => 'true',
	};
}

sub prefix {
	my ($net) = @_;
	return undef if !defined($net) || $net eq '';
	$net =~ s{/\d+\z}{};
	return $net;
}

# One POST body. subnet[] is the v6 net. ip[] is a real IPv4 server address.
sub form {
	my ($window, $targets) = @_;
	my @subnets;
	my @ips;
	foreach my $t (@{ $targets || [] }) {
		next if ref($t) ne 'HASH';
		my $p = prefix($t->{prefix});
		push @subnets, $p if defined($p) && $p ne '';
		my $ip = $t->{ip};
		push @ips, $ip if defined($ip) && $ip =~ /^\d+\.\d+\.\d+\.\d+\z/;
	}
	my $form = {
		type => $window->{type},
		from => $window->{from},
		to => $window->{to},
		single_values => $window->{single_values},
	};
	$form->{'subnet[]'} = \@subnets if @subnets;
	$form->{'ip[]'} = \@ips if @ips;
	return $form;
}

sub _triple {
	my ($node) = @_;
	return undef if ref($node) ne 'HASH';
	foreach my $k (keys %{ $node }) {
		return undef if $k ne 'in' && $k ne 'out' && $k ne 'sum';
	}
	return undef if !exists($node->{in}) && !exists($node->{out});
	return $node;
}

sub format {
	my ($parsed, $targets) = @_;
	my $traffic = (ref($parsed) eq 'HASH') ? $parsed->{traffic} : undef;
	return "traffic reply had no data\n" if ref($traffic) ne 'HASH';
	my $data = $traffic->{data};
	my $head = sprintf("traffic %s %s .. %s\n",
		(defined($traffic->{type}) ? $traffic->{type} : ''),
		(defined($traffic->{from}) ? $traffic->{from} : ''),
		(defined($traffic->{to}) ? $traffic->{to} : ''));
	if (ref($data) eq 'ARRAY') {
		return "traffic reply had no data\n" if @{ $data };
		my $out = $head;
		foreach my $t (@{ $targets || [] }) {
			next if ref($t) ne 'HASH';
			my $label = $t->{label} || $t->{prefix} || $t->{ip} || 'target';
			$out .= "$label\n\tno samples\n";
		}
		$out .= "\tno samples\n" if $out eq $head;
		return $out;
	}
	return "traffic reply had no data\n" if ref($data) ne 'HASH';
	my %label;
	foreach my $t (@{ $targets || [] }) {
		next if ref($t) ne 'HASH';
		my $name = $t->{label} || '';
		my $p = prefix($t->{prefix});
		if (defined($p) && $p ne '') {
			$label{$p} = $name;
			$label{"$p/64"} = $name;
		}
		if (defined($t->{ip}) && $t->{ip} ne '') {
			$label{$t->{ip}} = $name;
		}
	}
	my $out = $head;
	my %seen;
	foreach my $key (sort keys %{ $data }) {
		my $bare = $key;
		$bare =~ s{/64\z}{};
		my $label = $label{$key};
		$label = $label{$bare} if !defined($label);
		$label = $key if !defined($label) || $label eq '';
		$seen{$key} = 1;
		$seen{$bare} = 1;
		$out .= "$label $key\n";
		my $node = $data->{$key};
		my $triple = _triple($node);
		if ($triple) {
			$out .= sprintf("\ttotal in %.4f out %.4f sum %.4f\n",
				(defined($triple->{in}) ? $triple->{in} : 0),
				(defined($triple->{out}) ? $triple->{out} : 0),
				(defined($triple->{sum}) ? $triple->{sum} : 0));
			next;
		}
		if (ref($node) ne 'HASH') {
			$out .= "\tunreadable\n";
			next;
		}
		foreach my $bucket (sort keys %{ $node }) {
			my $b = $node->{$bucket};
			next if ref($b) ne 'HASH';
			$out .= sprintf("\t%s in %.4f out %.4f sum %.4f\n",
				$bucket,
				(defined($b->{in}) ? $b->{in} : 0),
				(defined($b->{out}) ? $b->{out} : 0),
				(defined($b->{sum}) ? $b->{sum} : 0));
		}
	}
	foreach my $t (@{ $targets || [] }) {
		next if ref($t) ne 'HASH';
		my $p = prefix($t->{prefix});
		my $ip = $t->{ip};
		my $hit = (defined($p) && $p ne '' && ($seen{$p} || $seen{"$p/64"}))
			|| (defined($ip) && $ip ne '' && $seen{$ip});
		next if $hit;
		my $name = $t->{label} || $p || $ip || 'target';
		$out .= "$name\n\tno samples\n";
	}
	return $out;
}

1;
