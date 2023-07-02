# Todo

- Remove home from config
- on_event actions stored as raw json
- Turn alex/notes into space
- Remove space, space is a tag
- Introduce Obj, books,  for example

# Bugs

- External link doesn't work
- Fix parsing for "Invalid link: known/The Algorithm Design Manual.pdf" it should be turned into local link, with dot first
- Search doesn't work for utf, russian chars

# Lodo

- Make video about parser FText
- Add time tag
- Search with blackjack and hookers, tags facets with stats, show query and chunk trigrams, don't do separate app, use with notes https://github.com/searchkit/searchkit/tree/main/sample-data
- Display search for section/subsection as section/subsection with the next text item
- on_timer executed every minute, needed for action
- Add facets to search, display tags with 0 count as disabled, and for every tag display count, use larger size for
  tags with larger count. Split whole tags into 3 groups 0..max_count/3..max_count*2/3..max_count.
- Add home icon at the right of the white page
- Categories - urgent, high, lindy, archive.
- Display doc id and block id with gray color
- Home page with readme
- Search for "everyday" doesn't work
- use `select: blocks/docs order_by: `
- use `sql: expression` for filter
- Show space with list of documents, control sorting etc in db config
- Hide panel by default, show setting button on doc right
- Live Tutorial
- V Cache selected tags as view field, probably not, just use sqlite
- Search for "health" doesn't work.
- Add sorting to search and filter
- Move trigrams into search
- Display update time for docs
- Sync with static html to public internet hosting
- Sync with google/drive to mobile
- Rewrite "home-page" to be defined in config.
- Rewrite home_cached and other cached methods with `db.cache home_cached` template
- Search Facets
- Folding content right panel, persistent setting if closed
- Allow requests only from "keep" domain
- make editor configurable
- Checkout M. Fowler BiKi
- FText, long link reference, [N. Taleb Random](nt_random), [nt_random](http://ntaleb.org/random)
- Add space.config and parse editor code like "{path} {line}, each space has its own editor, could
  be local space or github space
- Add space/doc/block link for both embed and block display.
- Spaces have different colors of favicon, favicon set on top level compponent as window_icon
- Hierarchical tags
- Mozaic images gallery
- Tricky problem, try renaming `seqm.paginate` to `seqm.page` and the keep would break because nim won't recognise
  the `app_view.page` proc.

# Notes

Use two todos, first organised in Keep, and log like buffer on mobile.

# Features

- Invisible and smart, same as `echo "Hello World"`.
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
- Hierarchical tags, colored
- Auto asset extensions, the 'img{picture}' will be expanded into 'img{picture.png}' pr 'img{picture.jpg}'

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