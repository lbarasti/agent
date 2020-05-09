require "./spec_helper"

describe Agent do
  counter = Agent.new(0)
  it "supports fetching the underlying state" do
    counter.get.should eq 0
  end

  it "supports fetching and tranforming the underlying state" do
    counter.get { |v| "v = #{v}" }.should eq "v = 0"
  end

  it "supports updating the underlying state" do
    counter.update(&.+(1))
    counter.get.should eq 1
  end

  it "supports getting and updating the underlying state in one operation" do
    transformed = counter.get_and_update { |n|
      {n / 2, n + 1}
    }
    transformed.should eq 0.5
    counter.get.should eq 2
  end

  it "supports timing out on requests" do
    counter.update { |n|
      sleep 0.5
      n + 1
    }.should eq Agent::Result::Submitted

    counter.get(0.1.seconds).should eq Agent::Result::Timeout
  end

  it "raises an error on timeout, when using the `!` variant of the methods" do
    counter.update { |n|
      sleep 0.5
      n + 1
    }.should eq Agent::Result::Submitted

    expect_raises(Exception) {
      counter.get!(0.1.seconds)
    }
  end

  it "gracefully handles exceptions on get_* operations" do
    counter.get_and_update { |n|
      raise Exception.new
      {n, n}
    }.should eq Agent::Result::Error

    counter.get.should eq 4
  end

  it "gracefully handles exceptions on `update`" do
    counter.update { |n|
      raise Exception.new
      n + 1
    }.should eq Agent::Result::Submitted
    counter.get.should eq 4
  end
end
