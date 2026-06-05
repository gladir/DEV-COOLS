class Counter
  def initialize(start)
    @value = start
  end

  def inc
    @value = @value + 1
  end

  def value
    @value
  end
end

c = Counter.new(10)
c.inc
puts c.value
