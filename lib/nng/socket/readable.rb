module NNG
  module Socket
    module Readable
      def wait_readable
        @recv_io ||= IO.for_fd(recv_fd, autoclose: false)
        @recv_io.wait_readable
      end

      def receive
        wait_readable
        super
      end
    end
  end
end
