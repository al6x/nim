import base, ../core

proc svg_dot*(color: string): SafeHtml =
  fmt"""
    <svg version="1.1" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
      <circle style="fill: {color};" cx="50" cy="50" r="50"></circle>
    </svg>
  """.dedent.trim.replace(re"\s*\n\s*", "")

proc default_html_page*(app_el: El, styles = seq[string].init, scripts = seq[string].init): SafeHtml =
  app_el.attr("c", true) # adding white space around, for prettier html
  let styles  = ["/assets/mono.css"] & styles
  let scripts = ["import { run } from '/assets/mono.js'; run()".dedent.trim] & scripts
  proc is_style_link(s: string): bool = re"^(/|https?:)" =~ s
  let page =
    el"html":
      el"head":
        el("title", (text: app_el.window_title))
        el("link", (rel: "icon")) # Window icon, optional
        for style in styles:
          if style.is_style_link: el("link", (rel: "stylesheet", href: style))
          else:                   el("style", (html: style))

      el"body":
        it.add app_el

        # Window icon, optional
        el("template", (id: "window_icon",          html: svg_dot("#1e40af")))
        el("template", (id: "window_icon_disabled", html: svg_dot("#94a3b8")))

      for script in scripts:
        el("script", (html: script)):
          it.attr("type", "module")

  "<!DOCTYPE html>\n" & page.to_html