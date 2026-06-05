text = "ruby 32 compiler"

if text =~ /ruby\s+\d+/
  puts "match"
else
  puts "no match"
end

puts /compiler/i.match(text)
