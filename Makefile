mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
current_dir := $(notdir $(patsubst %/,%,$(dir $(mkfile_path))))

MODULE := xml
PREFIX ?= ~/.hammerspoon
MODPATH = hs/_dtc
VERSION ?= 0.1
HS_APPLICATION ?= /Applications

LUAFILE  = init.lua
LUAMODULES = init.lua
SOFILE   = internal.so
DEBUG_CFLAGS ?= -g

# All object files
OBJFILES = internal.o

CC = @clang
# Warnings for our own code
WARNINGS ?= -Weverything -Wno-objc-missing-property-synthesis \
            -Wno-implicit-atomic-properties -Wno-direct-ivar-access \
            -Wno-cstring-format-directive -Wno-padded \
            -Wno-covered-switch-default -Wno-missing-prototypes \
            -Werror-implicit-function-declaration \
            -Wno-documentation-unknown-command \
            -Wno-documentation -Wno-documentation-deprecated-sync \
            -Wno-newline-eof -Wno-declaration-after-statement

EXTRA_CFLAGS ?= -F$(HS_APPLICATION)/Hammerspoon.app/Contents/Frameworks \
                -mmacosx-version-min=10.13

# Our code gets full warnings
CFLAGS  += $(DEBUG_CFLAGS) -fmodules -fobjc-arc -DHS_EXTERNAL_MODULE \
           $(WARNINGS) $(EXTRA_CFLAGS)

LDFLAGS += -dynamiclib -undefined dynamic_lookup $(EXTRA_LDFLAGS) \
           -framework Foundation

.SUFFIXES: .m .o

all: verify $(SOFILE)

$(SOFILE): $(OBJFILES)
	$(CC) $(OBJFILES) $(LDFLAGS) -o $@

internal.o: internal.m
	$(CC) -c $< $(CFLAGS) -o $@

install: verify install-objc install-lua install-docs

docs:
	hs -c "require(\"hs.doc\").builder.genJSON(\"$(dir $(mkfile_path))\")" > docs.json

verify: $(LUAMODULES)
	@if $$(hash lua >& /dev/null); then \
		(luac -p $(LUAMODULES) && echo "Lua Compile Verification Passed"); \
	else \
		echo "Skipping Lua Compile Verification"; \
	fi

install-objc: $(SOFILE)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(SOFILE) $(PREFIX)/$(MODPATH)/$(MODULE)
	cp -vpR $(SOFILE:.so=.so.dSYM) $(PREFIX)/$(MODPATH)/$(MODULE) 2>/dev/null || true

install-lua: $(LUAMODULES)
	mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE)
	install -m 0644 $(LUAMODULES) $(PREFIX)/$(MODPATH)/$(MODULE)

install-docs:
	@if [ -f docs.json ]; then \
		mkdir -p $(PREFIX)/$(MODPATH)/$(MODULE); \
		install -m 0644 docs.json $(PREFIX)/$(MODPATH)/$(MODULE); \
		echo "Installed docs.json"; \
	else \
		echo "No docs.json file to install (run 'make docs' to generate)"; \
	fi

clean:
	rm -rf $(SOFILE) $(OBJFILES) *.dSYM docs.json

uninstall:
	rm -v -f $(addprefix $(PREFIX)/$(MODPATH)/$(MODULE)/, $(LUAMODULES))
	rm -v -f $(PREFIX)/$(MODPATH)/$(MODULE)/$(SOFILE)
	rm -v -f $(PREFIX)/$(MODPATH)/$(MODULE)/docs.json
	rm -v -fr $(PREFIX)/$(MODPATH)/$(MODULE)/$(SOFILE:.so=.so.dSYM)
	rmdir -p $(PREFIX)/$(MODPATH)/$(MODULE) 2>/dev/null || true

.PHONY: all clean uninstall verify install install-objc install-lua install-docs docs
