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
    c = Counter.new(0)
    done = (1..10).map { |m|
      Channel(Nil).new.tap { |d|
        spawn {
          (1..2048).each {
            sleep rand/1000
            c.incr
          }
          d.send(nil)
        }
      }
    }
    10.times {
      Channel.receive_first(done)
    }
    c.get.should eq 2048 * 10
  end
end