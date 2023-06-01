**Formal Text**, Text as Data

Markdown specifies How it Looks, FormalText **specifies What it Means, the structure of the Data**.

The Formal Text document is a sequence of blocks, blocks could be of different types, text,
list, table, images, charts etc. More blocks could and should be added, easy extensibility is
core feature, blocks for charts, computations (like Python Notebook) etc.

I'm using it for Notebook App (screenshot below), but it also could be used separately.

![](readme/keep.png)

# Todo

- Autolinks and text{text with special characters}
- Hash of doc should also include hash of its assets

# Features

Invisible, it try to look like normal text as much as possible.

Extensible, blocks, embeds, assets, define your own.

Validates the correctness of the data, tags, links, asset paths are validated.

Links to other docs and blocks in other docs.

Default blocks - text, image, images, code, data, table

Searchable, each block exposes its content as text, tags which is then used to search.

Collections of blocks, while blocks belongs to document, it's possible to query docs separately
and assemble virtual docs of blocks of various sources.

Could be used as a standalone document, or as document in notebook app, wich spaces, docs, full text search,
etc.

# Example

Example of FormalText

```
About Forex ^title

There are multiple reasons to About Forex. Every single of those reasons is big enough to stay away
from such investment. Forex has all of them. ^text

Trends are down #Finance #Trading ^section

**No intrinsic value**. Unlike #stocks that has it can fell all the
way down [to zero](http://some.com). ^text

knots #bushcraft #knots ^images
```

Note the last line with `knots` the images from the `knots` folder will be displayed as a gallery.

Rendering Formal Text:

```
nimble install https://github.com/al6x/nim?subdir=ftext

nim r --experimental:overloadable_enums ftext/render/example.nim

# To serve images properly the static server needed
# npm install -g node-static
ftext/bin/serve_example_assets

open http://localhost:3000/finance/about-forex.html
```

And you should see this page

![](readme/static_page.png)

# VSCode integration

![](readme/vscode.png)

Install 'Highlight' by 'Fabio Spampinato' extension, and then add following to VSCode `settings.json`

```JSON
  "highlight.regexes": {
    // tags
    "(#[a-zA-Zа-яА-Я]+[a-zA-Zа-яА-Я0-9]*)": {
      "filterFileRegex": ".*.ft$",
      "decorations": [
        { "color": "rgb(30, 64, 175)", "fontWeight": "normal" } // "textDecoration": "underline"
      ]
    },

    // title and section
    "([^\n]+?)(\\s*\\^title|\\s*\\^section)(\\s*\n|\\Z)": {
      "filterFileRegex": ".*.ft$",
      "decorations": [
        { "fontWeight": "bold" } // "textDecoration": "underline"
      ]
    },
    // Command
    "(\\s*)(\\^[a-z0-9]+\\s*)(\n|\\Z)": {
      "filterFileRegex": ".*.ft$",
      "decorations": [
        { "color": "#9CA3AF" }, { "color": "#9CA3AF" }
      ]
    },
    // Bold
    "(\\*\\*[a-zA-Z0-9\\s]+\\*\\*)": {
      "filterFileRegex": ".*.ft$",
      "decorations": [
        { "fontWeight": "bold" }
      ]
    }
  }
```