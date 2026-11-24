# purpose: run the hetznercli regress suite
# usage: make regress
# exit codes: 0 prove passed, non-zero prove failed

regress:
	prove regress/*.t

manlint:
	MANPATH=${.CURDIR}/man:/usr/share/man:/usr/X11R6/man:/usr/local/man \
	    mandoc -Tlint -Wstyle ${.CURDIR}/man/man1/*.1

.PHONY: regress manlint
