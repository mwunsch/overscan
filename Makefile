.SUFFIXES:

DOCSRC := overscan/scribblings/overscan.scrbl
OUTDIR := docs
RACKET_DOCS := http://docs.racket-lang.org/

$(OUTDIR): $(DOCSRC)
	raco scribble +m --dest $@ --redirect-main $(RACKET_DOCS) --dest-name index $<

.PHONY: clean

clean:
	rm -rf $(OUTDIR)
