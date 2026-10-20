# FIBER BASICS: COOPERATIVE PAUSE AND RESUME.
#
# A Fiber is a coroutine. Unlike Thread, nothing forces it to switch --
# it only pauses at Fiber.yield, and only resumes when you call #resume.
# It runs on whichever OS thread calls #resume; resuming it from a
# different thread raises FiberError.

puts "---- pause and resume, interleaved with main ----"

fiber = Fiber.new do
  puts "fiber: step 1"
  Fiber.yield
  puts "fiber: step 2"
  Fiber.yield
  puts "fiber: step 3"
end

puts "main: about to resume"
fiber.resume
puts "main: back in control"
fiber.resume
puts "main: back again"
fiber.resume
puts "main: fiber finished, alive? #{fiber.alive?}"

puts
puts "---- a fiber only runs on whichever thread calls #resume ----"

gen = Fiber.new do
  loop { Fiber.yield Thread.current.object_id }
end

puts "main thread id:   #{Thread.current.object_id}"
puts "fiber sees thread: #{gen.resume}"

Thread.new do
  begin
    gen.resume
  rescue FiberError => e
    puts "resuming from a different thread raised: #{e.class}: #{e.message}"
  end
end.join
