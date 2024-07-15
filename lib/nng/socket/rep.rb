module NNG
  module Socket
    fail LoadError unless defined? Rep0

    class Rep0
      include SenderMethods
      include ReceiverMethods
    end
  end
end
