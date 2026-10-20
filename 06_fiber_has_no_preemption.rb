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
