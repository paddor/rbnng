require "minitest/autorun"
require "minitest/spec"
require "async"
require "nng"

describe NNG::Socket::Pair0 do
  it "can send and receive a message" do
    Async do |task|
      listener = NNG::Socket::Pair0.new
      listener.listen("inproc://pair0_spec")

      dialer = NNG::Socket::Pair0.new
      dialer.dial("inproc://pair0_spec")

      task.async { dialer.send("hello from pair0") }
      msg = listener.receive

      assert_equal "hello from pair0", msg.body
    end
  end

  it "opens in raw mode" do
    sock = NNG::Socket::Pair0.new(raw: true)
    refute_nil sock
  end

  it "includes Readable" do
    assert_includes NNG::Socket::Pair0.ancestors, NNG::Socket::Readable
  end

  it "includes Writable" do
    assert_includes NNG::Socket::Pair0.ancestors, NNG::Socket::Writable
  end

  it "exposes wait_readable" do
    assert_respond_to NNG::Socket::Pair0.new, :wait_readable
  end

  it "exposes wait_writable" do
    assert_respond_to NNG::Socket::Pair0.new, :wait_writable
  end
end

describe NNG::Socket::Pair1 do
  it "can send and receive a message" do
    Async do |task|
      listener = NNG::Socket::Pair1.new
      listener.listen("inproc://pair1_spec")

      dialer = NNG::Socket::Pair1.new
      dialer.dial("inproc://pair1_spec")

      task.async { dialer.send("hello from pair1") }
      msg = listener.receive

      assert_equal "hello from pair1", msg.body
    end
  end
end
