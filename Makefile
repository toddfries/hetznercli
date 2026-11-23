# purpose: run the hetznercli regress suite
# usage: make regress
# exit codes: 0 prove passed, non-zero prove failed

regress:
	prove regress/*.t

.PHONY: regress
