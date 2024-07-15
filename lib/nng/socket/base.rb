module NNG
  module Socket

    module ConverterMethods
      # Converts the result from ms to seconds.
      def get_opt_ms(...)
        super / 1000.0
      end

      # Converts +duration+ from seconds to ms.
      #
      def set_opt_ms(_, duration)
        duration = (duration * 1000).to_i
        super
      end
    end

    fail LoadError unless defined? Base

    class Base
      prepend ConverterMethods
    end
  end
end
