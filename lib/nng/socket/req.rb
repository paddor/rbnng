# frozen_string_literal: true


module NNG
  module Socket
    class Req0
      def initialize(raw: false)
        if raw
          _open_raw
        else
          _open
        end
      end
    end
  end
end
