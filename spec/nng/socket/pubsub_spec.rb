require "minitest/autorun"
require "minitest/spec"
require "async"
require "nng"

describe "Pub0 / Sub0" do
  it "subscriber receives a published message" do
    Async do |task|
      pub = NNG::Socket::Pub0.new
      pub.listen("inproc://pubsub_spec")

      sub = NNG::Socket::Sub0.new
      sub.dial("inproc://pubsub_spec")

      # Allow time for the subscription to be established
      sleep 0.01

      task.async { pub.send("broadcast") }
      msg = sub.receive

      assert_equal "broadcast", msg.body
    end
  end
end
