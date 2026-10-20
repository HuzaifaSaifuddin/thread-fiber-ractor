# THE PAYOFF: REAL CPU PARALLELISM.
#
# Same CPU-bound workload as 01_gvl_thread_basics.rb, now split across
# Thread vs Ractor. Thread stays flat no matter how many you spawn.
# Ractor doesn't -- each one has its own GVL and genuinely runs at the
# same instant as the others, on different cores.

require "benchmark"

def count_primes(upto)
  count = 0
  (2..upto).each do |n|
    is_prime = (2..Math.sqrt(n).to_i).none? { |d| n % d == 0 }
    count += 1 if is_prime
  end
  count
end

WORKERS = 4
LIMIT = 600_000

puts "#{WORKERS} workers, each counting primes up to #{LIMIT}"
puts

puts "---- Serial: #{WORKERS} calls, one after another ----"
serial_time = Benchmark.realtime { WORKERS.times { count_primes(LIMIT) } }
puts "  wall time: #{serial_time.round(2)}s"

puts
puts "---- Threads: #{WORKERS} concurrent, same GVL ----"
thread_time = Benchmark.realtime do
  threads = WORKERS.times.map { Thread.new { count_primes(LIMIT) } }
  threads.each(&:join)
end
puts "  wall time: #{thread_time.round(2)}s"
puts "  speedup vs serial: #{(serial_time / thread_time).round(2)}x"

puts
puts "---- Ractors: #{WORKERS} concurrent, independent GVLs ----"
ractor_time = Benchmark.realtime do
  ractors = WORKERS.times.map { Ractor.new { count_primes(LIMIT) } }
  ractors.each(&:value)
end
puts "  wall time: #{ractor_time.round(2)}s"
puts "  speedup vs serial: #{(serial_time / ractor_time).round(2)}x"
