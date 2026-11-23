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

package Hetznercli::Vswitch;

use strict;
use warnings;

sub members {
	my ($row) = @_;
	my @nums;
	my $servers = $row->{server};
	return @nums if ref($servers) ne 'ARRAY';
	foreach my $server (@{ $servers }) {
		if (!ref($server)) {
			push @nums, $server if defined($server) && $server =~ /^\d+$/;
			next;
		}
		next if ref($server) ne 'HASH';
		if (defined($server->{server_number}) && $server->{server_number} =~ /^\d+$/) {
			push @nums, $server->{server_number};
		}
	}
	return @nums;
}

# The vSwitch list call omits membership. A row with no server array is
# unknown, not empty. Empty membership is an empty array.
sub unknown_membership {
	my ($rows) = @_;
	my @ids;
	foreach my $row (@{ $rows }) {
		next if ref($row->{server}) eq 'ARRAY';
		push @ids, $row->{id};
	}
	return @ids;
}

# vSwitches the reference server is on and the target server is not.
sub missing {
	my ($rows, $reference, $target) = @_;
	my @out;
	foreach my $row (@{ $rows }) {
		my %have = map { $_ => 1 } members($row);
		next if !$have{$reference};
		next if $have{$target};
		push @out, {
			id => $row->{id},
			vlan => $row->{vlan},
			name => $row->{name},
		};
	}
	return @out;
}

sub _blocks {
	my ($text) = @_;
	my @blocks;
	my $cur;
	foreach my $line (split /\n/, $text) {
		if ($line =~ /^iface\s+(\S+)\s+(inet6|inet)\s+(\S+)/) {
			push @blocks, $cur if $cur;
			$cur = { name => $1, family => $2, method => $3, opts => [] };
			next;
		}
		if ($cur && $line =~ /^\s+(\S+)\s+(.*?)\s*$/) {
			push @{ $cur->{opts} }, [$1, $2];
		}
	}
	push @blocks, $cur if $cur;
	return @blocks;
}

sub _opt {
	my ($block, $key) = @_;
	foreach my $opt (@{ $block->{opts} }) {
		return $opt->[1] if $opt->[0] eq $key;
	}
	return undef;
}

# Build a host interfaces file from the reference host's live pattern.
# The qemu user-net stanza (ens18 / 10.0.2.15) is not part of the pattern.
# nic, public_v6, and lan_addr come from the target, not the reference.
sub render {
	my ($text, $new) = @_;
	$new ||= {};
	my @blocks = _blocks($text);
	my ($vmbr0) = grep { $_->{name} eq 'vmbr0' && $_->{family} eq 'inet6' } @blocks;
	return { error => 'reference has no vmbr0' } if !$vmbr0;
	my $old_nic = _opt($vmbr0, 'bridge-ports');
	return { error => 'reference vmbr0 has no bridge port' }
		if !defined($old_nic) || $old_nic eq '' || $old_nic eq 'none';

	my @vlans;
	foreach my $block (@blocks) {
		if ($block->{name} =~ /^vmbr0\.(\d+)$/) {
			push @vlans, $1;
		}
	}
	return { error => 'reference has no vlan interfaces' } if !@vlans;

	my $lan_vlan;
	foreach my $block (@blocks) {
		next if $block->{name} !~ /^vmbr(\d+)$/;
		my $vlan = $1;
		next if $vlan eq '0' || $vlan eq '1';
		my $addr = _opt($block, 'address');
		if (defined($addr) && $block->{family} eq 'inet') {
			$lan_vlan = $vlan;
		}
	}
	return { error => 'reference has no addressed vlan bridge' }
		if !defined($lan_vlan);

	my $nic = $new->{nic};
	return { error => 'nic required' } if !defined($nic) || $nic eq '';
	my $v6 = $new->{public_v6};
	return { error => 'public v6 required' } if !defined($v6) || $v6 eq '';
	my $lan = $new->{lan_addr};
	return { error => 'lan address required' } if !defined($lan) || $lan eq '';
	$v6 =~ s{/64\z}{};
	$lan =~ s{/\d+\z}{};

	my $fe = _opt($vmbr0, 'address') || 'fe80::2/32';
	my $gw = _opt($vmbr0, 'gateway') || 'fe80::1';
	my $vids = _opt($vmbr0, 'bridge-vids') || '2-4094';
	my ($vmbr1) = grep { $_->{name} eq 'vmbr1' } @blocks;
	my $mtu = $vmbr1 ? _opt($vmbr1, 'mtu') : undef;

	my $out = '';
	$out .= "auto lo\niface lo inet loopback\n\n";
	$out .= "iface $nic inet manual\n\n";
	$out .= "auto vmbr0\niface vmbr0 inet6 static\n";
	$out .= "\taddress $fe\n";
	$out .= "\tgateway $gw\n";
	$out .= "\tbridge-ports $nic\n";
	$out .= "\tbridge-stp off\n";
	$out .= "\tbridge-fd 0\n";
	$out .= "\tbridge-vlan-aware yes\n";
	$out .= "\tbridge-vids $vids\n\n";
	$out .= "auto vmbr1\niface vmbr1 inet6 static\n";
	$out .= "\taddress $v6/64\n";
	$out .= "\tbridge-ports none\n";
	$out .= "\tbridge-stp off\n";
	$out .= "\tbridge-fd 0\n";
	$out .= "\tmtu $mtu\n" if defined($mtu) && $mtu ne '';
	$out .= "\n";
	foreach my $vlan (@vlans) {
		$out .= "auto vmbr0.$vlan\niface vmbr0.$vlan inet manual\n\n";
	}
	foreach my $vlan (@vlans) {
		$out .= "auto vmbr$vlan\n";
		if ($vlan eq $lan_vlan) {
			$out .= "iface vmbr$vlan inet static\n";
			$out .= "\taddress $lan/24\n";
		} else {
			$out .= "iface vmbr$vlan inet manual\n";
		}
		$out .= "\tbridge-ports vmbr0.$vlan\n";
		$out .= "\tbridge-stp off\n";
		$out .= "\tbridge-fd 0\n\n";
	}
	$out .= "source /etc/network/interfaces.d/*\n";
	return {
		text => $out,
		vlans => \@vlans,
		lan_vlan => $lan_vlan,
		old_nic => $old_nic,
	};
}

# First address in 10.10.0.7 .. 10.10.0.99 that is absent from the hosts
# text and absent from the ping-reply set. A listed address is never reused.
sub next_lan {
	my ($text, $busy) = @_;
	my %listed;
	while ($text =~ /^(\d+\.\d+\.\d+\.\d+)\b/mg) {
		$listed{$1} = 1;
	}
	foreach my $n (7 .. 99) {
		my $ip = "10.10.0.$n";
		next if $listed{$ip};
		next if $busy && $busy->{$ip};
		return $ip;
	}
	return undef;
}

1;
