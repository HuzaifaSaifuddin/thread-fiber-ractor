# THE REAL PAYOFF: Fiber::SchedulerInterface.
#
# Registering a scheduler (via Fiber.set_scheduler) makes Ruby intercept
# blocking calls -- sleep, socket I/O -- and hand them to the scheduler
# instead of actually blocking the OS thread. The scheduler registers
# interest with the kernel's own I/O multiplexer (epoll/kqueue) and the
# thread is immediately free to run other ready fibers. This is the
# mechanism Falcon is built on.
#
# The `async` gem is the reference implementation: `gem install async`.

require "async"
require "benchmark"

N = 20

puts "---- Threads: #{N} concurrent 'slow I/O calls' (sleep 1 each) ----"
thread_time = Benchmark.realtime do
  threads = N.times.map { Thread.new { sleep 1 } }
  threads.each(&:join)
end
puts "  wall time: #{thread_time.round(2)}s"
puts "  OS threads used: #{N} (one per call)"

puts
puts "---- Fibers + scheduler: same #{N} calls, one task.async each ----"
fiber_time = Benchmark.realtime do
  Async do |task|
    N.times { task.async { sleep 1 } }
  end
end
puts "  wall time: #{fiber_time.round(2)}s"
puts "  OS threads used: 1 (every task cooperatively shared the same thread)"

puts
BIG_N = 3_000
puts "---- Now push past where Threads hit their wall (02_thread_ceiling.rb found ~2,046) ----"
puts "Running #{BIG_N} concurrent 'slow calls' as Fibers -- Thread.new would have crashed by now."
big_time = Benchmark.realtime do
  Async do |task|
    BIG_N.times { task.async { sleep 1 } }
  end
end
puts "  wall time: #{big_time.round(2)}s"
puts "  #{BIG_N} concurrent I/O-bound calls, 1 OS thread, no crash."
