# Thread vs Fiber vs Ractor

A hands-on, numbers-first tour of Ruby's three concurrency primitives — built
after watching Shopify engineers talk through *"When Rails Met Fibers:
Migrating Sidekiq from Puma to Falcon"* at RailsConf Pune (Deccan Queen).

I'd used `Thread` my whole career without asking what's actually happening
underneath Puma. This repo is what came out of two weeks of refusing to
trust the docs and measuring Thread, Fiber, and Ractor myself instead.

Every script below prints real, measured numbers on whatever machine runs
it — nothing here is a hardcoded claim. Run them yourself; your numbers
will differ from mine, and that's the point.

## Requirements

- Ruby >= 3.2 (built and verified on Ruby 4.0.7)
- `bundle install`

## The scripts

| # | File | Finding |
|---|------|---------|
| 1 | [`01_gvl_thread_basics.rb`](01_gvl_thread_basics.rb) | 2 threads, same CPU work: ~1.0x (zero speedup). Same 2 threads doing I/O: ~2.0x. The GVL releases on I/O, never on CPU-bound Ruby. |
| 2 | [`02_thread_ceiling.rb`](02_thread_ceiling.rb) | Thread hits a hard OS ceiling (~2,046 on this machine). 50,000 Fibers succeed with zero errors — not an OS-level construct. |
| 3 | [`03_fiber_basics.rb`](03_fiber_basics.rb) | `Fiber.new` / `#resume` / `Fiber.yield`. A Fiber only runs on whichever thread calls `#resume`; resuming from another thread raises `FiberError`. |
| 4 | [`04_fiber_is_not_a_speed_trick.rb`](04_fiber_is_not_a_speed_trick.rb) | A hand-rolled Fiber generator is several times *slower* than an equivalent plain loop. Fiber's value isn't speed. |
| 5 | [`05_fiber_scheduler.rb`](05_fiber_scheduler.rb) | With a scheduler (`async` gem — the mechanism Falcon runs on), 3,000 concurrent "I/O calls" run on exactly 1 OS thread. |
| 6 | [`06_fiber_has_no_preemption.rb`](06_fiber_has_no_preemption.rb) | Cooperative scheduling has no preemption. A CPU-bound fiber with no yield point starves a ready-in-0.1s I/O fiber for its entire 2s run. |
| 7 | [`07_ractor_basics.rb`](07_ractor_basics.rb) | `Ractor.new` / `#value` / `#send` / `Ractor.receive`, verified live (Ractor's API has drifted across Ruby versions). |
| 8 | [`08_ractor_sharing_rules.rb`](08_ractor_sharing_rules.rb) | Closures over mutable locals are refused at creation time; `#send` copies; frozen objects share by reference; `move:` transfers ownership; `make_shareable` deep-freezes. |
| 9 | [`09_ractor_vs_thread_cpu.rb`](09_ractor_vs_thread_cpu.rb) | Same CPU benchmark as step 1, now on Ractor: ~3.4x real speedup on 4 workers. Independent GVLs, genuine parallel execution. |
| 10 | [`10_thread_current_gotcha.rb`](10_thread_current_gotcha.rb) | **Bonus.** Rails' `Current.user` pattern defaults to thread-wide isolation, not per-fiber — two fibers sharing a thread clobber each other's `Current` state unless `isolation_level = :fiber` is set. |

## The short version

- **Thread** gives you concurrency on I/O you already have (Puma, Sidekiq) — never parallelism on CPU-bound Ruby, and it has a hard OS ceiling.
- **Fiber** gives you I/O concurrency at a scale Thread can't reach (thousands of fibers, 1 OS thread) — but it's cooperative, with zero preemption safety net.
- **Ractor** gives you compute parallelism Thread can never provide — at the cost of real isolation: no shared mutable state, enforced by the VM.

Pick based on where your actual bottleneck is.

## Setup

```
bundle install
ruby 01_gvl_thread_basics.rb
```

Each file is standalone — `ruby <file>.rb` runs it directly, in any order,
though they're numbered in the order this was actually learned.
