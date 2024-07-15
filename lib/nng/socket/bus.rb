module NNG
  module Socket
    fail LoadError unless defined? Bus0

    class Bus0
      include SenderMethods
      include ReceiverMethods
    end
  end
end
