# Copyright (c) 2017 Todd T. Fries <todd@fries.net>
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

package WWW::Hetzner::Server;

use strict;
use warnings;

use parent 'WWW::Hetzner::API';

use WWW::Hetzner;
use WWW::Hetzner::IP;
use WWW::Hetzner::traffic;
use WWW::Hetzner::rdns;

sub init {
	my ($me, $ip) = @_;
	$me->{setoverrides}->{ip} = sub {
		my ($me, $ip) = @_;
		if (ref($ip) eq "ARRAY" && $#{$ip} > 0) {
		printf "ip override passed a %s('%s') and a %s('%s')\n",
			ref($me),$me,ref($ip),$ip; 
			foreach my $i (@{$ip}) {
				printf "ip override IP array member %s\n", $i;
			}
			exit(1);
		}
		if (ref($ip) eq "ARRAY") {
			$ip = ${$ip}[0];
		}
		my $lip = WWW::Hetzner::IP->new($me->{hetzner},$ip);
		$me->{ip} = $lip;
	};
	$me->{setoverrides}->{_trafficbw} = sub {
		my ($me, $ip) = @_;
		if (ref($ip) eq "ARRAY" && $#{$ip} > 0) {
		printf "traffic override passed a %s('%s') and a %s('%s')\n",
			ref($me),$me,ref($ip),$ip; 
			foreach my $i (@{$ip}) {
				printf "traffic override IP array member %s\n", $i;
			}
			exit(1);
		}
		if (ref($ip) eq "ARRAY") {
			$ip = ${$ip}[0];
		}
		my $traffic = WWW::Hetzner::traffic->new($me->{hetzner},$ip);
		$me->{_trafficbw} = $traffic;
	};
	$me->{setoverrides}->{_rdns} = sub {
		my ($me, $ip) = @_;
		if (ref($ip) eq "ARRAY" && $#{$ip} > 0) {
		printf "rdns override passed a %s('%s') and a %s('%s')\n",
			ref($me),$me,ref($ip),$ip; 
			foreach my $i (@{$ip}) {
				printf "rdns override IP array member %s\n", $i;
			}
			exit(1);
		}
		if (ref($ip) eq "ARRAY") {
			$ip = ${$ip}[0];
		}
		my $rdns = WWW::Hetzner::rdns->new($me->{hetzner},$ip);
		$me->{_rdns} = $rdns;
	};
	$me->{call} = "server/$ip";
	$me->{dname} = "server";
	$me->refresh;
}

sub traffic {
	my ($me) = @_;
	my $ip = $me->get('server_ip');
	if (!defined($me->{_trafficbw})) {
		#printf "%s->traffic: set('traffic',%s)\n", ref($me), $ip;
		$me->set('_trafficbw',$ip);
	}
	return $me->{_trafficbw}->ios;
}

sub rdns {
	my ($me) = @_;
	my $ip = $me->get('server_ip');
	if (!defined($me->{_rdns})) {
		#printf "%s->rdns: set('rdns',%s)\n", ref($me), $ip;
		$me->set('_rdns',$ip);
	}
	return $me->{_rdns}->get('ptr');
}

sub firewall {
	my ($me) = @_;
	my $ip = $me->get('server_ip');
	my $parsed = $me->{hetzner}->req("firewall/$ip");
	return $parsed;
}
1;
