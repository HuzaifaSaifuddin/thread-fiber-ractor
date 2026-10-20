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

(filled in as each step is added — see commit history for the order this
was actually built in)

## Setup

```
bundle install
ruby 01_gvl_thread_basics.rb
```

Each file is standalone — `ruby <file>.rb` runs it directly.
