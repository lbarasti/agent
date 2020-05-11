require "./spec_helper"
require "immutable"

class ConcurrentMap2(K, V) < Agent(Immutable::Map(K, V))
  def initialize(hash : Immutable::Map(K, V))
    super
  end

  def [](k)
    get!(&.[](k))
  end

  def []=(k, v)
    update { |hash|
      hash.set(k, v)
    }
  end

  def []?(k)
    get(&.[](k))
  end
end

describe ConcurrentMap2 do
  latency = "latency"
  it "works" do
    rt = ConcurrentMap2.new(Immutable::Map(String, Float64).new)
    rt.update { |hash|
      hash.set(latency, 1.2)
    }
    rt[latency].should eq 1.2

    rt.get_and_update { |hash|
      {hash[latency], hash.set(latency, hash[latency] + 0.3)}
    }.should eq 1.2

    rt[latency].should eq 1.5

    expect_raises(Exception) {
      rt["error_rate"]
    }
    rt["error_rate"]?.should be_a Agent::Error
    rt["error_rate"] = 5.1
    rt["error_rate"].should eq 5.1
  end

  it "is thread-safe" do
    c = ConcurrentMap2.new(Immutable::Map(String, Int32).new)
    done = (1..10).map { |m|
      Channel(Nil).new.tap { |d|
        spawn {
          (1..2048).each {
            sleep rand/1000
            c.update { |h|
              h.set(m.to_s, (h[m.to_s]? || 0) + 1)
            }
          }
          d.send(nil)
        }
      }
    }
    10.times {
      Channel.receive_first(done)
    }
    (1..10).each { |i|
      c[i.to_s].should eq 2048
    }
  end
end
