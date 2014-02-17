def time
  start = Time.now
  result = yield
  t = Time.now - start
  [result, t]
end