require "minitest/autorun"
require "minitest/spec"
require "async"
require "nng"

describe "Push0 / Pull0" do
  it "pull receives what push sends" do
    Async do |task|
      pull = NNG::Socket::Pull0.new
      pull.listen("inproc://pipeline_spec")

      push = NNG::Socket::Push0.new
      push.dial("inproc://pipeline_spec")

      task.async { push.send("pipeline message") }
      msg = pull.receive

      assert_equal "pipeline message", msg.body
    end
  end
end
