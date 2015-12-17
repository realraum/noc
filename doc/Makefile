.PHONY: default clean serve

default:
	ikiwiki --refresh --setup ikiwiki.setup

clean:
	rm -rf dest

serve: default
	@cd dest; python -m SimpleHTTPServer
