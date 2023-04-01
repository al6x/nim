import basem, randomm

# generate_id --------------------------------------------------------------------------------------
const letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".map((v) => v)
const letters_and_numbers = (letters.join("") & "0123456789").map((v) => v)
proc generate_id*(length = 6): string =
  var rgen = secure_rgen()
  # First character is letter
  letters.sample(rgen) & letters_and_numbers.sample(length - 1, rgen).join("")


# isKnownError -------------------------------------------------------------------------------------
proc decode_known_mongo_error*[E](error: E): Option[string] =
  if error.code in [11000, 11001]: return "not unique".some

if is_main_module:
  echo generate_id()