# frozen_string_literal: true


module NNG
  module Socket
    class Rep0
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
