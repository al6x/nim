The bottleneck for the most code is not performance, but productivity: the speed it can be written
and the monetary cost of the developers. It's the biggest downside of Nim that it optimises what's
cheap and abundant - the performance, by spending what's costly and rare - developer time needed
to write the code.

It still surprises me, after 1 year of working heavily with Nim.

Future in programming languages is not about machines or machine optimised languages. Machines will
be fine and will be fast. Every 3 year computing powers doubles, algorithms and perf optimisers
gets better. The problem is not the machines or better compilers.

The bigest problem in Computer Science is old and weak human brain, that's not designed for digital
world and don't improves every 3 years. The future is in languages who would focus on humans and
make it easier to work with digital world.

Type Infer is not considered important https://forum.nim-lang.org/t/8259#53213

For me the biggest Nim issue is that its priorities are different from mine. So this criticism is
biased.

My priorities are to work with nice and beautifull tools and make money. Simple and clean code. High
productive way to build software. It's ok if I had to pay for that with some overhead and higher
CPU and Mem usage. Like say anything less than x4 times more CPU and Memory will be fine, I'm
willing to pay that, and if it's less than x2 it's ideal.

Nim priorities are to have zero-overhad CPU, asmost zero-overhead Mem, hard real-time and nice code.
Those are nice goals, the problem is - what's the cost? The cost is that these goals are incredibly
hard to achive (as far as I know nobody achieved it yet). The cost is the time you have to wait, you
need to wait maybe 2-5-10 years or maybe more, untill it will be possible. As right now Nim doesn't
achive it yet. Trying to excel at everything Nim excels at nothing. And has issues both as a language
and as a fast and reliable multicore or IO server.

So that's why I'm complaining about Nim. I don't have nice and clean language Nim could be right
now if it accepted to tolerate a little bit CPU or Mem overhead and spent more time on improving the
language itself.

Right now Nim is suitable for command line utilities and scripts, maybe some embedded software and
other special cases. For other use cases, it would be much better to choose other language. It's
possible to write say servers or web dev in Nim, but you achieve much better results with other
languages and tools.

Issues with Nim:

- Simple and very needed issues [like this one](https://github.com/nim-lang/RFCs/issues/8) are
  ignored for years (5 years) for quest to get holy grail of zero-overhead and GC-less memory
  management. Which in reality is holy grail and not working anyway, and in practical case could be
  slower than Node.JS, where it's constantly crashes or accidentally block IO-loop with sync IO-call.
  Or if you use non-ref for large data object and pass it around. In theory nim is high performant,
  in practice it's extremelly hard and fragile to be used for anything other than command-line
  scripts.
- No copy-on-write. The default way to define data structures in Nim is `object`. But if you not
  careful and use `object` for large data and pass it around, it going to be copied and the program
  going to be slower than Python.
- object vs ref. and move semantic. To achieve highest performance and hard real-time Nim needs
  fine grained control over object memory layout, object copying and destruction. And it's
  great features if you need it. But if you don't, and in most practical use cases there's no
  need such high performance, you still needs to pay attention to value vs. ref and it's a burden,
  some [feedback from biologist](http://lh3.github.io/2020/05/17/fast-high-level-programming-languages).
- No support for parallelism. Nether for CPU nor IO. Async is very unstable and async in general
  is bad approach. But what pretty much makes async in Nim useless is a) the ability to block async
  loop by IO, b) fragmentation by sync and async IO. Writing reliable and fast servers is so hard
  that it makes no sense to write it in Nim.
- Nim core team focus on low-level performance details, hard real time, hard limits for
  memory etc. And don't have much interest or time left form making the great developer experience,
  making language and standard libraries flexible and simlpe to use. Lots of language features
  ignored for years, and all the effort of core devs spent on something like making GC a little
  bit more performant.
- Macros, works well for simple cases. For complex things macros are very hard to use, like
  learning different language. Because macros are not homoiconic and AST structure is different
  from the language structure.
- Macros, allow core devs to ignore feature requests. As when someone points to the lack of feature,
  like "it's hard to initialise objects, too much boilerplate". The answer from the core team
  is, instead of recognizing the problem and finding ways to address it - the answer is
  "write macros".
- Nim core team and nim community focus on use cases like command-line utilities, embedded software,
  system prgramming, and have little interest in server or networking, reliable long running
  processes, web development, etc. So those domains are not only under developed, but also problems
  are ignored and marked as non important, and probably won't be addressed in the future too.
- Not enough focus in Nim community for simple and clean code. Something like zero-overhead for
  collection iteration considered extemelly important. And keeping API clean and simple is second
  priority.
- Nim for data processing, not so good either. The Nim language itself is very good fit
  for data processing. But the Nim core team and community focussed so much on performance and
  low-level details that the libraries and API are not as simple as they could have been. The high
  performance has its cost, that cost is the Nim code and libraries and APIs are not as simple as
  they could have been, like say in Python. So your productivity and ability to experiment fast are
  not as high as in say Python.
- No simple built-in profiler. Not really a problem for people knowing C, as Nim works well with
  C-profilers. But if you don't know C-profilers and just need to find the bottleneck in your code
  there's no simple way, you need to learn how to use C-profilers and how to use it with Nim.




The amount of bugs and suprises in Nim is just mind blowing. I'm using Nim almost a year and it still continue to surprise me every second day. It feels more fragile after 10 years of development than Node.JS in its early days.

I mostly use Nim for data processing. But I also tried to use it for web dev and recently build some web service with Nim. Bugs and missing features keept coming non stop. Eventually I got tired and switched to Node.JS. Finished service in half (or even third) time spent on Nim version, and it worked since without a single issue.

So eventually I given up on using Nim for anything except one-time-run data processing scripts, but even in this simple case, it still work unreliably and surprises are common practice (like null pointers not caught by except clause, etc).

The current state of Nim:

Multicore - unusable for practical projects, there are some experimental work, but nothing more.

Networking - async is working, but immature, lacks features and libraries, buggy, and require expert knowledge to be usable.

Language - the core is nice. But there are so much extra stuff and complications that's using it feels like piloting a space ship. And even when you learn it, it still not enough and Nim keeps surprising you.

Macros - great for simple tings. For anything more complex, to use macros is almost like learning a whole new language.

Simple and very needed issues [like this one](https://github.com/nim-lang/RFCs/issues/8) are ignored for years (5 years). I guess such features considered as insignificant and unimportant.

Nim core team and large part of nim community focus on use cases like command-line utilities, embedded software, system prgramming, and have little interest in server or networking, reliable long running processes, web development, etc. So those domains are not only under developed, but also problems are ignored and marked as non important, and probably won't be addressed in the future too.

# Anoying examples

The `assert` won't print values, `assert actual == expected`, no way to know the value of actual from the output.

The string format don't have escape, this fails `"a\"b".replace(re"\"", "")` but this works `"a\"b".replace(re("\""), "")`.

The `iterator.to_seq` not working, need to do `to_seq(iterator)`.

The `to_seq` not overloaded properly [link](https://forum.nim-lang.org/t/10056)

Lambda doesn't work with `void` return type, code below would fail

```Nim
import std/sugar

proc on_click(fn: proc(event: string): void): void =
  discard

on_click((e) => discard)
```

Inability to resolve (overload) property attr and proc with same name.

```Nim
import std/tables

type Element* = ref object
  tag*:   string
  attrs*: Table[string, string]

proc attrs*[T](self: T, attrs: tuple): T =
  for k, v in attrs.field_pairs:
    self.attrs[k] = $v
  return self

proc h*(tag: string): Element =
  Element(tag: tag)

echo h("dif").attrs((class: "some"))[]
```

Need to wrap `discard` into brackets, doesn't compile without it

```Nim
import std/sugar

proc on_click(fn: (string) -> void): void =
  discard

on_click((e: string) => (discard)) # <=
```

Inheritance doesn't autocast to parent type, code below would fail because Cow can't be added to
collection of type Animal

```
type Animal = ref object of RootObj
type Cow = ref object of Animal
var animals: seq[Animal]
animals.add Cow()                    # <= works
let animals2: seq[Animal] = @[Cow()] # <= error
```

Templates may produce unexpected results

```Nim
type Some = ref object
  v: int

template somefn(a: Some): int =
  a.v = 2
  a.v

let some = Some(v: 1)
echo somefn(some)       # => 2

echo somefn(Some(v: 1)) # => 1
```

Object variant can't share same field name, code below would fail to compile. And this problem is
refused to be fixed and the suggestion is to just share that field on all variant branches, which is
defeats the whole point of using object variants.

```Nim
type EventType* = enum location, click, change
type Event* = object
  case kind*: EventType
  of location:
    location*: Url
  of click:
    el_id*: string
    click*: ClickEvent
  of change:
    el_id*:  string # <= Error, redefinition of el_id
    change*: ChangeEvent
```

Tons of random inconsistiencies like these.

String interpolation doesn't work for template arguments, code below would fail

```
import std/strformat

template button*(size = "w-5 h-5") =
  echo fmt"{size}"

template layout*() =
  button()

layout()
```

String interpolation is very fragile and breaks in many cases especialy when mixing many templates,
for examlpe for HTML building DSL.

Templates are very fragile, should be used only minimally, tried to use it for HTML templating DSL
tons of edge cases.