module NNG
  module Socket
    module SenderMethods
      def send_fd
        get_opt_int 'send-fd'
      end
    end
  end
end
