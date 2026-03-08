# frozen_string_literal: true

module NNG
  module Socket
    module Readable
      def wait_readable(timeout = default_recv_timeout)
        @recv_io ||= IO.for_fd(recv_fd, autoclose: false)
        @recv_io.wait_readable(timeout)
      end


      def receive(timeout: default_recv_timeout)
        wait_readable(timeout) or raise Timeout::Error, 'receive timed out'
        super()
      end

      private

      def default_recv_timeout
        ms = recv_timeout
        ms.negative? ? nil : ms / 1000.0
      end
    end
  end
end
