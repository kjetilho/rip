DOT_GRIP = $(HOME)/.grip
GRIP_VERSION = 3.2.0
BINDIR = $(HOME)/bin
RIPTRACK = $(BINDIR)/riptrack
ENCODE = $(BINDIR)/encode
ENCODE_PL = $(BINDIR)/encode.pl
SCAN = $(BINDIR)/scan
SCRIPTS = $(RIPTRACK) $(ENCODE) $(ENCODE_PL) $(SCAN)

all:
	# nothing

install: $(DOT_GRIP) $(SCRIPTS)

$(DOT_GRIP): _grip
	sed -e s,@@GRIP_VERSION@@,$(GRIP_VERSION), \
	    -e s,@@RIPTRACK@@,$(RIPTRACK), \
	    -e s,@@ENCODE@@,$(ENCODE), \
	    < $< > $@

$(RIPTRACK): bin/riptrack
	install -m 0775 $< $@
$(ENCODE): bin/encode
	install -m 0775 $< $@
$(ENCODE_PL): bin/encode.pl
	install -m 0775 $< $@
$(SCAN): bin/scan
	install -m 0775 $< $@

