FROM ocaml/opam:ubuntu-18.04-ocaml-4.12

WORKDIR /home/app

RUN sudo ln -f /usr/bin/opam-2.1 /usr/bin/opam
RUN opam init --reinit -ni
RUN mkdir -p /home/opam/dune/_boot /home/opam/dune/_build && chown opam:opam /home/opam/dune/_boot /home/opam/dune/_build
RUN sudo apt-get install git libgmp-dev pkg-config libpcre3-dev -y

COPY . /home/app/

RUN git config --global --add safe.directory /home/app
RUN opam install . --deps-only -y
RUN eval $(opam env)
RUN eval $(opam env) && make
RUN eval $(opam env) && make install
