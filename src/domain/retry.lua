-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local Retry = {}

Retry.DEFAULT_ATTEMPTS = 4

-- luasocket string codes and 5xx are flaky-connection signals; below 500 is a definitive answer.
function Retry.transient(code)
  if type(code) ~= "number" then return true end
  return code >= 500
end

function Retry.run(fn, opts)
  local attempts = opts.attempts or Retry.DEFAULT_ATTEMPTS
  local delay = 1
  for attempt = 1, attempts do
    local a, b = fn()
    if attempt == attempts or not opts.should_retry(a, b) then return a, b end
    if opts.on_retry and opts.on_retry(attempt + 1, attempts) == false then return a, b end
    opts.sleep(delay)
    delay = delay * 2
  end
end

return Retry
