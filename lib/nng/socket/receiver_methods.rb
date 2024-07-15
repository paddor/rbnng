begin
  require 'io/wait'
rescue LoadError
end

module NNG
  module Socket
    module ReceiverMethods
      def self.included(mod)
        if ::IO.method_defined? :wait_readable
          mod.prepend Async
        end
      end

      def recv_fd
        get_opt_int 'recv-fd'
      end

      def recv_timeout
        get_opt_ms 'recv-timeout'
      end

      def recv_timeout=(seconds)
        set_opt_ms 'recv-timeout', seconds
      end


      module Async
        def get_msg
          super if wait_readable
        end

        def recv_io
          @recv_io ||= ::IO.for_fd recv_fd, autoclose: false
        end

        def recv_timeout=(seconds)
          super
          recv_io.timeout = seconds
        end

        def wait_readable
          recv_io.wait_readable
        end
      end
    end
  end
end
