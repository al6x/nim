import { assert, something, p } from 'bon/base.ts'

let jQuery = (window as something).jQuery

// Types -------------------------------------------------------------------------------------------
export type TInput = string | number | boolean | Element | Document | TElement | { is_telement: true }
  // | JSX.Element | JSX.Element[]

export type EventType =
  'touchstart' | 'touchend' |
  'click' | 'dblclick' | 'blur' | 'focus' |
  'change' | 'submit' |
  'keydown' | 'keypress' | 'keyup' |
  'popstate' | 'pushstate' | 'resize'


// TEvent ------------------------------------------------------------------------------------------
export class TEvent {
  public readonly target: TElement
  public readonly current_target: TElement

  constructor(
    public readonly native: Event
  ) {
    if (!native.target) throw new Error(`target not defined`)
    this.target = new TElementImpl(native.target as something)
    if (!native.currentTarget) throw new Error(`currentTarget not defined`)
    this.current_target = new TElementImpl(native.currentTarget as something)
  }

  prevent_default(): void { this.native.preventDefault() }
  stop_propagation(): void { this.native.stopPropagation() }
}


// TElement ----------------------------------------------------------------------------------------
export interface TElement {
  readonly is_telement: true
  readonly native: HTMLElement

  once(id: string, fn: () => void): void

  hide(): void
  show(): void

  on(event: EventType, fn: (e: TEvent) => void): void
  on(event: EventType, selector: string, fn: (e: TEvent) => void): void

  off(event: string): void
  off(event: string, fn: (e: TEvent) => void): void

  find(query: string): TElement[]
  find_one(query: string): TElement
  find_by_id(id: string): TElement
  find_parents(query: string): TElement[]
  find_parent(query: string): TElement
  get_parent(): TElement

  get_data(name: string): something
  set_data(name: string, value: something): void

  get_attr(name: string): string | undefined
  set_attr(name: string, value: string | number | boolean | null | undefined): void
  set_attrs(attrs: { [name: string]: string | number | boolean | null | undefined }): void
  remove_attr(name: string): void
  ensure_attr(name: string): string

  get_style(name: string): string | undefined
  set_style(name: string, value: string | number | boolean | null | undefined): void
  set_styles(attrs: { [name: string]: string | number | boolean | null | undefined }): void
  ensure_style(name: string): string

  add_class(klass: string): void
  remove_class(klass: string): void

  get_html(): string
  set_content(html: TInput | TInput[]): void
  get_content(): string
  get_text_content(): string

  replace_with(html: TInput | TInput[]): void
  prepend(html: TInput | TInput[]): void
  append(html: TInput | TInput[]): void
  insert_before_self(html: TInput | TInput[]): void
  insert_after_self(html: TInput | TInput[]): void
  remove(): void

  trigger(event: EventType): void

  flash(): void
  waiting<T>(fn: () => Promise<T>): Promise<T>
}

export function is_telement(v: unknown): v is TElement {
  return v instanceof Object && 'is_telement' in v
}

// TDocument ---------------------------------------------------------------------------------------
export interface TContainer<T> {
  readonly native: T

  on(event: EventType | EventType[], fn: (e: TEvent) => void): void
  on(event: EventType | EventType[], selector: string, fn: (e: TEvent) => void): void

  off(event: EventType | EventType[]): void
  off(event: EventType | EventType[], fn: (e: TEvent) => void): void
  off(event: EventType | EventType[], selector: string, fn: (e: TEvent) => void): void

  find(query: string): TElement[]
  find_one(query: string): TElement
  find_by_id(id: string): TElement
}


// TElementStatic ----------------------------------------------------------------------------------
export interface TElementStatic {
  (document: Event):     TEvent
  (document: Document):  TContainer<Document>
  (window:   Window):    TContainer<Window>
  (element:  Element):   TElement
  (elements: Element[]): TElement[]

  find(query: string): TElement[]
  find_one(query: string): TElement
  find_by_id(id: string): TElement

  build(html: string): TElement[]
  build_one(html: string): TElement
}


// TElementImpl -----------------------------------------------------------------
export class TElementImpl implements TElement {
  public readonly is_telement = true
  protected readonly $el: something
  constructor(
    public readonly native: HTMLElement
  ) {
    this.$el = jQuery(native)
  }

  once(id: string, fn: () => void) {
    if (!this.get_data(`once-${id}`)) {
      fn()
      this.set_data(`once-${id}`, true)
    }
  }

  hide() { this.$el.hide() }
  show() { this.$el.show() }

  on(...args: something[]) { this.$el.on(...transform_tattrs_to_jquery(args)) }
  off(...args: something[]) { this.$el.off(...transform_tattrs_to_jquery(args)) }

  find(query: string): TElement[] {
    return this.$el.find(query).toArray().map((el: something) => new TElementImpl(el))
  }
  find_one(query: string) {
    const found = this.find(query)
    assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`)
    return found[0]
  }
  find_by_id(id: string) {
    return this.find_one(`#${id}`)
  }
  find_parents(query: string) {
    return this.$el.parents(query).toArray().map((el: something) => new TElementImpl(el))
  }
  find_parent(query: string) {
    const found = this.find_parents(query)
    assert.equal(found.length, 1, `required to find exactly 1 parent '${query}' but found ${found.length}`)
    return found[0]
  }
  get_parent() {
    const parent = this.$el.parent()
    assert(parent.length == 1, `element has no parent`)
    return new TElementImpl(parent.get(0))
  }

  get_data(name: string) { return this.$el.data(name) }
  set_data(name: string, value: something) { this.$el.data(name, value) }

  get_attr(name: string) { return name == 'value' ? this.$el.val() : this.$el.attr(name) }
  set_attr(name: string, value: something) {
    if (name == 'value') this.$el.val(value)
    this.$el.attr(name, value)
  }
  set_attrs(attrs: something) { for (const key of attrs) this.set_attr(key, attrs[key]) }
  remove_attr(name: string) {
    if (name == 'value') this.$el.val('')
    else this.$el.remove_attr(name)
  }
  ensure_attr(name: string) {
    const value = this.get_attr(name)
    assert(!!value, `missing '${name}' attribute`)
    return value
  }

  get_style(name: string) { return this.$el.css(name) }
  set_style(name: string, value: something) { return this.$el.css(name, value) }
  set_styles(attrs: something) { return this.$el.css(attrs) }
  ensure_style(name: string) {
    const value = this.get_style(name)
    assert(!!value, `missing '${name}' style`)
    return value
  }

  add_class(klass: string) { this.$el.addClass(klass) }
  remove_class(klass: string) { this.$el.removeClass(klass) }

  get_html() { return this.$el[0].outerHTML }
  set_content(html: TInput | TInput[]) {
    this.$el.html(unwrap(html))
    this.trigger_new_content_added(this)
  }
  get_content() { return this.$el.html() }
  get_text_content() { return this.$el.text() }

  replace_with(html: TInput | TInput[]) {
    const $parent = this.get_parent()
    this.$el.replaceWith(unwrap(html))
    this.trigger_new_content_added($parent)
  }
  prepend(html: TInput | TInput[]) {
    this.$el.prepend(unwrap(html))
    this.trigger_new_content_added(this)
  }
  append(html: TInput | TInput[]) {
    this.$el.append(unwrap(html))
    this.trigger_new_content_added(this.get_parent())
  }
  insert_before_self(html: TInput | TInput[]) {
    this.$el.before(unwrap(html))
    this.trigger_new_content_added(this.get_parent())
  }
  insert_after_self(html: TInput | TInput[]) {
    this.$el.after(unwrap(html))
    this.trigger_new_content_added(this.get_parent())
  }
  remove() { this.$el.remove() }

  trigger(event: EventType) { this.$el.trigger(event) }

  flash() { flash(this) }
  waiting<T>(fn: () => Promise<T>): Promise<T> { return waiting(this, fn) }

  trigger_new_content_added(el: TElement) {}
}


// MonDocumentImpl ----------------------------------------------------------------
export class TContainerImpl<T> implements TContainer<T> {
  protected readonly $el: something
  constructor(
    public readonly native: T
  ) {
    this.$el = jQuery(native)
  }

  on(...args: something[]) { this.$el.on(...transform_tattrs_to_jquery(args)) }
  off(...args: something[]) { this.$el.off(...transform_tattrs_to_jquery(args)) }

  find(query: string): TElement[] {
    return this.$el.find(query).toArray().map((el: something) => new TElementImpl(el))
  }
  find_one(query: string) {
    const found = this.find(query)
    assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`)
    return found[0]
  }
  find_by_id(id: string) {
    return this.find_one(`#${id}`)
  }
}


// $ ------------------------------------------------------------------------------
export const $: TElementStatic = wrap as something
$.find = find
$.find_one = find_one
$.find_by_id = find_by_id
$.build = build
$.build_one = build_one

function wrap(arg: Event):         TEvent
function wrap(arg: TEvent):        TEvent
function wrap(arg: Window):        TContainer<Window>
function wrap(arg: Document):      TContainer<Document>
function wrap(arg: TElement):      TElement
function wrap(arg: HTMLElement):   TElement
function wrap(arg: HTMLElement[]): TElement[]
function wrap(arg: Event | TEvent | Window | Document | TElement | HTMLElement | HTMLElement[]): something {
  if      (arg instanceof TEvent)   return arg
  else if ('is_telement' in arg)    return arg
  else if (arg instanceof Array)    return arg.map((el) => new TElementImpl(el))
  else if (arg instanceof Window)   return new TContainerImpl(arg)
  else if (arg instanceof Document) return new TContainerImpl(arg)
  else if (arg instanceof Event)    return new TEvent(arg)
  else                              return new TElementImpl(arg)
}
export { wrap }

export function find(query: string): TElement[] {
  return jQuery(query).toArray().map((el: something) => new TElementImpl(el))
}

export function find_one(query: string): TElement {
  const found = find(query)
  assert.equal(found.length, 1, `required to find exactly 1 '${query}' but found ${found.length}`)
  return found[0]
}

export function find_by_id(id: string): TElement {
  return find_one(`#${id}`)
}

export function build(html: TInput): TElement[] {
  return jQuery(unwrap(html)).toArray().map((el: something) => new TElementImpl(el))
}

export function build_one(html: TInput): TElement {
  const elements = build(html)
  assert.equal(elements.length, 1, `required to build exactly 1 element but found ${elements.length}`)
  return elements[0]
}


// flash --------------------------------------------------------------------------
const updateTimeouts: { [key: string]: something } = {}
function flash($el: TElement): void {
  const timeout = 1500 // should be same as in CSS animation
  const id = $el.get_attr('id')
  if (id) {
    // ID used when flash repeatedly triggered on the same element, before the previous flash has
    // been finished. Without ID such fast flashes won't work properly.
    // Example - frequent updates from the server changing counter.
    if (id in updateTimeouts) {
      clearTimeout(updateTimeouts[id])
      $el.remove_class('flash')
      void ($el.native as something).offsetWidth
    }
    $el.add_class('flash')

    updateTimeouts[id] = setTimeout(() => {
      $el.remove_class('flash')
      delete updateTimeouts[id]
    }, timeout)
  } else {
    $el.add_class('flash')
    setTimeout(() => $el.remove_class('flash'), timeout)
  }
}


// waiting -----------------------------------------------------------------------------------------
export async function waiting<T>(arg: Event | TEvent | Element | TElement, fn: () => Promise<T>): Promise<T> {
  let $element: TElement
  if ((arg instanceof TEvent) || (arg instanceof Event)) {
    let event: Event = arg instanceof TEvent ? arg.native : arg
    event.preventDefault()
    event.stopPropagation()
    $element = $(event.currentTarget as Element)
  } else {
    $element = 'is_telement' in arg ? arg : $(arg)
  }

  $element.add_class('waiting')
  try {
    return await fn()
  } finally {
    $element.remove_class('waiting')
  }
}


// Utils --------------------------------------------------------------------------
function transform_tattrs_to_jquery(args: something[]): something[] {
  args = [...args]

  // Transforming list of events into string event `['click', 'touchstart']` => `"click touchstart"`
  if (args[0] instanceof Array) args[0] = args[0].join(' ')

  // Wrapping Event as TEvent
  const fn = args.pop()
  assert(fn instanceof Function, `wrong listener arguments`)
  if (!fn.TEventWrapper) fn.TEventWrapper = (e: something) => fn(new TEvent(e))
  args.push(fn.TEventWrapper)
  return args
}

// Unwrap from JSX.Element or TElement to string or HTMLElement
function unwrap(input: something): something {
  if      (input instanceof Array)
    return input.map((v) => unwrap(v))
  // else if (is_element(input))
  //   return render(input)
  else if (input && input instanceof Object && input.is_telement)
    return input.native
  else
    return input
}

export function get_form_data($form: TElement): { [key: string]: string } {
  const list = jQuery($form.native as something).serializeArray()
  const result: {[key: string]: string } = {}
  for (let { name, value } of list) result[name] = value
  return result
}


// Document observer --------------------------------------------------------------
// const newContentInElementListeners: (($el: TElement) => void)[] = []
// export function afterthis.trigger_new_content_addedElement(listener: ($el: TElement) => void) {
//   newContentInElementListeners.push(listener)
// }
// export function this.trigger_new_content_added($el: TElement) {
//   for (const listener of newContentInElementListeners) listener($el)
// }
// export function this.trigger_new_content_addedDocument() {
//   const $el = new TElementImpl(document.body)
//   for (const listener of newContentInElementListeners) listener($el)
// }

// // Globals ------------------------------------------------------------------------
// Object.assign(window.mono, { this.trigger_new_content_addedDocument, $: jQuery })
