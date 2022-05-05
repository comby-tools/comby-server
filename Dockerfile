FROM ocaml/opam
WORKDIR /home/app

COPY . /home/app/

RUN sudo apt-get install libgmp-dev pkg-config libpcre3-dev -y

RUN opam install . --deps-only -y
RUN eval $(opam env)
RUN eval $(opam config env)
RUN make
RUN make install
