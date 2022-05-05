PATH  := /home/opam/.opam/4.14/bin:$(PATH)
SHELL := /bin/bash

all: build

build:
	@rm -rf comby-server
	@dune build --profile dev
	@ln -sfn _build/install/default/bin/comby-server comby-server

run-server:
	@./comby-server -p 8888

run-staging-server:
	@./comby-server -p 8887

install:
	@dune install

doc:
	@dune build @doc

test:
	@dune runtest

clean:
	@dune clean

uninstall:
	@dune uninstall

promote:
	@dune promote

.PHONY: all build run-server run-staging-server install doc test clean uninstall promote comby-server
