require "mkmf"

pkg_config("libnng") || dir_config("nng")
have_library("nng", "nng_version") || abort("libnng not found")
have_header("nng/nng.h") || abort("nng/nng.h not found")
have_header("nng/supplemental/tls/tls.h")

create_makefile("nng/rbnng")
