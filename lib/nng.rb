# frozen_string_literal: true

require 'timeout'
require 'nng/rbnng'
require 'nng/version'
require 'nng/tls'
require 'nng/socket/base'
require 'nng/socket/readable'
require 'nng/socket/writable'
require 'nng/socket/pair0'
require 'nng/socket/pair1'
require 'nng/socket/bus0'
require 'nng/socket/pub0'
require 'nng/socket/sub0'
require 'nng/socket/push0'
require 'nng/socket/pull0'
require 'nng/socket/req0'
require 'nng/socket/rep0'
require 'nng/socket/surveyor0'
require 'nng/socket/respondent0'

module NNG
  Msg = Message
end
