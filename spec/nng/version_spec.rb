# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'nng'

describe NNG do
  describe '.nng_version' do
    it 'returns a 3-element array of integers' do
      v = NNG.nng_version
      assert_equal 3, v.length
      v.each { |n| assert_kind_of Integer, n }
    end
  end
end
