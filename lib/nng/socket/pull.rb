module NNG
  module Socket
    fail LoadError unless defined? Pull0

    class Pull0
      include ReceiverMethods
    end
  end
end
