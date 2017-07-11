SHELL := /bin/bash
PATH  := node_modules/.bin:$(PATH)

parsers := lib/grammar/parser.rb

.PHONY: all clean test

all: $(parsers)

%.rb: %.peg node_modules/.bin/canopy
	canopy $^ --lang ruby

node_modules/.bin/canopy:
	npm install canopy

test: all
	find spec -name '*_spec.rb' | xargs ruby -Ilib

clean:
	rm -rf node_modules $(parsers)
