module NNG
  module Socket
    fail LoadError unless defined? Surveyor0

    class Surveyor0
      include SenderMethods
    end
  end
end
