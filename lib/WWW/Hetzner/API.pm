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

# generic API class 'parent'
package WWW::Hetzner::API;

use Moose;
use Moose::Util::TypeConstraints;

use WWW::Hetzner;

has 'hetzner' => (is => 'rw', isa => 'WWW::Hetzner', required => 1);
has 'ip' => (is => 'rw', isa => 'Str', required => 1);

around 'new' => sub {
	my $orig = shift;
	my $me = shift;

	my $nme = $me->$orig(@_);
	$nme->init;
	return $nme;
};

sub init {
	my ($me) = @_;

	$me->refresh;
}

sub set {
	my ($me, $var, $val) = @_;
	my $oval = $me->get($var);
	if (!defined($oval)) {
		$oval="<undef>";
	}
	if (!defined($val)) {
		$val="<undef>";
	}
	if (defined($me->{setoverrides}->{$var})) {
		my $oset = $me->{setoverrides}->{$var};
		&$oset($me,$val);
		return;
	}
	#printf "api %s %s: %s -> %s\n", ref($me), $var, $oval, $val;


	$me->{v}->{$var} = $val;
}

sub get {
	my ($me, $var) = @_;
	return $me->{v}->{$var};
}

sub refresh {
	my ($me) = @_;
	if (!defined($me->{call})) {
		return;
	}
	my $parsed = $me->hetzner->get($me->{call});
	if (!defined($parsed)) {
		printf "api %s refresh %s call returned <undef>\n",
			ref($me),
			$me->{call};
		return;
	}

	if (ref($parsed) eq "") {
		printf "%s: %s\n", $me->{call}, $parsed;
	}
	my $dn = $me->{dname};
	foreach my $var (keys %{$parsed->{$dn}}) {
		my $val = $parsed->{$dn}->{$var};
		#printf "api %s refresh '%s' = '%s'\n", ref($me), $var, $val;
		$me->set($var, $val);
	}
}

1;
