![GitHub release](https://img.shields.io/github/release/lbarasti/agent.svg)
![Build Status](https://github.com/lbarasti/agent/workflows/Crystal%20spec/badge.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Docs](https://img.shields.io/badge/docs-available-brightgreen.svg)](https://lbarasti.github.io/agent)

# agent

An Agent is a wrapper that makes it thread-safe to share object references
across your application, without having to worry about concurrent access and destructive assignment.

It's an ideal companion for immutable data structures, but promises thread-safe access
and modifications on mutable objects, too, provided that the user only manipulates state
within an Agent's methods.

## Installation

- Add the dependency to your `shard.yml`:

```yaml
dependencies:
  agent:
    github: lbarasti/agent
```

- Run `shards install`

## Usage

Let's define an Agent wrapping a hash.
```crystal
require "agent"

concurrent_hash = Agent.new({"a" => 1, "c" => 41})
```

We can now traverse the hash safely with `Agent.get`.
```crystal
concurrent_hash.get { |h| h["a"] } # => 1
```
Everything we do within the block passed to `Agent#get` is guaranteed to be thread-safe and consistent.

To update the hash in a thread-safe fashion we call `Agent#update`.
```crystal
concurrent_hash.update { |h|
  h["b"] = 12
  h
} # => Agent::Result::Submitted
```
The block passed to `Agent#update` will run asynchronously, but any calls following
it are guaranteed to see the updated version of the wrapped object - provided that the update was successful.

```crystal
concurrent_hash.get { |h| h["b"] } # => 12
```

If you want synchronously fetch and update the state of the agent, then `Agent#get_and_update` will serve your purpose.

```crystal
concurrent_hash.get_and_update { |h|
  old_b = h["b"]
  h["b"] = old_b + 1
  {h["b"] , h}
} # => 13
```

`Agent#get_and_update` expects a block of type
```crystal
Hash(String, Int32) -> {Q, Hash(String, Int32)}
```
where `Q` is a generic type and is the type of the returned value. This means you can return
any transformation of the current Agent's state *and* alter the state in a single pass.

### Error handling and timeouts

Errors are handled within the Agent, and surfaced as `Agent::Result::Error` values.
For example, if we try to fetch a value for a non existing key, the `KeyError` exception turns into an `Agent::Result::Error`.
```crystal
concurrent_hash.get { |h| h["non-existing"] } # => Agent::Result::Error
```
If you'd rather deal with the exception yourself, check out the `!` variant of Agent's getter methods.
```crystal
concurrent_hash.get! { |h| h["non-existing"] } # raises Exception("Error")
```

In order to give responsiveness guarantees to the client's code, Agent's operations support timing out.
The default timeout is 5 seconds, but you can pass a custom timeout on each operation.

```crystal
concurrent_hash.get {
  sleep 3.seconds # simulates a time consuming operation
}

concurrent_hash.get(max_wait: 1.second) { |h|
  h["b"]
} # => Agent::Result::Timeout

concurrent_hash.get!(max_wait: 1.second) { |h|
  h["b"]
} # raises Exception("Timeout")
```

## Agents in multi-threaded runtime

As of Crystal 0.34.0, by default, your code will be compiled to run on a single thread.
In this scenario, using Agents still makes sense if you access or modify objects from
different fibers. If that's not the case, then the only perk of adopting Agents is that
your code will be future proof.

To see how multi-threading and concurrency can break the correctness of your application,
think about the behaviour of the following code, where we spawn 10 fibers, and each one
concurrently updates the value of a counter 1024 times.

```crystal
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
```

Or just check out this repository and run

```
crystal build -Dpreview_mt examples/breaking_counter.cr
CRYSTAL_WORKERS=4 ./breaking_counter
```

You'll notice unpredictable results in the final count.

We can fix this with an `Agent`.

```crystal
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
```

Now the final value for `counter` will *always* equal 10240, no matter the number of runtime threads.

## FAQ

### How does this differ from `Atomic(T)` ([docs](https://crystal-lang.org/api/latest/Atomic.html))?

Only primitive integer types, reference types or nilable reference types can be used with an Atomic type.  
On the other hand, you can wrap any type in an `Agent`.

### Are Agent updates atomic, i.e. do either all the instructions in a block take effect or none of it does?

No, atomicity is not guaranteed. In particular, if an exception is raised within a given get / update block,
then any side-effecting operation preceding the exception will not be reverted.

Relying on immutable data structures and avoiding side-effects in Agent's get / update operations are
good mitigations for the lack of atomicity.

### My code uses immutable data structures such as [these ones](https://github.com/lucaong/immutable). Are these not thread-safe by definition?

Immutable data structures are thread-safe in the sense that you can safely access them from different fibers, but they are subject to the so-called [lost update problem](https://en.wikipedia.org/wiki/Concurrency_control#Why_is_concurrency_control_needed?), where changes made by a fiber will not be recorded by another one - think of the case where multiple fibers close over the same variable, and then destructively assign values to such variable, concurrently. 

You can dodge the lost-update bullet by making sure that all the updates to your immutable data structure happen in a single fiber, but that's not always possible or desirable. Furthermore, you might still have to implement custom logic to ensure transactionality - think of the scenario where a fiber wants to increment a counter by 1, but first has to fetch the current value of the counter. In a parallel¹ execution, the counter _might_ change between the fetch and the set statement

¹ Things will be fine in a concurrent but not parallel execution, as the fiber will not yield control until after the update.

## Development

Just check out the repository and run `crystal spec` to run the tests.

## Contributing

1. Fork it (<https://github.com/lbarasti/agent/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [lbarasti](https://github.com/lbarasti) - creator and maintainer
