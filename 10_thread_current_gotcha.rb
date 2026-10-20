# BONUS: THE GOTCHA BEHIND RAILS' Current.user.
#
# Most Rails apps keep request-scoped context (current user, request
# id) via ActiveSupport::CurrentAttributes. It's built on
# ActiveSupport::IsolatedExecutionState, which defaults to
# isolation_level = :thread -- storing state as a plain attribute on
# the shared Thread object, NOT scoped per-fiber.
#
# Under a Fiber-scheduler server (e.g. Falcon), multiple fibers share
# one OS thread. With the default :thread isolation, they'll clobber
# each other's Current state. Rails exposes a real fix:
# config.active_support.isolation_level = :fiber
#
# No Rails app required -- this is the actual ActiveSupport class,
# used standalone.

require "active_support"
require "active_support/current_attributes"
require "async"

class Current < ActiveSupport::CurrentAttributes
  attribute :request_id
end

def run_two_fibers
  Async do |task|
    task.async do
      Current.request_id = "req-A"
      puts "  [A] set request_id=req-A, sleeping (simulated I/O, yields to scheduler)..."
      sleep(0.3)
      puts "  [A] woke back up. Current.request_id is now: #{Current.request_id.inspect}"
    end
    task.async do
      sleep(0.1) # let A set its value and go to sleep first
      puts "  [B] (while A is asleep) setting request_id=req-B"
      Current.request_id = "req-B"
    end
  end
end

puts "---- isolation_level = :thread (Rails' default) ----"
run_two_fibers

puts
ActiveSupport::IsolatedExecutionState.isolation_level = :fiber
puts "---- isolation_level = :fiber (config.active_support.isolation_level = :fiber) ----"
run_two_fibers
