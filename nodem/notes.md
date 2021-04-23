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