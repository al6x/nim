import options, strutils, strformat, json
import ./nodem/asyncm, ./nodem/nexportm, ./nodem/httpm, ./nodem/nimportm

export httpm, nexportm, nimportm, asyncm, json


# run ----------------------------------------------------------------------------------------------
proc run*(node: Node, on_error: OnError = default_on_error): Future[void] =
  node.receive_async(call_nexport_function_async, on_error, catch_node_errors)

proc run_forever*(node: Node, on_error: OnError = default_on_error): void =
  spawn_async node.run(on_error)
  run_forever()


# run_rest -----------------------------------------------------------------------------------------
proc run_rest*(
  url:       string,
  allow_get: seq[string] | bool = false, # GET disabled by default, for security reasons
  on_error:  OnError = default_on_error
): Future[void] =
  url.receive_rest_async(call_nexport_function_async, allow_get, on_error, catch_node_errors)

proc run_rest_forever*(
  url:       string,
  allow_get: seq[string] | bool = false, # GET disabled by default, for security reasons
  on_error:  OnError = default_on_error
): void =
  spawn_async url.run_rest(allow_get, on_error)
  run_forever()


# mount_nexports_as_rest_on ------------------------------------------------------------------------
proc mount_nexports*[HttpServerT](
  server:    HttpServerT,
  url:       string,
  allow_get: seq[string] | bool = false, # GET disabled by default, for security reasons
  on_error:  OnError = default_on_error
): void =
  url.receive_rest_async(call_nexport_function_async, allow_get, on_error, catch_node_errors)