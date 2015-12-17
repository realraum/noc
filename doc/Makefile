.PHONY: default clean serve

default:
	ikiwiki --setup ikiwiki.setup

clean:
	rm -rf dest

serve: default
	@cd dest; python -m SimpleHTTPServer
