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

package Hetznercli::Iso;

use strict;
use warnings;

sub parse_sums {
	my ($text) = @_;
	my @rows;
	foreach my $line (split /\n/, $text) {
		next if $line =~ /^\s*$/ || $line =~ /^\s*#/;
		if ($line =~ /^([0-9A-Fa-f]{64})\s+\*?(\S+)\s*$/) {
			push @rows, { sha256 => lc($1), name => $2 };
		}
	}
	return @rows;
}

sub parse_index {
	my ($html) = @_;
	my @rows;
	my %seen;
	while ($html =~ /(proxmox-ve_[0-9][^"'<>\s]*\.iso)/g) {
		my $name = $1;
		next if $seen{$name}++;
		push @rows, { name => $name, sha256 => undef };
	}
	return @rows;
}

sub _nums {
	my ($name) = @_;
	my @n = ($name =~ /(\d+)/g);
	return @n;
}

sub cmp_name {
	my ($a, $b) = @_;
	my @a = _nums($a);
	my @b = _nums($b);
	my $n = @a > @b ? @a : @b;
	foreach my $i (0 .. $n - 1) {
		my $c = ($a[$i] || 0) <=> ($b[$i] || 0);
		return $c if $c;
	}
	return 0;
}

sub ve_candidates {
	my (@rows) = @_;
	my @out;
	my %seen;
	foreach my $row (@rows) {
		my $name = $row->{name};
		next if !defined($name);
		next if $name !~ /^proxmox-ve_\d.*\.iso$/;
		next if $name =~ /arm64/i;
		next if $seen{$name}++;
		push @out, { name => $name, sha256 => $row->{sha256} };
	}
	@out = sort { cmp_name($b->{name}, $a->{name}) } @out;
	return @out;
}

sub recommend {
	my ($text) = @_;
	my @rows;
	if ($text =~ /^[0-9A-Fa-f]{64}\s/m) {
		@rows = parse_sums($text);
	} else {
		@rows = parse_index($text);
	}
	my @choices = ve_candidates(@rows);
	my $best = $choices[0];
	my $url;
	if ($best) {
		$url = 'https://enterprise.proxmox.com/iso/' . $best->{name};
	}
	return {
		choices => \@choices,
		recommended => $best,
		url => $url,
	};
}

sub serial_grub {
	my ($cfg) = @_;
	if ($cfg !~ /^serial --unit=0 --speed=115200\s*$/m) {
		$cfg = join("\n",
			'serial --unit=0 --speed=115200',
			'terminal_input serial',
			'terminal_output serial',
			'',
			$cfg,
		);
	}
	my @out;
	foreach my $line (split /\n/, $cfg, -1) {
		if ($line =~ /^(\s*linux\s+)(.*)$/) {
			my ($lead, $rest) = ($1, $2);
			$rest =~ s/(?:^|\s)console=ttyS0,115200(?=\s|$)//g;
			$rest =~ s/\s+\z//;
			$line = $lead . $rest . ' console=ttyS0,115200';
		}
		push @out, $line;
	}
	return join("\n", @out);
}

sub xorriso_argv {
	my ($src, $dst, $grub) = @_;
	return (
		'xorriso',
		'-indev', $src,
		'-outdev', $dst,
		'-map', $grub, '/boot/grub/grub.cfg',
		'-boot_image', 'any', 'replay',
	);
}

1;
