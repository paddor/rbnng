module NNG
  module Socket
    fail LoadError unless defined? Respondent0

    class Respondent0
      include ReceiverMethods
    end
  end
end
