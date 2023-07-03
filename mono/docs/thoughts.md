# Component Templates

- Clean UI with Components similar to Svelte or JSX.
- Components are interactive atomic blocks.
- Stateless Functional and Stateful Object Components.
- Template is plain Nim code.
- Slots, block passed as additional `content: seq[El]` argument.
- Also, custom slots could be used in block scope, like `layout.left/right`.
- Tag shortcut helps keep code small.
- No wait for Nim compilation, plays well with Tailwind, autocomplete etc.
- Context with `threadvar`.

# Todo

- Change el normalization, do it in JS, also in diff instead of replace(html_string) use replace(el_json), have minimal normalization in Nim, only for built-in HTML components to render initial page for SEO.
- Maybe use buit_el
- Flash doesn't work on todo and hello and twitter properly
- Browser Adapter with multiple widgets in the page and interactive charts.
- Better Async/Actor/Networking code.
- Slots for templates
- Add on_focus, on_drag, on_drop, on_keypress, on_keyup
- In bind_to, use JSON instead of string serialisation
- Move normalisation and `value` setting to JS, remove SEO friendliness.
- If evnet hanlders has render=false, optimise networking and don't sent event from browser, instead accumulate it and send all on next event.

# Ideas

- Integration with WebComponent, Svelte, React, UI Kits.
- Integration with LiveView, RoR, Laravel solutions for Desktop, IoS, Android.