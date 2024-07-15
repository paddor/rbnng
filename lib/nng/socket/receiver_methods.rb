module NNG
  module Socket
    module ReceiverMethods
      def recv_fd
        get_opt_int 'recv-fd'
      end

      def recv_timeout
        get_opt_ms 'recv-timeout'
      end

      def recv_timeout=(seconds)
        set_opt_ms 'recv-timeout', seconds
      end
    end
  end
end
