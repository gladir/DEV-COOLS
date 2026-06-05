double = lambda do |x|
  x * 2
end

printer = proc do |value|
  puts value
end

printer.call(double.call(21))
