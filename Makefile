.SUFFIXES:

DOCSRC := overscan/scribblings/overscan.scrbl
OUTDIR := docs
RACKET_DOCS := http://docs.racket-lang.org/

$(OUTDIR): $(DOCSRC)
	raco scribble +m --html-tree 2 --redirect-main $(RACKET_DOCS) --dest $(@D) --dest-name $(@F) $<

.PHONY: clean docs

clean:
	rm -rf $(OUTDIR)
