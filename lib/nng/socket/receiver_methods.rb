module NNG
  module Socket
    module ReceiverMethods
      def recv_fd
        get_opt_int 'recv-fd'
      end
    end
  end
end
