.SUFFIXES:

DOCSRC := overscan/scribblings/overscan.scrbl
OUTDIR := docs
RACKET_DOCS := http://docs.racket-lang.org/

docs/$(OUTDIR): $(DOCSRC)
	raco scribble +m --html-tree 2 --redirect-main $(RACKET_DOCS) --dest $(@D) --dest-name $(@F) $<

$(OUTDIR): docs/$(OUTDIR)

.PHONY: clean docs

clean:
	rm -rf docs/$(OUTDIR)
