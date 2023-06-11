import base, mono/core

var mono_id* {.threadvar.}: string
proc before_processing_session*[T](session: Session[T]) = mono_id = session.id
proc after_processing_session*[T](session: Session[T]) = mono_id = ""

proc session_log*: Log = Log.init("Session", mono_id)