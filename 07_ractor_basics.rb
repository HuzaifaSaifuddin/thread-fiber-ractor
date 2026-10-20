# RACTOR BASICS: ACTUAL PARALLELISM.
#
# A Ractor is Ruby's actor-model primitive -- each one gets its own
# GVL, so multiple Ractors genuinely execute Ruby at the same instant,
# on different cores. Thread can never do this, no matter how many you
# spawn (see 01_gvl_thread_basics.rb).
#
# Ractor's API is still marked experimental and has changed across Ruby
# versions -- e.g. an older `#take` method is gone as of this Ruby;
# `#value` is the current way to retrieve a Ractor's result. Don't
# trust a tutorial's method names without checking your own version.

r1 = Ractor.new do
  "hello from a ractor"
end
puts "r1.value => #{r1.value.inspect}"

puts

r2 = Ractor.new do
  msg = Ractor.receive
  "ractor received: #{msg}"
end
r2.send("ping from main")
puts "r2.value => #{r2.value.inspect}"

puts

puts "main Ractor is: #{Ractor.current.inspect}"
puts "Ractor.main?   => #{Ractor.main?}"
