require "minitest/autorun"
require "minitest/spec"
require "async"
require "nng"

describe "Req0 / Rep0" do
  it "completes a request/reply roundtrip" do
    Async do |task|
      rep = NNG::Socket::Rep0.new
      rep.listen("inproc://reqrep_spec")

      req = NNG::Socket::Req0.new
      req.dial("inproc://reqrep_spec")

      task.async do
        request = rep.receive
        assert_equal "ping", request.body
        rep.send("pong")
      end

      req.send("ping")
      reply = req.receive

      assert_equal "pong", reply.body
    end
  end

  it "opens Req0 in raw mode" do
    sock = NNG::Socket::Req0.new(raw: true)
    refute_nil sock
  end

  it "opens Rep0 in raw mode" do
    sock = NNG::Socket::Rep0.new(raw: true)
    refute_nil sock
  end
end
