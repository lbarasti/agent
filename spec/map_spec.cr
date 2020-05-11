require "./spec_helper"

class ConcurrentMap(K, V) < Agent(Hash(K, V))
  def initialize(hash : Hash(K, V))
    super
  end

  def [](k)
    get!(&.[](k))
  end

  def []=(k, v)
    update { |hash|
      hash[k] = v
      hash
    }
  end

  def []?(k)
    get(&.[](k))
  end
end

Latency = "latency"
describe ConcurrentMap do
  it "works" do
    rt = ConcurrentMap.new(Hash(String, Float64).new)
    rt.update { |hash|
      hash[Latency] = 1.2
      hash
    }
    rt[Latency].should eq 1.2

    rt.get_and_update { |hash|
      old = hash[Latency]
      hash[Latency] = 1.5
      {old, hash}
    }.should eq 1.2

    rt[Latency].should eq 1.5

    expect_raises(Exception) {
      rt["error_rate"]
    }
    rt["error_rate"]?.should eq Agent::Result::Error
    rt["error_rate"] = 5.1
    rt["error_rate"].should eq 5.1
  end
end
