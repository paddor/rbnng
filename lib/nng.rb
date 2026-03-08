require "nng/rbnng"
require "nng/version"

module NNG
  module Socket
    class Base
      alias_method :send_msg, :send
      alias_method :get_msg, :receive
    end
  end
end
require "nng/socket/readable"
require "nng/socket/writable"
require "nng/socket/pair0"
require "nng/socket/pair1"
require "nng/socket/bus0"
require "nng/socket/pub0"
require "nng/socket/sub0"
require "nng/socket/push0"
require "nng/socket/pull0"
require "nng/socket/req0"
require "nng/socket/rep0"
require "nng/socket/surveyor0"
require "nng/socket/respondent0"
