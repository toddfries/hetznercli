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

package WWW::Hetzner::traffic;

use Moose;
extends 'WWW::Hetzner::API';

sub init {
	my ($me) = @_;
	my $ip = $me->ip;
	$me->{dname} = "traffic";
	$me->{start} = "2017-10-01";
	$me->{stop}  = "2017-10-31";
	$me->refreshcall;
	$me->refresh;
}

sub refreshcall {
	my ($me) = @_;

	$me->{call} = "traffic?ip=".$me->{ip}."&type=month&from=".$me->{start}."&to=".$me->{stop};
}

sub ios {
	my ($me, $start, $stop) = @_;
	my $ip = $me->ip;
	if (defined($start)) {
		$me->{start}=$start;
	}
	if (defined($stop)) {
		$me->{stop}=$stop;
	}
	if (defined($start) || defined($stop)) {
		$me->refreshcall;
		$me->refresh;
	}

	if (!defined($me->{data}->{$ip}->{in})) {
		return (undef,undef,undef);
	}
	my $in  = $me->{data}->{$ip}->{in};
	my $out = $me->{data}->{$ip}->{out};
	my $sum = $me->{data}->{$ip}->{sum};
	return ($in,$out,$sum);
}

1;
