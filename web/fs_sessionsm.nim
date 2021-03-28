import basem, logm, jsonm, fsm as fs, envm, persistencem, timem
{.experimental: "code_reordering".}


# FsSessions ---------------------------------------------------------------------------------------
# Simple session with local file system as a storage
type FsSessions*[T] = object
  path*:           string
  expiration_sec*: int

proc init*[T](
  _:               type[FsSessions[T]],
  path           = env["fs_session_path", "./tmp/sessions"],
  expiration_sec = 30.days.seconds
): FsSessions[T] =
  FsSessions[T](path: path, expiration_sec: expiration_sec)


# SessionData --------------------------------------------------------------------------------------
type SessionData[T] = object
  session:   T
  timestamp: Time

proc init[T](_: type[SessionData[T]], session: T): SessionData[T] =
  SessionData[T](session: session, timestamp: Time.now)


# [], []=, delete ----------------------------------------------------------------------------------
proc `[]`*[T](sessions: FsSessions[T], id: string): T =
  let data = SessionData[T].read_from(sessions.fs_path(id), () => SessionData.init(T.init))
  if (Time.now.epoch - data.timestamp.epoch) < sessions.expiration_sec:
    return data.session

proc `[]=`*[T](sessions: FsSessions[T], id: string, session: T) =
  SessionData.init(session).write_to(sessions.fs_path(id))

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