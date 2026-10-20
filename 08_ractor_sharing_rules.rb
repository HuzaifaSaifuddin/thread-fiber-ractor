# RACTOR'S SHARING RULES.
#
# Since Ractors genuinely run at the same instant, Ruby has to prevent
# two of them from mutating the same object at once. It does this by
# making the setup physically impossible, not just "risky" -- there is
# no path to "two Ractors, one shared mutable object, by reference."

puts "---- 1. closures over a mutable outer variable are refused at Ractor.new time ----"
arr = [1, 2, 3]
begin
  Ractor.new { arr << 4 }
rescue ArgumentError => e
  puts "#{e.class}: #{e.message}"
end

puts
puts "---- 2. #send of a mutable object copies it -- different object_id ----"
arr2 = [1, 2, 3]
r = Ractor.new { Ractor.receive << 4 }
r.send(arr2)
result = r.value
puts "result: #{result.inspect}, original: #{arr2.inspect}"
puts "same object_id? #{arr2.object_id == result.object_id}"

puts
puts "---- 3. #send of a frozen object shares it by true reference ----"
frozen_arr = [1, 2, 3].freeze
r2 = Ractor.new { Ractor.receive }
r2.send(frozen_arr)
result2 = r2.value
puts "same object_id? #{frozen_arr.object_id == result2.object_id}"

puts
puts "---- 4. move: true transfers ownership instead of copying ----"
arr3 = [1, 2, 3]
r3 = Ractor.new { Ractor.receive << 4 }
r3.send(arr3, move: true)
puts "result: #{r3.value.inspect}"
begin
  arr3.inspect
rescue Ractor::MovedError => e
  puts "touching the original after move: #{e.class}: #{e.message}"
end

puts
puts "---- 5. Ractor.make_shareable deep-freezes recursively ----"
data = { name: "example", roles: ["lead", "engineer"] }
Ractor.make_shareable(data)
puts "outer frozen? #{data.frozen?}, nested array frozen? #{data[:roles].frozen?}"

puts
puts "---- 6. a Ractor is itself shareable -- non-main Ractors can't mutate its ivars ----"
r4 = Ractor.new { @x = 1 }
begin
  r4.value
rescue Ractor::RemoteError => e
  puts "#{e.cause.class}: #{e.cause.message}"
end
