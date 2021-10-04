{.passL: "-lgsl".}

const libgsl =
  when defined(windows): "gsl.dll"
  elif defined(macosx):  "libgsl.dylib"
  else:                  "libgsl.so"

proc gsl_cdf_gaussian_P*(x: cdouble; sigma: cdouble): cdouble {.cdecl, importc, dynlib: libgsl.}

type
  gsl_rng_type* {.bycopy.} = object
    name*: cstring
    max*: culong
    min*: culong
    size*: csize_t
    set*: proc (state: pointer; seed: culong) {.cdecl.}
    get*: proc (state: pointer): culong {.cdecl.}
    get_double*: proc (state: pointer): cdouble {.cdecl.}

  gsl_rng* {.bycopy.} = object
    `type`*: ptr gsl_rng_type
    state*: pointer

var gsl_rng_default_seed* {.importc, dynlib: libgsl.}: culong
var gsl_rng_default* {.importc, dynlib: libgsl.}: ptr gsl_rng_type

proc gsl_rng_uniform*(r: ptr gsl_rng): cdouble {.cdecl, importc, dynlib: libgsl.}
proc gsl_rng_alloc*(T: ptr gsl_rng_type): ptr gsl_rng {.cdecl, importc, dynlib: libgsl.}
proc gsl_rng_free*(r: ptr gsl_rng) {.cdecl, importc, dynlib: libgsl.}
proc gsl_ran_gaussian*(r: ptr gsl_rng; sigma: cdouble): cdouble {.cdecl, importc, dynlib: libgsl.}
proc gsl_rng_uniform_int*(r: ptr gsl_rng; n: culong): culong {.cdecl, importc, dynlib: libgsl.}
