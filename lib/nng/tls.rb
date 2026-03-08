# frozen_string_literal: true

require 'uri'

module NNG
  module TLS
    module_function

    def coerce_pem(val)
      case val
      when Pathname then val.read
      else
        val = val.to_pem if val.respond_to?(:to_pem)
        val.to_s
      end
    end

    def extract_host(url)
      uri = URI.parse(url.sub(%r{\Atls\+tcp://}, 'tcp://'))
      uri.host
    rescue URI::InvalidURIError
      nil
    end
  end
end
