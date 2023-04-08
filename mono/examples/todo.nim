import base, ../component, ../h


# Model --------------------------------------------------------------------------------------------
type TodoItemState = enum active, completed

type TodoItem = ref object
  text:      string
  completed: bool

type Todos = seq[TodoItem]

proc id(self: TodoItem): string =
  self.text


# TodoView -----------------------------------------------------------------------------------------
const enter_key  = 13; const escape_key = 27

# Feature: stateful component, preserving its state between renders
type TodoView = ref object of Component
  on_delete: proc(id: string): void
  editing:   Option[string] # value of `editing` field going to be maintained between requests
  item:      TodoItem

proc set_attrs(self: TodoView, item: TodoItem, on_delete: (proc(id: string): void)): void =
  self.item = item; self.on_delete = on_delete

proc render(self: TodoView): HtmlElement =
  proc handle_edit(e: KeydownEvent): void =
    if e.key == enter_key:
      self.item.text = self.editing.get
      self.editing.clear
    elif e.key == escape_key:
      self.editing.clear

  let class_modifier =
    (if self.item.completed: ".completed" else: "") &
    (if self.editing.is_some: ".editing" else: "")

  # Feature: compact HTML template syntax
  h"li.todo-list{class_modifier}":
    + h".view":
      + h"input.toggle type: checkbox"
        # Feature: two way binding with autocast
        .bind_to(self.item.completed)
      + h"label".text(self.item.text)
        .on_dblclick(proc = self.editing = self.item.text.some)
      + h"button.destroy"
        .on_click(proc = self.on_delete(self.item.id))
      if self.editing.is_some:
        + h"input.edit autofocus"
          .bind_to(self.editing)
          .on_keydown(handle_edit)
          .on_blur(proc = self.editing = string.none)


# TodosView -----------------------------------------------------------------------------------------
type Filter = enum all, active, completed

type TodosView = ref object of Component
  items:      Todos
  filter:     Filter
  new_todo:   string
  toggle_all: bool

proc set_attrs(self: TodosView, items: Todos = @[], filter: Filter = all): void =
  self.items = items; self.filter = filter

method render(self: TodosView): HtmlElement =
  let completed_count = self.items.count((item) => item.completed)
  let active_count    = self.items.len - completed_count
  let all_completed   = completed_count == self.items.len

  let filtered =
    case self.filter:
    of all:       self.items
    of completed: self.items.filter((item) => item.completed)
    of active:    self.items.filter((item) => not item.completed)

  proc create_new(e: KeydownEvent): void =
    if e.key == enter_key and not self.new_todo.is_empty:
      self.items.add(TodoItem(text: self.new_todo, completed: false))
      self.new_todo = ""

  proc toggle_all(e: ChangeEvent): void =
    self.items.each((item: TodoItem) => (item.completed = self.toggle_all))

  proc on_delete(id: string): void =
    self.items.delete((item) => item.id == id)

  proc set_filter(filter: Filter): auto =
    proc = self.filter = filter

  h"header.header":
    + h"h1".text("todos")
    + h"input.new-todo autofocus".attr("placeholder", "What needs to be done?")
      .bind_to(self.new_todo)
      .on_keydown(create_new)

    if not self.items.is_empty:
      + h"section.main":
        + h"input.toggle-all type=checkbox"
          .value(all_completed)
          .on_change(toggle_all)
        + h"label for=toggle-all".text("Mark all as complete")

        + h"ul.todo-list":
          for item in filtered:
            # Feature: statefull componenets, attr names and values are typesafe
            + self.h(TodoView, item.id, (on_delete: on_delete, item: item))

        + h"footer.footer":
          + h"span.todo-count":
            + h"strong".text(active_count)
            + h"span".text((if active_count == 1: "item" else: "items") & " left")

          proc filter_class(filter: Filter): string =
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
              .on_click(proc = self.items.delete((item) => item.completed))
