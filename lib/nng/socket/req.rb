module NNG
  module Socket
    fail LoadError unless defined? Req0

    class Req0
      include SenderMethods
      include ReceiverMethods
    end
  end
end
