TARGETS = cdc_acm.ihx

all:	$(TARGETS)

%.ihx:	%.c
	sdcc $<

clean:
	rm -f `cat .gitignore` $(TARGETS)

