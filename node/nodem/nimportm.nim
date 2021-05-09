import basem, jsonm, macros
import ./http_nodem, ./nexportm

export jsonm, http_nodem

# nimport ------------------------------------------------------------------------------------------
macro nimport*(fn: typed): typed =
  # Import remote function from remote node to be able to call it

  let fsign  = fn_signature(fn)
  let (fname, args, rtype, is_async) = fsign
  let fsigns = fsign.to_s
  let full_name = fsigns.full_name
  let short_name = fsigns.short_name

  # Generating code
  if is_async: throw "async not supported"
  if rtype.kind == nnkSym and rtype.str_val == "void":
    case args.len:
    of 1:
      let (n, nt, _) = args[0]
      quote do:
        proc `fname`*(`n`: `nt`): void =
          call_nexport_fn_void(`short_name`, `full_name`, `n`)
    of 2:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`): void =
          call_nexport_fn_void(`short_name`, `full_name`, `n`, `a`)
    of 3:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]; let (b, bt, _) = args[2]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`, `b`: `bt`): void =
          call_nexport_fn_void(`short_name`, `full_name`, `n`, `a`, `b`)
    of 4:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]; let (b, bt, _) = args[2]; let (c, ct, _) = args[3]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`, `b`: `bt`, `c`: `ct`): void =
          call_nexport_fn_void(`short_name`, `full_name`, `n`, `a`, `b`, `c`)
    else:
      quote do:
        raise new_exception(Exception, "not supported, please update the code to suppor it")
  else:
    case args.len:
    of 1:
      let (n, nt, _) = args[0]
      quote do:
        proc `fname`*(`n`: `nt`): `rtype` =
          call_nexport_fn(`short_name`, `full_name`, `n`, typeof `rtype`)
    of 2:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`): `rtype` =
          call_nexport_fn(`short_name`, `full_name`, `n`, `a`, typeof `rtype`)
    of 3:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]; let (b, bt, _) = args[2]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`, `b`: `bt`): `rtype` =
          call_nexport_fn(`short_name`, `full_name`, `n`, `a`, `b`, typeof `rtype`)
    of 4:
      let (n, nt, _) = args[0]; let (a, at, _) = args[1]; let (b, bt, _) = args[2]; let (c, ct, _) = args[3]
      quote do:
        proc `fname`*(`n`: `nt`, `a`: `at`, `b`: `bt`, `c`: `ct`): `rtype` =
          call_nexport_fn(`short_name`, `full_name`, `n`, `a`, `b`, `c`, typeof `rtype`)
    else:
      quote do:
        raise new_exception(Exception, "not supported, please update the code to suppor it")


# call_nexport_fn ----------------------------------------------------------------------------------
proc call_nexport_fn[N](short_name: string, full_name: string, n: N, args: JsonNode): JsonNode =
  assert args.kind == JArray
  let res = try:
    # The `path` is not used by `nexport` server, but needed to support services written in REST
    # style as `/api/fname`.
    n.call((fn: full_name, args: args).to_json.to_s, path = "/" & short_name)
  except Exception as e:
    throw fmt"can't call '{n}.{full_name}', {e.msg}"

  let json = res.parse_json
  if json.kind == JObject and "is_error" in json: throw json["message"].get_str
  json

proc call_nexport_fn*[N, R](
  short_name: string, full_name: string, n: N, rtype: type[R]
): R =
  let args = newJArray(); args.add n.id.to_json;
  call_nexport_fn(short_name, full_name, n, args).to_json(R)

proc call_nexport_fn*[N, A, R](
  short_name: string, full_name: string, n: N, a: A, tr: type[R]
): R =
  let args = newJArray(); args.add n.id.to_json; args.add a.to_json;
  call_nexport_fn(short_name, full_name, n, args).to_json(R)

proc call_nexport_fn*[N, A, B, R](
  short_name: string, full_name: string, n: N, a: A, b: B, tr: type[R]
): R =
  let args = newJArray(); args.add n.id.to_json; args.add a.to_json; args.add b.to_json;
  call_nexport_fn(short_name, full_name, n, args).to_json(R)

proc call_nexport_fn*[N, A, B, C, R](
  short_name: string, full_name: string, n: N, a: A, b: B, c: C, tr: type[R]
): R =
  let args = newJArray(); args.add n.id.to_json; args.add a.to_json; args.add b.to_json; args.add c.to_json
  call_nexport_fn(short_name, full_name, n, args).to_json(R)

# For void
proc call_nexport_fn_void*[N](short_name: string, full_name: string, n: N): void =
  discard call_nexport_fn(short_name, full_name, n, string)

proc call_nexport_fn_void*[N, A](short_name: string, full_name: string, n: N, a: A): void =
  discard call_nexport_fn(short_name, full_name, n, a, string)

proc call_nexport_fn_void*[N, A, B](short_name: string, full_name: string, n: N, a: A, b: B): void =
  discard call_nexport_fn(short_name, full_name, n, a, b, string)

proc call_nexport_fn_void*[N, A, B, C](short_name: string, full_name: string, n: N, a: A, b: B, c: C): void =
  discard call_nexport_fn(short_name, full_name, n, a, b, c, string)