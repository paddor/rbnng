# frozen_string_literal: true

module NNG
  module Socket
    module Writable
      def wait_writable(timeout = send_timeout)
        @send_io ||= IO.for_fd(send_fd, autoclose: false)
        @send_io.wait_readable(timeout)
      end

      def send(data, timeout: send_timeout)
        wait_writable(timeout) or raise Timeout::Error, 'send timed out'
        super(data)
      end
    end
  end
end
