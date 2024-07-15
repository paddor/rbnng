module NNG
  module Socket
    fail LoadError unless defined? Pub0

    class Pub0
      include SenderMethods
    end
  end
end
