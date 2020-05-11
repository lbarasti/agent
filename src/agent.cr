class Agent(T)
  record Wait, ack : Channel(Nil)
  record Update(T), fn : T -> T
  enum Result
    Timeout
    Submitted
    Error
  end

  DefaultTimeout = 5.seconds

  # Creates an Agent wrapping `@state`.
  #
  # Agents are fiber-based, i.e. each Agent runs a fiber and serialises
  # access and update requests over a channel. This guarantees thread-safety and
  # data consistency within Agent's operations.
  def initialize(@state : T)
    @commands = Channel(Update(T) | Wait).new
    spawn do
      loop do
        case m = @commands.receive
        when Update
          @state = m.fn.call(@state)
        when Wait
          m.ack.send(nil)
          m.ack.receive
        end
      rescue
        # Error while updating. Keep on running
      end
    end
  end

  # Fetches the state of the Agent.
  #
  # This is equivalent to `get(max_time, &id)`, where `id` is the identity function.
  def get(max_time = DefaultTimeout) : T | Result
    get(max_time) { |v| v }
  end

  # Fetches the state of the Agent.
  #
  # Analogous `Agent#get`, but an exception is raised in case of timeout.
  # NOTE the compile-time type of the returned value is `T`, rather than `T | Agent::Result`.
  def get!(max_time = DefaultTimeout) : T
    case r = get(max_time)
    when T
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  # Fetches the state of the Agent and applies the given function to it.
  #
  # This is equivalent to calling `Agent#get_and_update`, where `fn` does not update the current state.
  # the current state.
  def get(max_time = DefaultTimeout, &fn : T -> Q) : Q | Result forall Q
    get_and_update(max_time) { |state|
      {fn.call(state), state}
    }
  end

  # Fetches the state of the Agent and applies the given function to it.
  #
  # Analogous `Agent#get`, but an exception is raised in case of timeout
  # or if an exception is raised within the block.
  # NOTE the compile-time type of the returned value is `Q`, rather than `Q | Agent::Result`.
  def get!(max_time = DefaultTimeout, &fn : T -> Q) : Q forall Q
    case r = get(max_time, &fn)
    when Q
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  # Fetches the state of the Agent, updates it and returns the first projection of `fn.call(state)`.
  #
  # If the `#get_and_update` request is not handled by the Agent's fiber within
  # `max_time`, then an Agent::Result::Timeout is returned. If an error is raised
  # during the execution of the block, then an Agent::Result::Error is returned.
  # Otherwise, the transformed state `fn.call(state).first`, and the state is updated to
  # `fn.call(state).last`.
  def get_and_update(max_time = DefaultTimeout, &fn : T -> {Q, T}) : Q | Result forall Q
    ack = Channel(Nil).new

    select
    when @commands.send(Wait.new(ack))
      ack.receive
      begin
        q, @state = fn.call(@state)
        q
      rescue
        Result::Error
      ensure
        ack.send nil
      end
    when timeout max_time
      Result::Timeout
    end
  end

  # Fetches the state of the Agent, updates it and returns the first projection of `fn.call(state)`.
  #
  # Analogous `Agent#get_and_update`, but an exception is raised in case of timeout
  # or if an exception is raised within the block.
  # NOTE the compile-time type of the returned value is `Q`, rather than `Q | Agent::Result`.
  def get_and_update!(max_time = DefaultTimeout, &fn : T -> {Q, T}) : Q forall Q
    case r = get_and_update(max_time, &fn)
    when Q
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  # Updates the state of the Agent.
  #
  # Returns `Agent::Result::Submitted`, if the update operation was accepted.
  # Returns `Agent::Result::Timeout`, if a timeout is triggered before the operation
  # is accepted by the Agent's fiber.
  # NOTE `#update` does not wait for `fn` to be applied to the Agent's state
  # before returning.
  def update(max_time = DefaultTimeout, &fn : T -> T) : Result
    select
    when @commands.send(Update.new(fn))
      Result::Submitted
    when timeout max_time
      Result::Timeout
    end
  end
end
