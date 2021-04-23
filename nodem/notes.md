# Async problems

- No return without return await? No return without {.async.}?
- Huge and meaningless stack trace and error messages, "too many files".
- x2 amount of code that needed to be written.
- Practically it's more like x3, because async code is much harder to dealt with.
- As a short-term solution async is tolerable, as long term... hopefully one day Nim will deprecate it.
- Lack of async libraries, solved, using Elixir-bridge.
- Easy to block the loop, solved, with Elixir-bridge.
- Nice compiler check for `check_async`.
- Best solution - avoid async, unless very rarely for bottleneck code, proved with benchmark.

# Let's make async great again! As it was in old JS times.

Seems like we have to live with `async`, let's think if we can improve how it's used. I used Nim async
and it looks to me, compared to the experience of Async in JavaScript, there are couple of things could be improved.

1 Use same `await` instead of `wait_for` if async needs to be called in sync function.

2 No sync IO instead of async proc allowed, mark all non-async IO with `syncio` and throw error if it's used
in async proc. It is ok to block async event loop with CPU, it terrible if it's blocked with sync-IO.

3 Allow implicit return from async functions.

4 Allow to return future from async function.

5 Rename `async_check` as `spawn(Future)` or `check(Future)`.

6 Remove `run_forewer`, if there's at least one listener registered on the event loop keep process running.

7 Don't print ugly multi-page async error stack traces, if it can't be made short and clean it's better to
not print it at all, as they are usually useless anyway.

8 `with_timeout` should throw error or return `Future[T]`, not `Future[bool]`.

9 Maybe Stop using `{.async.}` the code is noisy, if function returns `Future` it's async.

What do you think? If we have to live with it, let's make it great! :)


# Why and how I'm using it

Nim has small memory footprint and is CPU-fast. Nim doesn't have good parallel capabilities yet, and while it
has async-IO and it's fast it's not good enough. Async is machine-level code, like C, nobody uses it if
there is a better choice, or special case (Node.JS no exception, there's just no other choice in JS).

I want those features right now. **Simple parallel Nim code** and **simple and fast IO** with
**rich features and protocol** support. This library allows for me to
**travel into the future and get those features right now** (when I finish the Elixir bridge).

It's like using PostgreSQL, who cares if it's written in Nim or C or Go, it's just a black box you talk to
over network, I think Web IO is the same. And implementing fast Web Server in Nim or 10k Realtime Streaming via
WebSockets feels like reinventing PostgreSQL, waste of time. The Elixir-bridge is such PostgreSQL for Web and IO.

I want to create user products. Not spend my time on things like: realtime streaming, auth, rate-limits,
binary storage, Browser-IO integrations, server robustness, DB-access, scaling, MQ, caching, and so on and on.
Elixir-bridge provides all those features for Nim.

It spawn X single threaded Nim nodes for CPU parralelism. And uses Elixir-bridge for simple and fast
IO, drivers and protocols. Avoiding Nim-drivers and using Elixir-bridge instead for things like MongoDB etc. should
also help to keep Nim nodes memory footprint small.