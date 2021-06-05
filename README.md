# Install

First build and install `comby` from source:

```bash
git clone https://github.com/comby-tools/comby
cd comby && opam install . --deps-only -y
eval $(opam env)
make
make install
cd ..
```

Then build and install `comby-server` (this repository):

```bash
git clone https://github.com/comby-tools/comby-server
cd comby-server && opam install . --deps-only -y
make
```

You can now run:

```
./comby-server
```

You can test that the server is working by running this command in a separate terminal:

```bash
curl 'http://127.0.0.1:3000/rewrite' --data-raw '{"source":"foo(x)","match":"foo(:[x])","rule":"where true","rewrite":"bar(:[x])","language":".generic","substitution_kind":"in_place","id":0}'
```

You should see the response:

```json
{
  "rewritten_source": "bar(x)",
  "in_place_substitutions": [
    {
      "range": {
        "start": { "offset": 0, "line": -1, "column": -1 },
        "end": { "offset": 6, "line": -1, "column": -1 }
      },
      "replacement_content": "bar(x)",
      "environment": [
        {
          "variable": "x",
          "value": "x",
          "range": {
            "start": { "offset": 4, "line": -1, "column": -1 },
            "end": { "offset": 5, "line": -1, "column": -1 }
          }
        }
      ]
    }
  ],
  "id": 0
}
```

See server options (port, interface, etc.) by typing `comby-server --help`.

