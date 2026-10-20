# THE COST OF COOPERATIVE SCHEDULING: NO PREEMPTION.
#
# Thread's GVL still has a timer that forces a switch, even for a pure
# CPU loop with no explicit yield point. A Fiber scheduler has no such
# safety net -- a fiber only ever gives up the thread when IT decides
# to (by hitting a blocking call). A CPU-bound fiber with zero yield
# points starves every other fiber on that thread for its *entire* run
# -- even ones whose I/O already finished.
#
# (If that CPU-bound fiber ran forever, everything sharing its thread
# would wait forever too -- there's no timeout to rescue it.)

require "async"
require "benchmark"

def busy_loop(seconds)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
  count = 0
  count += 1 while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
  count
end

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
elapsed = -> { (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start).round(2) }

Async do |task|
  task.async do
    busy_loop(2) # pure CPU, no yield point at all
    puts "[CPU-bound fiber] finished after #{elapsed.call}s"
  end

  task.async do
    sleep(0.1) # tiny I/O wait -- "ready" almost immediately
    puts "[I/O fiber]        finished after #{elapsed.call}s (expected ~0.1s if it weren't starved)"
  end
end

# SAME FINDING, AT A LARGER SCALE.
#
# The single I/O fiber above proves the mechanism. This proves the blast
# radius: one bad fiber doesn't just starve its one neighbor -- mixed in
# among thousands of well-behaved fibers, it holds back *all* of them for
# its entire run. None of the others get to finish early, because none of
# them even get a turn to start their own wait until the culprit is done.

N = 3_000

baseline = Benchmark.realtime do
  Async do |task|
    N.times { task.async { sleep 1 } }
  end
end
puts
puts "Baseline: #{N} I/O fibers alone -> #{baseline.round(2)}s"

finish_times = []
start2 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
with_culprit = Benchmark.realtime do
  Async do |task|
    task.async { busy_loop(2) } # the one bad fiber -- zero yield points

    N.times do
      task.async do
        sleep 1
        finish_times << (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start2)
      end
    end
  end
end
puts "With ONE CPU-bound fiber mixed in -> #{with_culprit.round(2)}s"
puts "  fastest of the #{N} I/O fibers finished at: #{finish_times.min.round(2)}s (would be ~1.0s without the culprit)"
puts "  slowest of the #{N} I/O fibers finished at: #{finish_times.max.round(2)}s"
puts "  all #{finish_times.size} I/O fibers were held back by the single CPU-bound one -- not just its immediate neighbor."
