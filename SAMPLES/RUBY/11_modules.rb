module Greeter
  def greet(name)
    "hello " + name
  end
end

class Robot
  include Greeter
end

r = Robot.new
puts r.greet("unit")
