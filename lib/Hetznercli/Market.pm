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

sub _hay {
	my ($product) = @_;
	my @part;
	push @part, $product->{hdd_text} if defined($product->{hdd_text});
	push @part, $product->{cpu} if defined($product->{cpu});
	if (ref($product->{description}) eq 'ARRAY') {
		push @part, @{ $product->{description} };
	} elsif (defined($product->{description}) && !ref($product->{description})) {
		push @part, $product->{description};
	}
	return join("\n", @part);
}

sub _truthy {
	my ($v) = @_;
	return 0 if !defined($v) || $v eq '' || $v eq '0' || $v eq 'false';
	return $v ? 1 : 0;
}

sub keep {
	my ($product, $min) = @_;
	return 0 if ref($product) ne 'HASH';
	return 1 if ref($min) ne 'HASH';
	my $disk = _num($product->{hdd_count}) * _num($product->{hdd_size});
	my $count = _num($product->{hdd_count});
	my $price = _num($product->{price});
	return 0 if defined($min->{cpu}) && _num($product->{cpu_benchmark}) < $min->{cpu};
	return 0 if defined($min->{mem}) && _num($product->{memory_size}) < $min->{mem};
	return 0 if defined($min->{disk}) && $disk < $min->{disk};
	return 0 if defined($min->{disk_max}) && $disk > $min->{disk_max};
	return 0 if defined($min->{count_min}) && $count < $min->{count_min};
	return 0 if defined($min->{count_max}) && $count > $min->{count_max};
	return 0 if defined($min->{price_min}) && $price < $min->{price_min};
	return 0 if defined($min->{price_max}) && $price > $min->{price_max};
	if (ref($min->{re}) eq 'ARRAY') {
		my $hay = _hay($product);
		foreach my $re (@{ $min->{re} }) {
			return 0 if $hay !~ $re;
		}
	}
	return 1;
}

sub _num_ok {
	my ($v) = @_;
	return defined($v) && $v =~ /\A\d+(?:\.\d+)?\z/;
}

sub _raise_min {
	my ($out, $key, $v) = @_;
	$out->{$key} = $v + 0 if !defined($out->{$key}) || $v + 0 > $out->{$key};
}

sub _lower_max {
	my ($out, $key, $v) = @_;
	$out->{$key} = $v + 0 if !defined($out->{$key}) || $v + 0 < $out->{$key};
}

sub _range {
	my ($val) = @_;
	return if !defined($val) || $val !~ /\A(\d+(?:\.\d+)?):(\d+(?:\.\d+)?)\z/;
	return ($1 + 0, $2 + 0);
}

# Repeated -o key=value. A later minimum only rises. A later maximum only falls.
# format=custom is recognized and refused.
sub parse_opts {
	my (@spec) = @_;
	my $out = {
		format => 'full',
		re => [],
	};
	foreach my $one (@spec) {
		if (!defined($one) || $one !~ /\A([^=]+)=(.*)\z/s) {
			return { error => 'option needs key=value' };
		}
		my ($key, $val) = ($1, $2);
		if ($key eq 'format') {
			if ($val eq 'full' || $val eq 'price') {
				$out->{format} = $val;
				next;
			}
			if ($val =~ /\Acustom:/) {
				return { error => 'format=custom is not implemented' };
			}
			return { error => "unknown format $val" };
		}
		if ($key eq 're') {
			if ($val eq '') {
				return { error => 're needs a pattern' };
			}
			my $re = eval { qr/$val/ };
			if ($@ || !defined($re)) {
				return { error => 'bad re' };
			}
			push @{ $out->{re} }, $re;
			next;
		}
		if ($key eq 'disk.min' || $key eq 'disk.max' || $key eq 'disk'
			|| $key eq 'price.min' || $key eq 'price.max' || $key eq 'price'
			|| $key eq 'disk.count.min' || $key eq 'disk.count.max'
			|| $key eq 'disk.count') {
			my ($min, $max);
			if ($key =~ /\.min\z/) {
				return { error => "$key needs a number" } if !_num_ok($val);
				$min = $val + 0;
			} elsif ($key =~ /\.max\z/) {
				return { error => "$key needs a number" } if !_num_ok($val);
				$max = $val + 0;
			} else {
				($min, $max) = _range($val);
				return { error => "$key needs MIN:MAX" } if !defined($min);
			}
			my ($minkey, $maxkey) = ($key =~ /\Adisk\.count/)
				? ('count_min', 'count_max')
				: ($key =~ /\Aprice/)
				? ('price_min', 'price_max')
				: ('disk_min', 'disk_max');
			_raise_min($out, $minkey, $min) if defined($min);
			_lower_max($out, $maxkey, $max) if defined($max);
			next;
		}
		return { error => "unknown option $key" };
	}
	if (defined($out->{disk_min}) && defined($out->{disk_max})
		&& $out->{disk_min} > $out->{disk_max}) {
		return { error => 'disk min is above disk max' };
	}
	if (defined($out->{count_min}) && defined($out->{count_max})
		&& $out->{count_min} > $out->{count_max}) {
		return { error => 'disk count min is above disk count max' };
	}
	if (defined($out->{price_min}) && defined($out->{price_max})
		&& $out->{price_min} > $out->{price_max}) {
		return { error => 'price min is above price max' };
	}
	return $out;
}

# -D raises disk.min. The other CLI floors are copied when set.
sub merge_cli {
	my ($opts, $cli) = @_;
	return { error => 'missing options' } if ref($opts) ne 'HASH';
	return { error => $opts->{error} } if $opts->{error};
	$cli = {} if ref($cli) ne 'HASH';
	my $disk = $opts->{disk_min};
	if (defined($cli->{disk}) && $cli->{disk} ne '') {
		my $n = _num($cli->{disk});
		$disk = $n if !defined($disk) || $n > $disk;
	}
	if (defined($disk) && defined($opts->{disk_max}) && $disk > $opts->{disk_max}) {
		return { error => 'disk min is above disk max' };
	}
	return {
		format => $opts->{format},
		keep => {
			cpu => (defined($cli->{cpu}) && $cli->{cpu} ne '') ? $cli->{cpu} : undef,
			mem => (defined($cli->{mem}) && $cli->{mem} ne '') ? $cli->{mem} : undef,
			disk => $disk,
			disk_max => $opts->{disk_max},
			count_min => $opts->{count_min},
			count_max => $opts->{count_max},
			price_min => $opts->{price_min},
			price_max => $opts->{price_max},
			re => $opts->{re},
		},
	};
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

# Same two-line banner and fixed row as hmarket. GB is count times size.
# The rate divides by 1000, not 1024, and keeps three decimals.
sub format_price {
	my ($products, $now) = @_;
	$products = [] if ref($products) ne 'ARRAY';
	$now = time() if !defined($now);
	my $text = "\n"
		. "                  HDD HDD        Price\n"
		. "           Ram   Size  Ct          Per  ,--Next Adjust-------------------.\n"
		. " ServerID   GB     GB     Price     TB Day HH:MM:SS     Date     Time\n";
	foreach my $product (@{ $products }) {
		next if ref($product) ne 'HASH';
		my $count = _num($product->{hdd_count});
		my $gb = $count * _num($product->{hdd_size});
		my $price = defined($product->{price}) ? $product->{price} : '';
		my $rate = ($gb > 0) ? (_num($price) / ($gb / 1000)) : 0;
		my $next = $product->{next_reduce};
		my $when = '      reload';
		my $aka = '';
		if (defined($next) && $next =~ /\A-?\d+\z/) {
			my $sec = $next + 0;
			if ($sec > 0) {
				my $d = int($sec / 86400);
				my $h = int(($sec % 86400) / 3600);
				my $m = int(($sec % 3600) / 60);
				my $s = $sec % 60;
				$when = sprintf('%2dd %2d:%02d:%02d', $d, $h, $m, $s);
			} elsif (_truthy($product->{fixed_price})) {
				$when = '       fixed';
			}
			$aka = strftime('%Y%m%d %H:%M:%S', localtime($now + $sec));
		} elsif (_truthy($product->{fixed_price})) {
			$when = '       fixed';
		}
		my $tail = ($aka ne '') ? "$when aka $aka" : $when;
		$text .= sprintf("%9d %4d %6d %2d %6s %6.3f %s\n",
			_num($product->{id}),
			_num($product->{memory_size}),
			$gb,
			$count,
			$price,
			$rate,
			$tail);
	}
	return $text;
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
