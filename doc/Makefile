.PHONY: default clean serve

default: favicon.ico
	ikiwiki --refresh --setup ikiwiki.setup

clean:
	rm -rf dest

serve: default
	@cd dest; python -m SimpleHTTPServer

favicon.ico:
	convert assets/logo.png -define icon:auto-resize=64,48,32,16 \
	                        -fill 'rgb(118,20,7)' -opaque white  \
	                        favicon.ico
