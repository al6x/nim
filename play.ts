class None {
  is_some(): boolean { return false }
  is_none(): boolean { return true }
}

const none = new None()

interface Number {
  is_some(): boolean
  is_none(): boolean
}

Number.prototype.is_none = function is_none() { return false }
Number.prototype.is_some = function is_some() { return true }

console.log([none, 10].)