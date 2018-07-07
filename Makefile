.PHONY: default clean serve diagram

default: diagram favicon.ico
	ikiwiki --refresh --setup ikiwiki.setup

clean:
	rm -rf dest

serve: default
	@cd dest; python -m SimpleHTTPServer

diagram:
	$(MAKE) -C Network/

favicon.ico:
	convert assets/logo.png -define icon:auto-resize=64,48,32,16 \
	                        -fill 'rgb(118,20,7)' -opaque white  \
	                        favicon.ico
