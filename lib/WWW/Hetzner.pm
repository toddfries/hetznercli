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

our $huser;
our $hpass;

sub new {
	my ($class, $conf) = @_;

	my $me = { };
	
	$me->{ua} = LWP::UserAgent->new();
	$me->{ua}->env_proxy(1);
	$me->{ua}->timeout(60);

	eval `cat $conf`;

	if (!defined($huser) || !defined($hpass)) {
		die "need huser and hpass defined in $conf";
	}

	$me->{ua}->credentials( "robot-ws.your-server.de:443", "robot-ws", $huser, $hpass);

	$me->{json} = JSON->new->allow_nonref;
	$me->{URLBASE} = "https://robot-ws.your-server.de/";

	bless $me, $class;
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

1;
