module NNG
  module Socket
    fail LoadError unless defined? Push0

    class Push0
      include SenderMethods
    end
  end
end
