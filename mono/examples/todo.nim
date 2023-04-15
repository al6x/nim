import base, mono/core

# Model --------------------------------------------------------------------------------------------
type
  TodoItemState* = enum active, completed

  TodoItem* = ref object
    text*:      string
    completed*: bool

  Todo* = ref object
    items*: seq[TodoItem]

proc id*(self: TodoItem): string =
  self.text


# TodoView -----------------------------------------------------------------------------------------
# Feature: stateful component, preserving its state between renders
type TodoItemView* = ref object of Component
  on_delete: proc(id: string)
  editing:   Option[string] # value of `editing` field going to be maintained between requests
  item:      TodoItem

proc set_attrs*(self: TodoItemView, item: TodoItem, on_delete: (proc(id: string))) =
  self.item = item; self.on_delete = on_delete

proc render*(self: TodoItemView): HtmlElement =
  proc handle_edit(e: KeydownEvent) =
    if e.key == "Enter":
      self.item.text = self.editing.get
      self.editing.clear
    elif e.key == "Escape":
      self.editing.clear

  let class_modifier =
    (if self.item.completed: ".completed" else: "") &
    (if self.editing.is_some: ".editing" else: "")

  # Feature: compact HTML template syntax
  h"li{class_modifier}":
    + h".view":
      + h"input.toggle type=checkbox"
        # Feature: two way binding with autocast
        .bind_to(self.item.completed)
      + h"label".text(self.item.text)
        .on_dblclick(proc = self.editing = self.item.text.some)
      + h"button.destroy"
        .on_click(proc = self.on_delete(self.item.id))
    if self.editing.is_some:
      + h"input#edit.edit autofocus"
        .bind_to(self.editing)
        .on_keydown(handle_edit)
        .on_blur(proc = self.editing = string.none)


# TodosView -----------------------------------------------------------------------------------------
type TodoViewFilter* = enum all, active, completed

type TodoView* = ref object of Component
  todo:       Todo
  filter:     TodoViewFilter
  new_todo:   string
  toggle_all: bool

proc set_attrs*(self: TodoView, todo: Todo = Todo(), filter: TodoViewFilter = all) =
  self.todo = todo; self.filter = filter

proc render*(self: TodoView): HtmlElement =
  let completed_count = self.todo.items.count((item) => item.completed)
  let active_count    = self.todo.items.len - completed_count
  let all_completed   = completed_count == self.todo.items.len

  let filtered =
    case self.filter:
    of all:       self.todo.items
    of completed: self.todo.items.filter((item) => item.completed)
    of active:    self.todo.items.filter((item) => not item.completed)

  proc create_new(e: KeydownEvent) =
    if e.key == "Enter" and not self.new_todo.is_empty:
      self.todo.items.add(TodoItem(text: self.new_todo, completed: false))
      self.new_todo = ""

  proc toggle_all(e: ChangeEvent) =
    self.todo.items.each((item: TodoItem) => (item.completed = not all_completed))

  proc on_delete(id: string) =
    self.todo.items.delete((item) => item.id == id)

  proc set_filter(filter: TodoViewFilter): auto =
    proc = self.filter = filter

  h"header.header":
    + h"h1".text("todos")
    + h"input.new-todo autofocus".attr("placeholder", "What needs to be done?")
      .bind_to(self.new_todo, true)
      .on_keydown(create_new)

    if not self.todo.items.is_empty:
      + h"section.main":
        + h"input#toggle-all.toggle-all type=checkbox"
          .value(all_completed)
          .on_change(toggle_all)
        + h"label for=toggle-all".text("Mark all as complete")

        + h"ul.todo-list":
          for item in filtered:
            # Feature: statefull componenets, attr names and values are typesafe
            let item = item
            + self.h(TodoItemView, item.id, (on_delete: on_delete, item: item))

        + h"footer.footer":
          + h"span.todo-count":
            + h"strong".text(active_count)
            + h"span".text((if active_count == 1: "item" else: "items") & " left")

          proc filter_class(filter: TodoViewFilter): string =
            if self.filter == filter: ".selected"  else: ""

          + h"ul.filters":
            + h"li":
              + h"a{all.filter_class}".text("All")
                .on_click(set_filter(all))
            + h"li":
              + h"a{active.filter_class}".text("Active")
                .on_click(set_filter(active))
            + h"li":
              + h"a{completed.filter_class}".text("Completed")
                .on_click(set_filter(completed))

          if all_completed:
            + h"button.clear-completed".text("Delete completed")
              .on_click(proc = self.todo.items.delete((item) => item.completed))

proc on_timer*(self: TodoView): bool =
  true

when is_main_module:
  # Deploying to Nim Server, also could be compiled to JS and deployed to Browser or Desktop App with WebView
  import mono/http, std/os

  let page: AppPage = proc(meta, html: string): string =
    """
      <!DOCTYPE html>
      <html>
        <head>
          <link rel="stylesheet" href="/assets/todo.css"/>
        </head>
        <body>
          <section class="todoapp">

      {html}

      <script type="module">
        import { run } from "/assets/mono.js"
        run()
      </script>

          </section>
        </body>
      </html>
    """.dedent.replace("{html}", html)

  let todo = Todo(items: @[TodoItem(text: "Buy Milk")])

  proc build_app(url: Url): tuple[page: AppPage, app: App] =
    let todo_view = TodoView()
    todo_view.set_attrs(todo = todo)

    let app: App = proc(events: seq[InEvent], mono_id: string): seq[OutEvent] =
      todo_view.process(events, mono_id)

    (page, app)

  # Path to folder with CSS styles and images
  let assets_path = current_source_path().parent_dir.absolute_path
  run_http_server(build_app, port = 2000, asset_paths = @[assets_path])