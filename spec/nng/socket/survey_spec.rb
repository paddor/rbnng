# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'async'
require 'nng'

describe 'Surveyor0 / Respondent0' do
  it 'respondent receives survey and surveyor receives response' do
    Async do |task|
      surveyor = NNG::Socket::Surveyor0.new
      surveyor.listen('inproc://survey_spec')

      respondent = NNG::Socket::Respondent0.new
      respondent.dial('inproc://survey_spec')

      sleep 0.01

      task.async do
        question = respondent.receive
        assert_equal 'survey?', question.body
        respondent.send('answer!')
      end

      surveyor.send('survey?')
      response = surveyor.receive

      assert_equal 'answer!', response.body
    end
  end
end
