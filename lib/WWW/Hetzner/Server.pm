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

use WWW::Hetzner;

sub new {
	my ($class, $hetzner, $ip) = @_;

	if (!defined($hetzner)) {
		die("1st arg 'hetzner' is undef, bailing\n");
	}
	#print "\$hetzner is a ".ref($hetzner)."\n";
	if (!defined($ip)) {
		die("2nd arg 'ip' is undef, bailing\n");
	}

	my $me = { };
	
	$me->{hetzner} = $hetzner;

	my $bret = bless $me, $class;

	$me->set('ip',$ip);
	$me->refresh;

	return $bret;
}

sub set {
	my ($me, $var, $val) = @_;
	my $oval = $me->get($var);
	if (!defined($oval)) {
		$oval="<undef>";
	}
	#printf "%s: %s -> %s\n", $var, $oval, $val;

	$me->{$var} = $val;
}

sub get {
	my ($me, $var) = @_;
	return $me->{$var};
}

sub refresh {
	my ($me) = @_;
	my $parsed = $me->{hetzner}->req("server/".$me->get('ip'));

	if (ref($parsed) eq "") {
		printf "server/%s: %s\n", $me->get('ip'), $parsed;
	}
	foreach my $var (keys %{$parsed->{server}}) {
		my $val = $parsed->{server}->{$var};
		#printf "refresh '%s' = '%s'\n", $var, $val;
		$me->set($var, $val);
	}
}

sub traffic {
	my ($me) = @_;
	my $ip = $me->get('server_ip');
	my $parsed = $me->{hetzner}->req("traffic?type=month&from=2017-10-01&to=2017-10-31&ip=${ip}");

	if (!defined($parsed->{traffic}->{data}->{$ip}->{in})) {
		return;
	}
	my $in  = $parsed->{traffic}->{data}->{$ip}->{in};
	my $out = $parsed->{traffic}->{data}->{$ip}->{out};
	my $sum = $parsed->{traffic}->{data}->{$ip}->{sum};
	printf "               traffic in/out/sum = %s/%s/%s\n", $in,$out,$sum;
	return ($in,$out,$sum);
}

sub firewall {
	my ($me) = @_;
	my $ip = $me->get('server_ip');
	my $parsed = $me->{hetzner}->req("firewall/$ip");
	return $parsed;
}
1;
