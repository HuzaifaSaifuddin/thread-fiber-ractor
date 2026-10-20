# THE GVL, IN TWO MEASUREMENTS.
#
# MRI's Global VM Lock lets exactly one thread execute a Ruby instruction
# at any instant, in one process — no matter how many threads you spawn.
# A thread blocked on I/O releases the GVL so another thread can run.
# A thread doing pure CPU work never hits a release point.
#
# This script proves both halves on your own machine.

require "benchmark"

def count_primes(upto)
  count = 0
  (2..upto).each do |n|
    is_prime = (2..Math.sqrt(n).to_i).none? { |d| n % d == 0 }
    count += 1 if is_prime
  end
  count
end

N = 1_000_000

puts "---- CPU-bound: does Thread give you parallelism? ----"

serial = Benchmark.realtime do
  count_primes(N)
  count_primes(N)
end
puts "Two calls, one after another:   #{serial.round(2)}s"

parallel = Benchmark.realtime do
  t1 = Thread.new { count_primes(N) }
  t2 = Thread.new { count_primes(N) }
  [t1, t2].each(&:join)
end
puts "Same two calls, on two Threads:  #{parallel.round(2)}s"
puts "speedup: #{(serial / parallel).round(2)}x  (expect ~1.0x — the GVL serializes CPU-bound Ruby)"

puts
puts "---- I/O-bound: does Thread give you concurrency? ----"

serial_io = Benchmark.realtime do
  sleep(1)
  sleep(1)
end
puts "Two sleeps, one after another:  #{serial_io.round(2)}s"

parallel_io = Benchmark.realtime do
  t1 = Thread.new { sleep(1) }
  t2 = Thread.new { sleep(1) }
  [t1, t2].each(&:join)
end
puts "Same two sleeps, on two Threads: #{parallel_io.round(2)}s"
puts "speedup: #{(serial_io / parallel_io).round(2)}x  (expect ~2.0x — I/O releases the GVL)"
