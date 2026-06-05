begin
  raise "boom"
rescue RuntimeError => e
  puts e.message
ensure
  puts "done"
end
