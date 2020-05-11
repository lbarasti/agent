# compile with `crystal build -Dpreview_mt examples/breaking_counter.cr`
# run with `CRYSTAL_WORKERS=8 ./breaking_counter`

done = Channel(Nil).new(10)
counter = 0
(1..10).each {
  spawn {
    (1..1024).each {
      counter += 1
    }
    done.send nil
  }
}
10.times { done.receive }
puts counter # => ?
