import base, ext/parser, std/os
import ../core, ../parse

proc hblock(kind, text: string): HalfParsedBlock =
  (text, kind, "", "", 0)

proc test_fdoc_location(): string =
  current_source_path().parent_dir.absolute_path & "/some.ft"

proc test_fdoc(): FDoc =
  FDoc.init(location = test_fdoc_location())

test "consume_tags":
  template t(a, b) =
    let pr = Parser.init(a.dedent)
    check pr.consume_tags == b

  t """
    #"a a"  #b, #д
  """, (@["a a", "b", "д"], 1)

  t """
    some #a ^text
  """, (@["a"], 1)

  t """
    #a ^text #b
  """, (@["a", "b"], 1)

test "consume_blocks, consume_tags":
  template t(a, expected, tags) =
    let pr = Parser.init(a.dedent)
    var parsed = pr.consume_blocks
    check parsed == expected
    check pr.consume_tags == tags

  t """
    S t [s l](http://site.com) an t,
    same ^ par.

    Second 2^2 paragraph ^text

    - first m{2^a} line
    - second line ^list

    ^text

    first line

    second line ^list

    k: 1 ^config.data

    some text
    #tag #another ^text

    #tag #another tag
  """, @[
    ("S t [s l](http://site.com) an t,\nsame ^ par.\n\nSecond 2^2 paragraph", "text", "", "", 1),
    ("- first m{2^a} line\n- second line", "list", "", "", 6),
    ("", "text", "", "", 9),
    ("first line\n\nsecond line", "list", "", "", 11),
    ("k: 1", "data", "config", "", 15),
    ("some text\n#tag #another", "text", "", "", 17)
  ], (@["tag", "another"], 20)

  t """
    some text ^text
  """, @[("some text", "text", "", "", 1)], (seq[string].init, 1)

test "text_embed":
  template t(a, b) =
    let pr = Parser.init(a); var items: seq[FTextItem]
    check pr.is_text_embed == true
    pr.consume_text_embed items
    assert items.len == 1
    check items[0].to_json == b.to_json

  t "math{2^{2} } other", FTextItem(kind: embed, embed_kind: "math", text: "2^{2} ")
  t "`2^{2} ` other",     FTextItem(kind: embed, embed_kind: "code", text: "2^{2} ")

test "consume_inline_text, space":
  check consume_inline_text("**a**b ").mapit(it.text) == @["a", "b"]
  check consume_inline_text("**a** b\n").mapit(it.text) == @["a", " b"]

test "parse_text":
  let config = FTextConfig()
  config.embed_parsers["image"] = embed_parser_image
  config.embed_parsers["code"] = embed_parser_code

  let ftext = """
    Some text [some link](http://site.com) another **text,
    and [link 2]** more #tag1 image{img.png} some `code 2` some{some}


    - Line #lt1
    - Line 2 image{non_existing.png}

    And #tag2 another
  """.dedent

  let blk = parse_text(hblock("text", ftext), test_fdoc(), config)
  check blk.warns == @["Unknown embed: some"]

  let parsed = blk.formatted_text
  check parsed.len == 3

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Paragraph 1
    check parsed[0].kind == text
    check parsed[0].text.len == 13
    var it = parsed[0].text

    check it, 0,  (kind: "text", text: "Some text ")
    check it, 1,  (kind: "glink", text: "some link", glink: "http://site.com")
    check it, 2,  (kind: "text", text:  " another ")
    check it, 3,  (kind: "text", text: "text, and ", em: true)
    check it, 4,  (kind: "link", text: "link 2", link: (space: ".", doc: "link 2"), em: true)
    check it, 5,  (kind: "text", text: " more ")
    check it, 6,  (kind: "tag", text: "tag1")
    check it, 7,  (kind: "text", text: " ")
    check it, 8,  (kind: "embed", embed_kind: "image", text: "img.png", parsed: "img.png".some)
    check it, 9,  (kind: "text", text: " some ")
    check it, 10, (kind: "embed", embed_kind: "code", text: "code 2")
    check it, 11, (kind: "text", text: " ")
    check it, 12, (kind: "embed", embed_kind: "some", text: "some")

  block: # Paragraph 2
    check parsed[1].kind == list
    check parsed[1].list.len == 2
    var it = parsed[1].list
    check it, 0, [
      (kind: "text", text: "Line "),
      (kind: "tag", text: "lt1")
    ]
    check it, 1, [
      (kind: "text", text: "Line 2 ").to_json,
      (kind: "embed", embed_kind: "image", text: "non_existing.png", parsed: "non_existing.png".some).to_json
    ]

  block: # Paragraph 3
    check parsed[2].kind == text
    check parsed[2].text.len == 3
    var it = parsed[2].text
    check it, 0, (kind: "text", text: "And ")
    check it, 1, (kind: "tag", text: "tag2")
    check it, 2, (kind: "text", text: " another")

test "parse_list_as_items":
  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # as list
    let ftext = """
      - Line #tag
      - Line 2 image{some-img}
    """.dedent
    let parsed = Parser.init(ftext).parse_list_as_items

    check parsed.len == 2
    check parsed, 0, [
      (kind: "text", text: "Line "),
      (kind: "tag", text: "tag")
    ]
    check parsed, 1, [
      (kind: "text", text: "Line 2 ").to_json,
      (kind: "embed", embed_kind: "image", text: "some-img").to_json
    ]

  block: # as paragraphs
    let ftext = """
      Line #tag some
      text

      Line 2 image{some-img}
    """.dedent
    let parsed = Parser.init(ftext).parse_list_as_items

    check parsed.len == 2
    check parsed, 0, [
      (kind: "text", text: "Line "),
      (kind: "tag", text: "tag"),
      (kind: "text", text: " some text")
    ]
    check parsed, 1, [
      (kind: "text", text: "Line 2 ").to_json,
      (kind: "embed", embed_kind: "image", text: "some-img").to_json
    ]

test "parse_list":
  let config = FTextConfig()
  config.embed_parsers["image"] = embed_parser_image
  config.embed_parsers["code"] = embed_parser_code

  let ftext = """
    - Some image{img.png} some{some}
    - Another image{non_existing.png}
  """.dedent

  let blk = parse_list(hblock("list", ftext), test_fdoc(), config)
  check blk.warns == @["Unknown embed: 'some'"]

  let parsed = blk.list
  check parsed.len == 2

  template check(list, i, expected) =
    check list[i].to_json == expected.to_json

  block: # Line 1
    var it = parsed[0]
    check it, 0,  (kind: "text", text: "Some ")
    check it, 1,  (kind: "embed", embed_kind: "image", text: "img.png", parsed: "img.png".some)
    check it, 2,  (kind: "text", text: " ")
    check it, 3,  (kind: "embed", embed_kind: "some", text: "some")

  block: # Line 2
    var it = parsed[1]
    check it, 0,  (kind: "text", text: "Another ")
    check it, 1,  (kind: "embed", embed_kind: "image", text: "non_existing.png", parsed: "non_existing.png".some)

test "image":
  let img = parse_image(hblock("image", "some.png #t1 #t2"), test_fdoc())
  check (img.image, img.tags, img.assets) == ("some.png", @["t1", "t2"], @["some.png"])

test "images, missing":
  let imgs = parse_images(hblock("images", "missing/dir\n#t1 #t2"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == ("missing/dir", @[], @["t1", "t2"],
    @["missing/dir"])

test "images":
  let imgs = parse_images(hblock("images", ". #t1 #t2"), test_fdoc())
  check (imgs.images_dir, imgs.images, imgs.tags, imgs.assets) == (".", @["img.png"], @["t1", "t2"],
    @[".", "img.png"])

test "parse":
  block:
    let text = """
      Some #tag text ^text

      - a
      - b ^list

      k: 1 ^config.data

      #t #t2
    """.dedent

    let doc = FDoc.parse(text, "some.ft")
    check doc.sections.len == 1
    let section = doc.sections[0]
    check section.blocks.len == 3
    check section.line_n == 1
    check doc.tags == @["t", "t2"]
    check doc.tags_line_n == 8

  block:
    let text = """
      Some title ^title

      Some section ^section

      Some #tag text #t1 ^text

      Another section
      #t1 #t2 ^section

      - a
      - b ^list

      k: 1 ^data

      #t #t2
    """.dedent

    let doc = FDoc.parse(text, "some.ft")
    check doc.title == "Some title"
    check doc.sections.len == 2
    check doc.sections[0].line_n == 3
    check doc.sections[1].line_n == 7

test "parse_ftext, missing assets":
  let text = """
    image{missing1.png} ^text

    missing2.png ^image

    missing_dir ^images
  """.dedent

  let doc = FDoc.parse(text, test_fdoc_location())
  let blocks = doc.sections[0].blocks
  check blocks.len == 3
  check blocks[0].warns == @["Asset don't exist some/missing1.png"]
  check blocks[1].warns == @["Asset don't exist some/missing2.png"]
  check blocks[2].warns == @["Asset don't exist some/missing_dir"]