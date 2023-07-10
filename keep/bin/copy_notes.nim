#!/usr/bin/env nim r
import base, os
let keep_dir = current_source_path().parent_dir.parent_dir

let from_dir = "/alex/notes"
let to_dir   = "/alex/projects/keep" # current_source_path().parent_dir.parent_dir.absolute_path
let files    = @["tutor.ft", "movies.ft", "movies", "everyday.ft", "sales.ft", "books.ft"]

for name in files:
  fs.copy fmt"{from_dir}/{name}", fmt"{to_dir}/{name}"

fs.copy fmt"{keep_dir}/examples/notes/sample.ft", fmt"{to_dir}/sample.ft"
fs.copy fmt"{keep_dir}/examples/notes/sample",    fmt"{to_dir}/sample"