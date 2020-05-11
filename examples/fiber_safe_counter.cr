# compile with `crystal build -Dpreview_mt examples/fiber_safe_counter.cr`
# run with `CRYSTAL_WORKERS=8 ./fiber_safe_counter`
require "../src/agent"

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
puts counter.get # => 1024 * 10
