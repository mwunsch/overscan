.SUFFIXES:

DOCSRC := overscan/scribblings/overscan.scrbl
OUTDIR := docs
RACKET_DOCS := http://docs.racket-lang.org/

$(OUTDIR): $(DOCSRC)
	raco scribble +m --html-tree 1 --redirect-main $(RACKET_DOCS) --dest-name $@ $<

.PHONY: clean

clean:
	rm -rf $(OUTDIR)
