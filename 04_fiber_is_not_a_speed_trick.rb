# FIBER ALONE IS NOT FASTER. IT'S OFTEN SLOWER.
#
# It's tempting to assume Fiber makes code faster just because it's a
# newer, fancier control-flow tool. It doesn't -- a Fiber switch has
# real overhead, and for a simple "stop when you hit a condition" loop,
# a plain loop wins every time. Fiber's value is structural (next file),
# not speed.

require "benchmark"

def fibonacci_generator
  Fiber.new do
    a, b = 0, 1
    loop do
      Fiber.yield a
      a, b = b, a + b
    end
  end
end

def fiber_until(threshold)
  fiber = fibonacci_generator
  loop do
    value = fiber.resume
    return value if value > threshold
  end
end

def loop_until(threshold)
  a, b = 0, 1
  loop do
    return a if a > threshold
    a, b = b, a + b
  end
end

ITERATIONS = 100_000
THRESHOLD = 50

fiber_time = Benchmark.realtime { ITERATIONS.times { fiber_until(THRESHOLD) } }
loop_time = Benchmark.realtime { ITERATIONS.times { loop_until(THRESHOLD) } }

puts "plain loop: #{loop_time.round(4)}s"
puts "fiber:      #{fiber_time.round(4)}s"
puts "fiber is #{(fiber_time / loop_time).round(1)}x SLOWER than a plain loop for this"
