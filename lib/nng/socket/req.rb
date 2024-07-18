module NNG
  module Socket
    fail LoadError unless defined? Req0

    class Req0
      include SenderMethods
      include ReceiverMethods

      def initialize(raw: false)
        if raw
          fail NotImplementedError
        else
          _initialize
        end
      end
    end
  end
end
