.SUFFIXES:

DOCSRC := overscan/scribblings/overscan.scrbl
OUTDIR := docs

$(OUTDIR): $(DOCSRC)
	raco scribble +m --dest $@ --redirect-main 'http://docs.racket-lang.org/' $<

.PHONY: clean

clean:
	rm -rf $(OUTDIR)
