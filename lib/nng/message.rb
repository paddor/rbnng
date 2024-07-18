module NNG
    fail LoadError unless defined? Message

    class Message
      def self.new_request_id
        # TODO
      end
    end

    Msg = Message
  end
end
