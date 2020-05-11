require "./spec_helper"

class Counter(T) < Agent(T)
  def incr
    update(&.+(1))
  end

  def decr
    update(&.-(1))
  end
end

describe Counter do
  it "supports basic increment and decrement operations" do
    c = Counter.new(0)
    c.get.should eq 0
    c.incr
    c.get.should eq 1
    10.times {
      c.decr
    }
    c.get.should eq -9
  end

  it "is thread-safe" do
    done = Channel(Nil).new(10)
    counter = Agent.new(0)

    (1..10).each {
      spawn {
        (1..1024).each {
          counter.update { |x| x + 1 }
        }
        done.send nil
      }
    }
    10.times { done.receive }
    counter.get.should eq 1024 * 10
  end
end
