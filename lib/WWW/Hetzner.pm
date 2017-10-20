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

package WWW::Hetzner;

use strict;
use warnings;

use LWP::UserAgent;
use HTTP::Request;
use JSON;

sub new {
	my ($class, $conf) = @_;

	my $me = { };
	
	$me->{ua} = LWP::UserAgent->new();
	$me->{ua}->env_proxy(1);
	$me->{ua}->timeout(60);
	$me->{cfile} = $conf;

	bless $me, $class;

	$me->loadconf;

	my $huser = $me->{config}->{huser};
	my $hpass = $me->{config}->{hpass};

	if (!defined($huser) || !defined($hpass)) {
		die("need huser and hpass defined in config file: $conf");
	}

	$me->{ua}->credentials( "robot-ws.your-server.de:443", "robot-ws", $huser, $hpass);

	$me->{json} = JSON->new->allow_nonref;
	$me->{URLBASE} = "https://robot-ws.your-server.de/";

	return $me;
}

sub req {
	my ($me, $call) = @_;

	my $url = $me->{URLBASE}.$call;
	
	my $req = HTTP::Request->new(GET => $url);

	if (!defined($req)) {
		return "EINVAL URL: $url";
	}

	my $res = $me->{ua}->request( $req );

	if (!defined($res)) {
		return "EBADF result URL='$url'";
	}
	#if (! $res->is_success) {
	#	return $res->status_line;
	#}

	return $me->parse_json( $res, "robot-ws");
}

sub parse_json {
	my ($me, $res, $name) = @_;

	my $str = $res->content;
	if (ref($str) ne "") {
		$str = $res->content_ref;
	}
	if (!defined($str)) {
		printf "%s has undef str\n", $name;
		return undef;
	}
	if (length($str) < 1) {
		printf "%s has empty str\n", $name;
		return undef;
	}

	my $parsed;
	#printf "%s: json->decode( '%s' ) .. pre\n", $name, $str;

	eval {
		$parsed = $me->{json}->decode( $str );
	};
	if ($@) {
		die(sprintf("%s: json->decode('%s') Error %s\n", $name,
		    $str, $@
));
	}
	return $parsed;
}

sub loadconf {
	my ($me) = @_;
	my $conf = $me->{cfile};

	if (! -f $conf) {
		die("config file '$conf' does not exist");
	}
	if (!open(C,$conf)) {
		die("could not open $conf");
	}
	my $line;
	while(<C>) {
		if (/^\s*$/ || /^\s*#/) {
			next;
		}
		chomp($line=$_);
		if ($line =~ /^\s*(\S+)\s*=\s*(.*)\s*$/) {
			my ($var,$val) = ($1, $2);
			printf "loadconf found '%s' = '%s'\n", $var, $val;

			$me->{config}->{$var}=$val;
			next;
		}
		printf "Unhandled config line: %s\n", $line;
	}
	close(C);
}

1;
