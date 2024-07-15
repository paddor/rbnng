begin
  require 'io/wait'
rescue LoadError
end

module NNG
  module Socket
    module SenderMethods
      def self.included(mod)
        if ::IO.method_defined? :wait_readable
          mod.prepend Async
        end
      end

      def send_fd
        get_opt_int 'send-fd'
      end

      def send_timeout
        get_opt_ms 'send-timeout'
      end

      def send_timeout=(seconds)
        set_opt_ms 'send-timeout', seconds
      end


      module Async
        def send_msg(str)
          super if wait_writable
        end

        def send_io
          @send_io ||= ::IO.for_fd send_fd, autoclose: false
        end

        def send_timeout=(seconds)
          super
          send_io.timeout = seconds
        end

        def wait_writable
          send_io.wait_readable
        end
      end
    end
  end
end
