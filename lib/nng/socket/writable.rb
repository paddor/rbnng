module NNG
  module Socket
    module Writable
      def wait_writable
        @send_io ||= IO.for_fd(send_fd, autoclose: false)
        @send_io.wait_readable
      end

      def send(data)
        wait_writable
        super
      end
    end
  end
end
