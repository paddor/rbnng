module NNG
  module Socket
    fail LoadError unless defined? Rep0

    class Rep0
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
