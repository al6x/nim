import basem, logm, jsonm, fsm as fs, envm, persistencem
{.experimental: "code_reordering".}


# FsSessions ---------------------------------------------------------------------------------------
# Simple session with local file system as a storage
type FsSessions*[T] = object
  path*: string

proc init*[T](
  _:     type[FsSessions[T]],
  path = env["fs_session_path", "./tmp/sessions"]
): FsSessions[T] =
  FsSessions[T](path: path)


# [], []=, delete ----------------------------------------------------------------------------------
proc `[]`*[T](sessions: FsSessions[T], id: string): T =
  T.read_from(sessions.fs_path(id))

proc `[]=`*[T](sessions: FsSessions[T], id: string, session: T) =
  session.write_to(sessions.fs_path(id))

proc delete*[T](sessions: FsSessions[T], id: string) =
  fs.delete(sessions.fs_path(id))

proc delete*[T](sessions: FsSessions[T]) =
  fs.delete(sessions.path, recursive = true)


# Helpers ------------------------------------------------------------------------------------------
func fs_path(sessions: FsSessions, id: string): string =
  fmt"{sessions.path}/{id.take(2)}/{id}.json"


# Test ---------------------------------------------------------------------------------------------
when is_main_module:
  type TestSession = ref object
    value: int

  proc init*(_: type[TestSession]): TestSession = TestSession(value: 1)

  let sessions = FsSessions[TestSession].init(path = "./tmp/test_sessions")
  sessions.delete("jim")
  var session = sessions["jim"]
  assert session.value == 1
  session.value = 2
  sessions["jim"] = session
  assert sessions["jim"].value == 2