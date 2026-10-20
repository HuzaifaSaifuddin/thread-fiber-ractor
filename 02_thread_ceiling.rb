# THREAD HAS A HARD OS CEILING. FIBER DOESN'T.
#
# A Thread maps to a real OS kernel thread. The kernel enforces a hard
# cap on how many of those can exist — and it's lower than you'd think.
# A Fiber is not an OS-level construct at all, so it isn't subject to
# that ceiling.
#
# This script finds your machine's actual thread ceiling, then creates
# a much larger number of Fibers with zero errors.

threads = []
thread_ceiling = nil

puts "Creating Threads until the OS refuses..."
begin
  100_000.times { threads << Thread.new { sleep 10 } }
  puts "Somehow created all 100,000 (unusual — most machines cap out well before this)"
rescue ThreadError => e
  thread_ceiling = threads.size
  puts "Hit a hard OS wall at #{thread_ceiling} threads -- #{e.message}"
ensure
  threads.each { |t| t.kill rescue nil }
  threads.each { |t| t.join rescue nil }
end

puts
fibers = []
fibers_created = 0
target = 50_000

puts "Creating #{target} Fibers (not an OS construct — no equivalent ceiling)..."
begin
  target.times do
    f = Fiber.new { Fiber.yield }
    f.resume
    fibers << f
    fibers_created += 1
  end
  ratio = thread_ceiling ? (fibers_created.to_f / thread_ceiling).round(1) : nil
  puts "Created all #{fibers_created} Fibers with zero errors" +
       (ratio ? " (#{ratio}x past where Threads hit their wall)" : "")
rescue => e
  puts "Failed after #{fibers_created} -- #{e.class}: #{e.message}"
end
