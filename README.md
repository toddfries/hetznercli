Hetzner CLI example app and packages

This is a work in progress, not feature complete, reading info only for now.

The idea of a conf file is to slurp in the conf file and set global vars,
this is something I intend to change with a simple parser soon.

For now, $HOME/.hcli.conf should contain:

	$huser = "username";
	$hpass = "password";

for the api user you've setup at hetzner's robot web interface.

See the 'hcli' app for more 'documentation'.  More to be put here in the
future.
