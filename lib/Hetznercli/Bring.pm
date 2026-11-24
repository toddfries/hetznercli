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

package Hetznercli::Bring;

use strict;
use warnings;

# pxj already has the alias, the NIC pin, the todd account, and the certificate.
sub finished {
	my ($name) = @_;
	return defined($name) && $name eq 'pxj';
}

sub normalize {
	my ($name) = @_;
	if (!defined($name) || $name eq '') {
		return { error => 'bring_online needs -n <short name>' };
	}
	$name = lc $name;
	$name =~ s/\.fdh\.bz\z//;
	if ($name !~ /\A[a-z][a-z0-9-]{0,20}\z/) {
		return { error => 'host name must be a short name' };
	}
	return { name => $name, fqdn => "$name.fdh.bz" };
}

sub ssh_block {
	my ($name) = @_;
	my $id = normalize($name);
	return '' if $id->{error};
	my $n = $id->{name};
	my $fqdn = $id->{fqdn};
	return <<"EOF";
Host r.$n.res
        HostKeyAlias $fqdn.rescue
        HostName $fqdn
Host r.$n
        HostKeyAlias $fqdn
        HostName $fqdn
Host r.$n.fdh.bz
        HostKeyAlias $fqdn
        HostName $fqdn
Host $n
        HostKeyAlias $fqdn
        HostName $fqdn
Host $n.fdh.bz
        HostKeyAlias $fqdn
        HostName $fqdn
EOF
}

sub ssh_present {
	my ($text, $name) = @_;
	my $id = normalize($name);
	return 0 if $id->{error};
	my $fqdn = $id->{fqdn};
	return 0 if !defined($text);
	return 0 if $text !~ /HostKeyAlias[ \t]+\Q$fqdn\E\.rescue\b/;
	return 0 if $text !~ /HostKeyAlias[ \t]+\Q$fqdn\E[ \t]*$/m;
	return 1;
}

sub merge_ssh {
	my ($text, $name) = @_;
	my $block = ssh_block($name);
	return { error => 'bad host name' } if $block eq '';
	$text = '' if !defined($text);
	if (ssh_present($text, $name)) {
		return { text => $text, status => 'present' };
	}
	$text .= "\n" if $text ne '' && $text !~ /\n\z/;
	$text .= "\n" if $text ne '';
	$text .= $block;
	return { text => $text, status => 'appended' };
}

sub pci_parts {
	my ($pci) = @_;
	return undef if !defined($pci) || $pci eq '';
	$pci =~ s/\Apci-//i;
	return undef if $pci !~ /\A[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-7]\z/i;
	return { kernels => lc($pci), path => 'pci-' . lc($pci) };
}

sub nic_text {
	my ($name, $pci, $nic) = @_;
	my $id = normalize($name);
	return $id->{error} . "\n" if $id->{error};
	my $slot = pci_parts($pci);
	if (!defined($nic) || $nic eq '' || $nic !~ /\A[a-z][a-z0-9]{1,14}\z/) {
		$nic = undef;
	}
	if (!$slot || !defined($nic)) {
		return "Pass -g 0000:bb:dd.f and -w <nic> to render the pin.\n"
			. "Install the udev rule and the .link file from the rescue image before the first disk boot.\n";
	}
	my $n = $id->{name};
	return <<"EOF";
# /etc/udev/rules.d/10-$n-nic.rules
SUBSYSTEM=="net", ACTION=="add", KERNELS=="$slot->{kernels}", NAME="$nic"
# /etc/systemd/network/10-$n-nic.link
[Match]
Path=$slot->{path}
[Link]
Name=$nic
Install both from the rescue image before the first disk boot.
EOF
}

# ok, missing, or bad. The hash itself stays in the file.
sub hash_status {
	my ($path) = @_;
	return 'missing' if !defined($path) || !-f $path;
	open my $fh, '<', $path or return 'missing';
	while (my $line = <$fh>) {
		next if $line !~ /^[[:space:]]*hash[[:space:]]*=[[:space:]]*(.*)$/;
		my $hash = $1;
		$hash =~ s/[[:space:]]+\z//;
		close $fh;
		return 'ok' if $hash =~ /\A\$(?:2a|2b|2y)\$/;
		return 'bad';
	}
	close $fh;
	return 'bad';
}

sub todd_text {
	my ($status) = @_;
	$status = 'missing' if !defined($status) || $status eq '';
	return <<"EOF";
Create user todd from ~/.config/hetzner/todd.conf
uid 947, group todd, extra group sudo, shell /bin/bash
chpasswd -e reads the hash. The hash is not printed.
hash file: $status
Install ~/.ssh/mykeypxu.pub as todd's authorized key.
EOF
}

# Remote bash -c body. The hash is read from stdin and is not part of this text.
sub todd_remote {
	my ($pubkey) = @_;
	return '' if !defined($pubkey) || $pubkey !~ /\Assh-(?:ed25519|rsa|ecdsa) [A-Za-z0-9+\/=]+ \S+\z/;
	my $q = $pubkey;
	$q =~ s/'/'\\''/g;
	return <<'EOF' =~ s/__PUB__/$q/gr;
set -eu
read -r hash
case "$hash" in
  '$2a$'*|'$2b$'*|'$2y$'*) ;;
  *) echo "hash is not bcrypt" >&2; exit 1 ;;
esac
if id todd >/dev/null 2>&1; then
  echo "todd already exists"
  exit 0
fi
getent group todd >/dev/null || groupadd -g 947 todd
useradd -m -g todd -u 947 -G sudo -s /bin/bash todd
printf '%s:%s\n' todd "$hash" | chpasswd -e
install -d -m 700 -o todd -g todd /home/todd/.ssh
touch /home/todd/.ssh/authorized_keys
grep -qxF '__PUB__' /home/todd/.ssh/authorized_keys || printf '%s\n' '__PUB__' >> /home/todd/.ssh/authorized_keys
chown todd:todd /home/todd/.ssh/authorized_keys
chmod 600 /home/todd/.ssh/authorized_keys
echo "todd created"
EOF
}

sub acme_text {
	my ($name) = @_;
	my $id = normalize($name);
	return $id->{error} . "\n" if $id->{error};
	my $fqdn = $id->{fqdn};
	return <<"EOF";
Order a Let's Encrypt certificate for $fqdn on port 8006.
The contact is postmaster\@fdh.bz.
The host name must already resolve. Nothing else should listen on port 80.
A later node in the same cluster skips the account create.
  pvesh get /cluster/acme/meta --directory https://acme-v02.api.letsencrypt.org/directory
  pvesh create /cluster/acme/account --name default --contact postmaster\@fdh.bz --directory https://acme-v02.api.letsencrypt.org/directory --tos_url <termsOfService>
  pvenode config set -acme account=default,domains=$fqdn
  pvenode acme cert order
The served file is /etc/pve/nodes/$id->{name}/pveproxy-ssl.pem.
EOF
}

sub acme_script {
	my ($name) = @_;
	my $id = normalize($name);
	return '' if $id->{error};
	my $fqdn = $id->{fqdn};
	return <<"EOF";
set -eu
fqdn='$fqdn'
node=\$(hostname)
pem="/etc/pve/nodes/\$node/pveproxy-ssl.pem"
if [ -f "\$pem" ] && openssl x509 -in "\$pem" -noout -issuer 2>/dev/null | grep -q "Let's Encrypt"; then
  echo "certificate already issued"
  exit 0
fi
dir='https://acme-v02.api.letsencrypt.org/directory'
meta=\$(pvesh get /cluster/acme/meta --directory "\$dir" --output-format json)
tos=\$(printf '%s' "\$meta" | python3 -c 'import json,sys; print(json.load(sys.stdin)["termsOfService"])')
if ! pvesh get /cluster/acme/account/default >/dev/null 2>&1; then
  pvesh create /cluster/acme/account --name default --contact postmaster\@fdh.bz --directory "\$dir" --tos_url "\$tos"
fi
pvenode config set -acme account=default,domains=\$fqdn
pvenode acme cert order
echo "certificate ordered"
EOF
}

sub plan {
	my (%o) = @_;
	my $id = normalize($o{name});
	return $id if $id->{error};
	my $text = "bring $id->{name} $id->{fqdn}\n\n";
	$text .= "SSH\n";
	$text .= ssh_block($id->{name});
	$text .= "Local forwards stay a per-host choice. This block only sets HostKeyAlias.\n\n";
	$text .= "NIC\n";
	$text .= nic_text($id->{name}, $o{pci}, $o{nic});
	$text .= "\n";
	$text .= "TODD\n";
	$text .= todd_text($o{hash_status});
	$text .= "\n";
	$text .= "CERT\n";
	$text .= acme_text($id->{name});
	$text .= "\n";
	if (finished($id->{name})) {
		$text .= "pxj is already done. These steps are not run again.\n";
	}
	return {
		text => $text,
		name => $id->{name},
		fqdn => $id->{fqdn},
		finished => finished($id->{name}) ? 1 : 0,
	};
}

1;
