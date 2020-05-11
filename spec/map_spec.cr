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

describe ConcurrentMap do
  latency = "latency"
  it "works" do
    rt = ConcurrentMap.new(Hash(String, Float64).new)
    rt.update { |hash|
      hash[latency] = 1.2
      hash
    }
    rt[latency].should eq 1.2

    rt.get_and_update { |hash|
      old = hash[latency]
      hash[latency] = 1.5
      {old, hash}
    }.should eq 1.2

    rt[latency].should eq 1.5

    expect_raises(Exception) {
      rt["error_rate"]
    }
    rt["error_rate"]?.should be_a Agent::Error
    rt["error_rate"] = 5.1
    rt["error_rate"].should eq 5.1
  end
end
