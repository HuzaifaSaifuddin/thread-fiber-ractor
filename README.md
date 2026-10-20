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

Actual output from each script, run on the machine this repo was built on
(Ruby 4.0.7, Apple M1). Your own numbers will differ — that's expected, run
them yourself.

<details>
<summary><code>01_gvl_thread_basics.rb</code></summary>

```
---- CPU-bound: does Thread give you parallelism? ----
Two calls, one after another:   5.77s
Same two calls, on two Threads:  5.79s
speedup: 1.0x  (expect ~1.0x — the GVL serializes CPU-bound Ruby)

---- I/O-bound: does Thread give you concurrency? ----
Two sleeps, one after another:  2.0s
Same two sleeps, on two Threads: 1.01s
speedup: 1.98x  (expect ~2.0x — I/O releases the GVL)
```
</details>

<details>
<summary><code>02_thread_ceiling.rb</code></summary>

```
Creating Threads until the OS refuses...
Hit a hard OS wall at 2046 threads -- can't create Thread: Resource temporarily unavailable

Creating 50000 Fibers (not an OS construct — no equivalent ceiling)...
Created all 50000 Fibers with zero errors (24.4x past where Threads hit their wall)
```
</details>

<details>
<summary><code>03_fiber_basics.rb</code></summary>

```
---- pause and resume, interleaved with main ----
main: about to resume
fiber: step 1
main: back in control
fiber: step 2
main: back again
fiber: step 3
main: fiber finished, alive? false

---- a fiber only runs on whichever thread calls #resume ----
main thread id:   16
fiber sees thread: 16
resuming from a different thread raised: FiberError: fiber called across threads
```
</details>

<details>
<summary><code>04_fiber_is_not_a_speed_trick.rb</code></summary>

```
plain loop: 0.0824s
fiber:      0.5839s
fiber is 7.1x SLOWER than a plain loop for this
```
</details>

<details>
<summary><code>05_fiber_scheduler.rb</code></summary>

```
---- Threads: 20 concurrent 'slow I/O calls' (sleep 1 each) ----
  wall time: 1.01s
  OS threads used: 20 (one per call)

---- Fibers + scheduler: same 20 calls, one task.async each ----
  wall time: 1.0s
  OS threads used: 1 (every task cooperatively shared the same thread)

---- Now push past where Threads hit their wall (02_thread_ceiling.rb found ~2,046) ----
Running 3000 concurrent 'slow calls' as Fibers -- Thread.new would have crashed by now.
  wall time: 1.11s
  3000 concurrent I/O-bound calls, 1 OS thread, no crash.
```
</details>

<details>
<summary><code>06_fiber_has_no_preemption.rb</code></summary>

```
[CPU-bound fiber] finished after 2.0s
[I/O fiber]        finished after 2.1s (expected ~0.1s if it weren't starved)
```
</details>

<details>
<summary><code>07_ractor_basics.rb</code></summary>

```
r1.value => "hello from a ractor"

r2.value => "ractor received: ping from main"

main Ractor is: #<Ractor:#1 running>
Ractor.main?   => true
```
</details>

<details>
<summary><code>08_ractor_sharing_rules.rb</code></summary>

```
---- 1. closures over a mutable outer variable are refused at Ractor.new time ----
ArgumentError: can not isolate a Proc because it accesses outer variables (arr).

---- 2. #send of a mutable object copies it -- different object_id ----
result: [1, 2, 3, 4], original: [1, 2, 3]
same object_id? false

---- 3. #send of a frozen object shares it by true reference ----
same object_id? true

---- 4. move: true transfers ownership instead of copying ----
result: [1, 2, 3, 4]
touching the original after move: Ractor::MovedError: can not send any methods to a moved object

---- 5. Ractor.make_shareable deep-freezes recursively ----
outer frozen? true, nested array frozen? true

---- 6. a Ractor is itself shareable -- non-main Ractors can't mutate its ivars ----
Ractor::IsolationError: can not access instance variables of shareable objects from non-main Ractors
```
</details>

<details>
<summary><code>09_ractor_vs_thread_cpu.rb</code></summary>

```
4 workers, each counting primes up to 600000

---- Serial: 4 calls, one after another ----
  wall time: 5.79s

---- Threads: 4 concurrent, same GVL ----
  wall time: 5.82s
  speedup vs serial: 0.99x

---- Ractors: 4 concurrent, independent GVLs ----
  wall time: 1.73s
  speedup vs serial: 3.35x
```
</details>

<details>
<summary><code>10_thread_current_gotcha.rb</code></summary>

```
---- isolation_level = :thread (Rails' default) ----
  [A] set request_id=req-A, sleeping (simulated I/O, yields to scheduler)...
  [B] (while A is asleep) setting request_id=req-B
  [A] woke back up. Current.request_id is now: "req-B"

---- isolation_level = :fiber (config.active_support.isolation_level = :fiber) ----
  [A] set request_id=req-A, sleeping (simulated I/O, yields to scheduler)...
  [B] (while A is asleep) setting request_id=req-B
  [A] woke back up. Current.request_id is now: "req-A"
```
</details>

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
