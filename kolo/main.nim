import base, mono/[core, http], std/os
import ./app, ./space

let page: AppPage = proc(root_el: JsonNode): string =
  """
    <!DOCTYPE html>
    <html>
      <head>
        <title>{title}</title>
        <link rel="stylesheet" href="build/palette.css"/>
      </head>
      <body>

    {html}

    <script type="module">
      import { run } from "/assets/mono.js"
      run()
    </script>

      </body>
    </html>
  """.dedent
    .replace("{title}", root_el.window_title.escape_html)
    .replace("{html}", root_el.to_html(comments = true))

let db = Db.init

proc build_app(url: Url): tuple[page: AppPage, app: AppFn] =
  let kolo = App(db: db)

  let app: AppFn = proc(events: seq[InEvent], mono_id: string): seq[OutEvent] =
    kolo.process(events, mono_id)

  (page, app)

run_http_server(build_app, port = 2000)