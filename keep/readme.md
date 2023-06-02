# Todo

- Move render to keep
- Base ftext classes on keep/base classes
- Use block or text table to display list of notes
- "/misc ^images" - no warnings
- Image on click open in new tab
- Add block and doc id to search index
- Make list as list, slow rendering, probably for text
- Refactor space, so it can have mixed content, ftext etc
- Add space.config and parse editor code like "{path} {line}, each space has its own editor, could
  be local space or github space
- Turn alex/notes into space
- Make video about parser FText
- Make search
- Search with blackjack and hookers, index Wwar of the worlds, and libres, show query timing, tags facets with stats,
  show query and chunk trigrams, don't do separate app, use with notes, just add extra vidgets to display
  peformance and trigrams.

- Add space/doc/block link for both embed and block display.
- FText parser for: Table

# LTodo

- Checkout M. Fowler BiKi
- FText, long link reference, [N. Taleb Random](nt_random), [nt_random](http://ntaleb.org/random)

# Notes

Use two todos, first organised in Keep, and log like buffer on mobile.

# Features

- It's a rendering and search engine, any data following doc and blocks structure could be rendered and searched.
- Extensible, different spaces, docs, blocks, actions
- Integrates other tools and data
- In search it's posible to control if show doc or block, by adding `block forest` doc by default.
- Each block has same UI, two lines top and bottom
- It's possible to create virtual docs, as search term, a sequence of blocks.
- Store, manage playlists and play Music, on external drive
- Store Books
- Store and play Audibooks, on external drive
- Store and display Photos and Photo Albums, on external drive
- Manage notes
- Blocks: text, gallery, list, image
- Table block, with images and text, to display books
- Tags
- Public and priveate spaces
- Search, tags and spaces filters, index book context
- Publish selected notes as pdf book
- SpreadSheet
- Git and GitHub for history and sharing
- Git for collaboration, updates, conflict resolution
- Any file hosting for sharing
- Ftext format is almost the same as Nim ftext DSL

# Forward 80 to 8080 on Mac OS

Enable

```
echo "
rdr pass inet proto tcp from any to any port 80 -> 127.0.0.1 port 8080
" | sudo pfctl -ef -
```

Disable

```
echo "
" | sudo pfctl -ef -
```

sudo pfctl -F all -f /etc/pf.conf

Show

```
sudo pfctl -s nat
```