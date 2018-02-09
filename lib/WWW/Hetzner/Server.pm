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

use Moose;

extends 'WWW::Hetzner::API';

use WWW::Hetzner::IP;
use WWW::Hetzner::traffic;
use WWW::Hetzner::rdns;
use WWW::Hetzner::cancellation;

use POSIX qw(strftime);

sub init {
	my ($me) = @_;
	my $ip = $me->ip;
	$me->{setoverrides}->{ip} = sub {
		my ($me) = @_;
		my $ip = $me->ip;
		my $lip = WWW::Hetzner::IP->new({hetzner => $me->hetzner,
			ip => $ip,
		});
		$me->{v}->{ip} = $lip;
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
		my $traffic = WWW::Hetzner::traffic->new(
			hetzner => $me->hetzner,
			ip => $ip,
		);
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
		my $rdns = WWW::Hetzner::rdns->new(
			hetzner => $me->{hetzner},
			ip => $ip,
		);
		$me->{_rdns} = $rdns;
	};
	$me->{setoverrides}->{_cancel} = sub {
		my ($me, $ip) = @_;
		if (ref($ip) eq "ARRAY" && $#{$ip} > 0) {
		printf "cancel override passed a %s('%s') and a %s('%s')\n",
			ref($me),$me,ref($ip),$ip; 
			foreach my $i (@{$ip}) {
				printf "cancel override IP array member %s\n", $i;
			}
			exit(1);
		}
		if (ref($ip) eq "ARRAY") {
			$ip = ${$ip}[0];
		}
		my $cancel = WWW::Hetzner::cancellation->new(
			hetzner => $me->{hetzner},
			ip => $ip,
		);
		$me->{_cancel} = $cancel;
	};
	$me->{call} = "server/$ip";
	$me->{dname} = "server";
	$me->refresh;
}

sub traffic {
	my ($me) = @_;
	my $ip = $me->ip;
	if (!defined($me->{_trafficbw})) {
		#printf "%s->traffic: set('traffic',%s)\n", ref($me), $ip;
		$me->set('_trafficbw',$ip);
	}
	my $start = strftime("%Y-%m-01", localtime(time()));
	my $mno = strftime("%m", localtime(time()));
	my %mdays;
	$mdays{'01'}=31;
	$mdays{'02'}=29;
	$mdays{'03'}=31;
	$mdays{'04'}=30;
	$mdays{'05'}=31;
	$mdays{'06'}=30;
	$mdays{'07'}=31;
	$mdays{'08'}=31;
	$mdays{'09'}=30;
	$mdays{'10'}=30;
	$mdays{'11'}=31;
	$mdays{'12'}=31;
	my $stop = strftime("%Y-%m-".$mdays{$mno}, localtime(time()));
	#print "traffic passing start=$start stop=$stop\n";
	return $me->{_trafficbw}->ios($start, $stop);
}

sub rdns {
	my ($me) = @_;
	my $ip = $me->ip;
	if (!defined($me->{_rdns})) {
		#printf "%s->rdns: set('rdns',%s)\n", ref($me), $ip;
		$me->set('_rdns',$ip);
	}
	return $me->{_rdns}->get('ptr');
}

sub cancel {
	my ($me) = @_;
	my $ip = $me->ip;
	if (!defined($me->{_cancel})) {
		#printf "%s->cancel: set('cancel',%s)\n", ref($me), $ip;
		$me->set('_cancel',$ip);
	}
	return $me->{_cancel};
}

sub firewall {
	my ($me) = @_;
	my $ip = $me->ip;
	my $parsed = $me->{hetzner}->req("firewall/$ip");
	return $parsed;
}

1;
