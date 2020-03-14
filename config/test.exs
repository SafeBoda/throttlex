use Mix.Config

config :throttlex, ThrottlexTest.Throttler,
  buckets: [
    bucket0: [gc_interval: 300, slot_size: 10],
    bucket1: [gc_interval: 300, slot_size: 60],
    bucket2: [gc_interval: 300, slot_size: 120]
  ]
