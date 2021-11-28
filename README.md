# RBNNG - nng for ruby

[nng](https://nng.nanomsg.org/) is a lightweight, broker-less messaging library.
This gem provides an API to interact with nng using a Ruby C extension.

## Installing

1. Install nng (consult your distro). If using Homebrew

   ```
   brew install nng
   ```

1. If nng is installed outside of `$PATH`, you can specify its location.

   e.g. for homebrew on linux

   ```
   gem install nng -- \
      --with-nng-lib=$HOME/.linuxbrew/Cellar/nng/1.5.2/lib \
      --with-nng-include=$HOME/.linuxbrew/Cellar/nng/1.5.2/include
   ```

   Use `gem install nng --pre` if trying to install an unreleased version.

## Examples

Examples can be found under the [demos](demos/) directory.

## Todo

-  General

   -  [x] Better error handling
   -  [ ] Add configuration options

-  Protocols
   -  [x] Req0/Rep0
   -  [x] Pair0/Pair1
   -  [x] Pub0/Sub0
   -  [x] Bus0
   -  [x] Survey0
   -  [x] Pipeline0
