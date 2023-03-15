import base

type RingBuffer*[T] = object
  data: seq[T]
  oldest, count: int

proc init*[T](_: type[RingBuffer[T]]; size: int): RingBuffer[T] =
  RingBuffer[T](data: new_seq[T](size), oldest: 0, count: 0)

proc init*[T](_: type[RingBuffer[T]]; data: openarray[T]): RingBuffer[T] =
  RingBuffer[T](data: data.to_seq, oldest: 0, count: data.len)

proc len*(self: RingBuffer): int = self.count

proc is_empty*(self: RingBuffer): bool = self.count == 0

proc is_full*(self: RingBuffer): bool = self.count == self.data.len

proc add*[T](self: var RingBuffer[T], v: T) =
  if self.is_full:
    self.data[self.oldest] = v
    self.oldest = (self.oldest + 1) mod self.data.len
  else:
    self.data[self.oldest + self.count] = v
    self.count += 1

proc addget*[T](self: var RingBuffer[T], v: T): T =
  assert self.is_full, "can't get if buffer is not full"
  result = self.data[self.oldest]
  self.add(v)

proc add*[T](self: var RingBuffer[T], values: openarray[T]) =
  for v in values: self.add v

iterator items*[T](self: RingBuffer[T]): T =
  for i in 0..<self.count: yield self[i]

proc `[]`*[T](self: RingBuffer[T], i: int): T =
  self.data[(self.oldest + i) mod self.data.len]

test "RingBuffer":
  var b = RingBuffer[int].init(3)
  b.add 1
  assert b.len == 1
  assert b == RingBuffer[int](data: @[1, 0, 0], oldest: 0, count: 1)
  b.add 2
  assert b.to_seq == @[1, 2]
  b.add 3
  assert b[1] == 2
  assert b == RingBuffer[int](data: @[1, 2, 3], oldest: 0, count: 3)
  b.add 4
  assert b[1] == 3
  assert b.len == 3
  assert b == RingBuffer[int](data: @[4, 2, 3], oldest: 1, count: 3)
  assert b.addget(5) == 2
  assert b == RingBuffer[int](data: @[4, 5, 3], oldest: 2, count: 3)
  assert b.to_seq == @[3, 4, 5]