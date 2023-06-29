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

- Maybe use buit_el
- Flash doesn't work on todo and hello and twitter properly
- Browser Adapter with multiple widgets in the page and interactive charts.
- Better Async/Actor/Networking code.
- Slots for templates

# Ideas

- Integration with WebComponent, Svelte, React, UI Kits.
- Integration with LiveView, RoR, Laravel solutions for Desktop, IoS, Android.