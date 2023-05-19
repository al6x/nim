# Todo

- Serve file space/doc.method-serve_file(rel_doc_path): tuple[path, mime]
- search list
- Move edit button to section right, `vscode -g fpath:line`
- FText parser for: Section, Table, Code, Images

# LTodo

- FText, long link reference, [N. Taleb Random](nt_random), [nt_random](http://ntaleb.org/random)

# Features

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
- Git for history and sharing
- Github or any other Git hosting for publishing, collaboration
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