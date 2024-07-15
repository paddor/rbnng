module NNG
  module Socket
    fail LoadError unless defined? Pair0

    class Pair0
      include SenderMethods
      include ReceiverMethods
    end

    fail LoadError unless defined? Pair1

    class Pair1
      include SenderMethods
      include ReceiverMethods
    end
  end
end
