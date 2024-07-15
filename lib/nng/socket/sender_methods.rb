module NNG
  module Socket
    module SenderMethods
      def send_fd
        get_opt_int 'send-fd'
      end

      def send_timeout
        get_opt_ms 'send-timeout'
      end

      def send_timeout=(seconds)
        set_opt_ms 'send-timeout', seconds
      end
    end
  end
end
