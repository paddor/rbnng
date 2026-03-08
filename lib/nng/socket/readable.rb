# frozen_string_literal: true

module NNG
  module Socket
    module Readable
      def wait_readable(timeout = recv_timeout)
        @recv_io ||= IO.for_fd(recv_fd, autoclose: false)
        @recv_io.wait_readable(timeout)
      end

      def receive(timeout: recv_timeout)
        wait_readable(timeout) or raise Timeout::Error, 'receive timed out'
        super()
      end
    end
  end
end
