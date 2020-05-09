class Agent(T)
  record Wait, ack : Channel(Nil)
  record Update(T), fn : T -> T
  enum Result
    Timeout
    Submitted
    Error
  end

  DefaultTimeout = 5.seconds

  def initialize(@v : T)
    @commands = Channel(Update(T) | Wait).new
    spawn do
      loop do
        case m = @commands.receive
        when Update
          @v = m.fn.call(@v)
        when Wait
          m.ack.send(nil)
          m.ack.receive
        end
      rescue
        # Error while updating. Keep on running
      end
    end
  end

  def get(max_time = DefaultTimeout) : T | Result
    get(max_time) { |v| v }
  end

  def get!(max_time = DefaultTimeout) : T
    case r = get(max_time)
    when T
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  def get(max_time = DefaultTimeout, &fn : T -> Q) : Q | Result forall Q
    get_and_update(max_time) { |state|
      {fn.call(state), state}
    }
  end

  def get!(max_time = DefaultTimeout, &fn : T -> Q) : Q forall Q
    case r = get(max_time, &fn)
    when Q
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  def get_and_update(max_time = DefaultTimeout, &fn : T -> {Q, T}) : Q | Result forall Q
    ack = Channel(Nil).new

    select
    when @commands.send(Wait.new(ack))
      ack.receive
      begin
        q, @v = fn.call(@v)
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

  def get_and_update!(max_time = DefaultTimeout, &fn : T -> {Q, T}) : Q forall Q
    case r = get_and_update(max_time, &fn)
    when Q
      r
    else
      raise Exception.new(r.to_s)
    end
  end

  def update(max_time = DefaultTimeout, &fn : T -> T) : Result
    select
    when @commands.send(Update.new(fn))
      Result::Submitted
    when timeout max_time
      Result::Timeout
    end
  end
end
