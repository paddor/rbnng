#
#    Copyright (c) 2021 Adib Saad
#
require 'mkmf'
dir_config('nng')

def header?
  have_header('nng/nng.h') ||
    find_header('nng/nng.h', '/opt/local/include', '/usr/local/include', '/usr/include')
end

def library?
  have_library('nng', 'nng_fini') ||
    find_library('nng', 'nng_fini', '/opt/local/lib', '/usr/local/lib', '/usr/lib')
end

if header? && library?
  create_makefile("nng/rbnng")
else
  raise "Couldn't find nng library. try setting --with-nng-dir=<path> to tell me where it is."
end
