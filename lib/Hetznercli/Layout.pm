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

package Hetznercli::Layout;

use strict;
use warnings;

sub _pick {
	my ($inventory, $rule, $used) = @_;
	my @disks;
	if (ref($rule->{disks}) eq 'ARRAY') {
		foreach my $want (@{ $rule->{disks} }) {
			my ($got) = grep { $_->{path} eq $want } @{ $inventory };
			if (!$got) {
				return { error => "disk $want is not in the inventory" };
			}
			push @disks, $got;
		}
	} elsif (($rule->{match} || '') eq 'nvme') {
		@disks = grep { ($_->{kind} || '') eq 'nvme' } @{ $inventory };
	} elsif (($rule->{match} || '') eq 'rotational') {
		@disks = grep { ($_->{kind} || '') eq 'rotational' } @{ $inventory };
	} elsif (($rule->{match} || '') eq 'rest') {
		@disks = grep { !$used->{ $_->{path} } } @{ $inventory };
	} else {
		return { error => 'disk rule needs disks or a match' };
	}
	@disks = sort { $a->{path} cmp $b->{path} } @disks;
	my $role = $rule->{role} || '';
	if ($role eq 'mirror' && @disks != 2) {
		return { error => 'mirror wants 2 disks, found ' . scalar(@disks) };
	}
	if ($role eq 'single' && @disks != 1) {
		return { error => 'single wants 1 disk, found ' . scalar(@disks) };
	}
	if (!@disks) {
		return { error => 'disk rule matched nothing' };
	}
	return { disks => \@disks };
}

sub plan {
	my ($inventory, $spec) = @_;
	return { error => 'inventory required' } if ref($inventory) ne 'ARRAY';
	return { error => 'spec required' } if ref($spec) ne 'HASH';
	return { error => 'install spec required' } if ref($spec->{install}) ne 'HASH';

	my $picked = _pick($inventory, $spec->{install}, {});
	return $picked if $picked->{error};
	my @install = @{ $picked->{disks} };
	my %used = map { $_->{path} => 1 } @install;

	my $out = {
		install_disks => [map { $_->{path} } @install],
		hdsize => $spec->{install}{hdsize},
		pool => $spec->{pool} || 'data',
		special => 0,
		data_disks => [],
		level => undef,
	};

	if (ref($spec->{data}) eq 'HASH') {
		my $data = $spec->{data};
		if (($data->{spare} || 0) != 0) {
			return { error => 'a spare was requested; this spec does not assign spares' };
		}
		my $dp = _pick($inventory, $data, \%used);
		return $dp if $dp->{error};
		my $level = $data->{level} || '';
		my $n = @{ $dp->{disks} };
		if ($level eq 'raidz2' && $n < 4) {
			return { error => "raidz2 wants at least 4 disks, found $n" };
		}
		if ($level eq 'raidz' && $n < 3) {
			return { error => "raidz wants at least 3 disks, found $n" };
		}
		if ($level eq 'raidz3' && $n < 5) {
			return { error => "raidz3 wants at least 5 disks, found $n" };
		}
		if ($level eq 'mirror' && $n < 2) {
			return { error => "mirror wants at least 2 disks, found $n" };
		}
		if ($level !~ /^(mirror|raidz|raidz2|raidz3)$/) {
			return { error => "unknown pool level $level" };
		}
		$out->{level} = $level;
		$out->{data_disks} = [map { $_->{path} } @{ $dp->{disks} }];
		if (defined($data->{special}) && $data->{special} ne '') {
			if ($data->{special} ne 'install-tails') {
				return { error => "unknown special role $data->{special}" };
			}
			if (@install != 2) {
				return { error => 'special mirror needs the two install disks' };
			}
			if (!defined($spec->{install}{hdsize}) || $spec->{install}{hdsize} eq '') {
				return { error => 'special mirror needs an installer hdsize so the tails stay free' };
			}
			$out->{special} = 1;
		}
	}
	return $out;
}

sub tail_placeholders {
	my ($planned) = @_;
	return map { $_ . '-tail' } @{ $planned->{install_disks} || [] };
}

sub zpool_command {
	my ($planned, $tails) = @_;
	return { error => $planned->{error} } if $planned->{error};
	if (!$planned->{data_disks} || !@{ $planned->{data_disks} }) {
		return { argv => [] };
	}
	my @tails;
	if ($planned->{special}) {
		if (ref($tails) ne 'ARRAY' || @{ $tails } != 2) {
			return { error => 'special mirror needs two tail partitions' };
		}
		@tails = @{ $tails };
	}
	my @cmd = (
		'zpool', 'create', '-o', 'ashift=12',
		$planned->{pool}, $planned->{level},
	);
	push @cmd, @{ $planned->{data_disks} };
	if ($planned->{special}) {
		push @cmd, 'special', 'mirror', @tails;
	}
	return { argv => \@cmd };
}

sub checklist {
	my ($planned) = @_;
	return $planned->{error} . "\n" if $planned->{error};
	my @lines;
	my $n = @{ $planned->{install_disks} };
	if ($n == 2) {
		push @lines, 'Installer: ZFS RAID1 on the install disks only';
	} elsif ($n == 1) {
		push @lines, 'Installer: one install disk';
	}
	push @lines, 'Install disks: ' . join(' ', @{ $planned->{install_disks} });
	if ($planned->{hdsize}) {
		push @lines, "Advanced hdsize: $planned->{hdsize}";
		push @lines, 'That leaves the tail of each install disk unpartitioned';
	}
	push @lines, 'Disks that are not install disks stay out of the guest';
	push @lines, 'Set reverse DNS on the host v6 to the host name';
	if ($planned->{special}) {
		push @lines, 'After boot, cut one GPT partition from each free tail';
		push @lines, "The data pool is $planned->{level} plus a mirror of the two tails";
		push @lines, 'special_small_blocks stays unset';
		push @lines, 'No cache device and no log device';
	}
	return join("\n", @lines) . "\n";
}

1;
