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

package Hetznercli::Market;

use strict;
use warnings;

use POSIX qw(strftime);

sub _num {
	my ($v) = @_;
	return 0 if !defined($v) || $v eq '';
	return $v + 0 if $v =~ /\A-?\d+(?:\.\d+)?\z/;
	return 0;
}

sub keep {
	my ($product, $min) = @_;
	return 0 if ref($product) ne 'HASH';
	return 1 if ref($min) ne 'HASH';
	my $disk = _num($product->{hdd_count}) * _num($product->{hdd_size});
	return 0 if defined($min->{cpu}) && _num($product->{cpu_benchmark}) < $min->{cpu};
	return 0 if defined($min->{mem}) && _num($product->{memory_size}) < $min->{mem};
	return 0 if defined($min->{disk}) && $disk < $min->{disk};
	return 1;
}

# Padded columns, then the CPU text. Left-aligned fields start under their
# header. Right-aligned fields end on their header. Widths grow to the rows.
my @COL_HEAD = qw(DC prodid sys bench disk MEM EUR EUR/TB next TB);
my @COL_LEFT = (1, 0, 1, 0, 0, 0, 0, 0, 1, 1);

sub row_fields {
	my ($product, $now) = @_;
	return () if ref($product) ne 'HASH';
	$now = time() if !defined($now);
	my $dc = defined($product->{datacenter}) ? $product->{datacenter} : '';
	$dc =~ s/-DC/-/;
	my $disk = _num($product->{hdd_count}) * _num($product->{hdd_size});
	my $traffic = defined($product->{traffic}) ? $product->{traffic} : '';
	$traffic =~ s/ TB$//;
	my $next = $product->{next_reduce};
	my $nextr = '-';
	if (defined($next) && $next =~ /\A-?\d+\z/) {
		$nextr = strftime('%m%d %H:%M', localtime($now + $next));
	}
	my $per = price_per_tb($product);
	my $per_s = defined($per) ? sprintf('%.5f', $per) : '-';
	return (
		$dc,
		sprintf('%d', _num($product->{id})),
		(defined($product->{name}) ? $product->{name} : ''),
		sprintf('%d', _num($product->{cpu_benchmark})),
		sprintf('%d', $disk),
		sprintf('%d', _num($product->{memory_size})),
		sprintf('%.2f', _num($product->{price})),
		$per_s,
		$nextr,
		$traffic,
		(defined($product->{cpu}) ? $product->{cpu} : ''),
	);
}

sub _widths {
	my (@rows) = @_;
	my @w = map { length($COL_HEAD[$_]) } 0 .. $#COL_HEAD;
	foreach my $fields (@rows) {
		for my $i (0 .. $#COL_HEAD) {
			my $n = length($fields->[$i] // '');
			$w[$i] = $n if $n > $w[$i];
		}
	}
	return @w;
}

sub _format_line {
	my ($fields, $widths) = @_;
	my @out;
	for my $i (0 .. $#$widths) {
		my $v = defined($fields->[$i]) ? $fields->[$i] : '';
		if ($COL_LEFT[$i]) {
			push @out, sprintf('%-*s', $widths->[$i], $v);
		} else {
			push @out, sprintf('%*s', $widths->[$i], $v);
		}
	}
	my $cpu = defined($fields->[$#$widths + 1]) ? $fields->[$#$widths + 1] : '';
	return join(' ', @out, $cpu) . "\n";
}

sub format_row {
	my ($product, $now) = @_;
	my @fields = row_fields($product, $now);
	return '' if !@fields;
	my @w = _widths(\@fields);
	return _format_line(\@fields, \@w);
}

# Header plus one line per product. Both market listings use this.
sub format_table {
	my ($products, $now) = @_;
	$products = [] if ref($products) ne 'ARRAY';
	my @rows;
	foreach my $product (@{ $products }) {
		my @fields = row_fields($product, $now);
		push @rows, \@fields if @fields;
	}
	my @w = _widths(@rows);
	my $text = _format_line([@COL_HEAD, 'CPU info'], \@w);
	foreach my $fields (@rows) {
		$text .= _format_line($fields, \@w);
	}
	return $text;
}

# EUR per tebibyte of the advertised disk total. hdd_size is gigabytes.
sub price_per_tb {
	my ($product) = @_;
	return undef if ref($product) ne 'HASH';
	my $gb = _num($product->{hdd_count}) * _num($product->{hdd_size});
	return undef if $gb <= 0;
	return _num($product->{price}) / ($gb / 1024);
}

sub stats {
	my ($product) = @_;
	return '' if ref($product) ne 'HASH';
	my $per = price_per_tb($product);
	my $per_s = defined($per) ? sprintf('%.2f EUR', $per) : 'unknown';
	my $text = sprintf("%s %s %s\n",
		(defined($product->{id}) ? $product->{id} : ''),
		(defined($product->{name}) ? $product->{name} : ''),
		(defined($product->{datacenter}) ? $product->{datacenter} : ''));
	$text .= sprintf("cpu %s bench %s\n",
		(defined($product->{cpu}) ? $product->{cpu} : ''),
		(defined($product->{cpu_benchmark}) ? $product->{cpu_benchmark} : ''));
	$text .= sprintf("ram %s GB\n",
		(defined($product->{memory_size}) ? $product->{memory_size} : ''));
	$text .= sprintf("disk %s x %s GB %s\n",
		(defined($product->{hdd_count}) ? $product->{hdd_count} : 0),
		(defined($product->{hdd_size}) ? $product->{hdd_size} : 0),
		(defined($product->{hdd_text}) ? $product->{hdd_text} : ''));
	if (ref($product->{description}) eq 'ARRAY') {
		foreach my $line (@{ $product->{description} }) {
			$text .= "  $line\n";
		}
	}
	$text .= sprintf("price %s EUR hourly %s setup %s\n",
		(defined($product->{price}) ? $product->{price} : ''),
		(defined($product->{price_hourly}) ? $product->{price_hourly} : ''),
		(defined($product->{price_setup}) ? $product->{price_setup} : ''));
	$text .= "price per TB $per_s\n";
	$text .= sprintf("traffic %s\n",
		(defined($product->{traffic}) ? $product->{traffic} : ''));
	$text .= sprintf("next reduce %s (%s)\n",
		(defined($product->{next_reduce_date}) ? $product->{next_reduce_date} : ''),
		(defined($product->{next_reduce}) ? $product->{next_reduce} : ''));
	$text .= sprintf("network %s\n",
		(defined($product->{network_speed}) ? $product->{network_speed} : ''));
	return $text;
}

# IPv6-only. The primary IPv4 addon is omitted. No password and no comment.
# $test adds test=true, which Robot accepts and does not process.
sub order_form {
	my ($id, $fingerprint, $test) = @_;
	if (!defined($id) || $id eq '') {
		return { error => 'product id required' };
	}
	if (!defined($fingerprint) || $fingerprint eq '') {
		return { error => 'fingerprint required' };
	}
	my $form = {
		product_id => $id,
		'authorized_key[]' => $fingerprint,
	};
	$form->{test} = 'true' if $test;
	return { form => $form };
}

sub order_text {
	my ($form) = @_;
	return '' if ref($form) ne 'HASH';
	my $text = "POST /order/server_market/transaction\n";
	$text .= "product_id=$form->{product_id}\n";
	$text .= "authorized_key[]=$form->{'authorized_key[]'}\n";
	$text .= "test=$form->{test}\n" if exists($form->{test});
	$text .= "IPv6-only form. The primary IPv4 addon is omitted.\n";
	return $text;
}

sub key_rows {
	my ($parsed) = @_;
	return () if ref($parsed) ne 'ARRAY';
	my @keys;
	foreach my $row (@{ $parsed }) {
		next if ref($row) ne 'HASH';
		my $one = (ref($row->{key}) eq 'HASH') ? $row->{key} : $row;
		next if ref($one) ne 'HASH';
		next if !defined($one->{fingerprint}) || $one->{fingerprint} eq '';
		push @keys, $one;
	}
	return @keys;
}

# Prefer an ED25519 key already stored on the account.
sub recommend_key {
	my ($keys) = @_;
	return undef if ref($keys) ne 'ARRAY' || !@{ $keys };
	foreach my $k (@{ $keys }) {
		return $k if ($k->{type} || '') eq 'ED25519';
	}
	return $keys->[0];
}

1;
