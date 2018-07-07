DIAGRAMS:=overview
FORMATS:=svg png

.PHONY: default
default: $(foreach diagram,$(DIAGRAMS),$(foreach ext,$(FORMATS),$(diagram).$(ext)))

$(foreach ext,$(FORMATS),%.$(ext)): %.dot
	$(foreach ext,$(FORMATS),circo -T$(ext) $^ -o $*.$(ext);)
