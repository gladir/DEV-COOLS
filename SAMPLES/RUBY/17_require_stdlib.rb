require "json"
require "set"

data = JSON.parse("{\"name\":\"Ruby\",\"year\":1995}")
seen = Set.new
seen.add(data["name"])

puts data["year"]
puts seen.include?("Ruby")
