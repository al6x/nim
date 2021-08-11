Basically, it's like C, no much sense to use C for web or servers or data analysis. For some bottleneck code, system utils yes, but as a general language, no.

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