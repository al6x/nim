import base, std/os, ../core, ../parse, ../render

let space_dir = current_source_path().parent_dir.absolute_path & "/finance"

let doc = FDoc.read(fmt"{space_dir}/about-forex.ft")
let html_page = doc.to_html_page(space_id = "finance")
fs.write fmt"{space_dir}/about-forex.html", html_page