# frozen_string_literal: true

module NNG
  module Socket
    module Writable
      def wait_writable(timeout = default_send_timeout)
        @send_io ||= IO.for_fd(send_fd, autoclose: false)
        @send_io.wait_readable(timeout)
      end


      def send(data, timeout: default_send_timeout)
        wait_writable(timeout) or raise Timeout::Error, 'send timed out'
        super(data)
      end

      private

      def default_send_timeout
        ms = send_timeout
        ms.negative? ? nil : ms / 1000.0
      end
    end
  end
end
