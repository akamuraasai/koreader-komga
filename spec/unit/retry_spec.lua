-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

require("spec.helper")
local Retry = require("domain/retry")

describe("Retry.run", function()
  it("returns fn's results on first-try success without sleeping", function()
    local slept = {}
    local calls = 0
    local a, b = Retry.run(function()
      calls = calls + 1
      return 200, { ok = true }
    end, {
      should_retry = function(code) return code ~= 200 end,
      sleep = function(s) slept[#slept + 1] = s end,
    })
    assert.equals(200, a)
    assert.same({ ok = true }, b)
    assert.equals(1, calls)
    assert.equals(0, #slept)
  end)

  it("retries with exponential backoff until fn succeeds", function()
    local slept = {}
    local calls = 0
    local a, b = Retry.run(function()
      calls = calls + 1
      if calls < 3 then return "timeout", nil end
      return 200, "body"
    end, {
      should_retry = function(code) return code ~= 200 end,
      sleep = function(s) slept[#slept + 1] = s end,
    })
    assert.equals(200, a)
    assert.equals("body", b)
    assert.equals(3, calls)
    assert.same({ 1, 2 }, slept)
  end)

  it("gives up after the attempt limit and returns the last result", function()
    local slept = {}
    local calls = 0
    local a, b = Retry.run(function()
      calls = calls + 1
      return "closed", nil
    end, {
      should_retry = function() return true end,
      sleep = function(s) slept[#slept + 1] = s end,
    })
    assert.equals("closed", a)
    assert.is_nil(b)
    assert.equals(4, calls)          -- DEFAULT_ATTEMPTS
    assert.same({ 1, 2, 4 }, slept)  -- no sleep after the last attempt
  end)

  it("stops when on_retry returns false and reports which retry is next", function()
    local seen = {}
    local calls = 0
    local a = Retry.run(function()
      calls = calls + 1
      return "timeout", nil
    end, {
      should_retry = function() return true end,
      sleep = function() end,
      on_retry = function(next_attempt, attempts)
        seen[#seen + 1] = { next_attempt, attempts }
        return next_attempt < 3
      end,
    })
    assert.equals("timeout", a)
    assert.equals(2, calls)
    assert.same({ { 2, 4 }, { 3, 4 } }, seen)
  end)
end)

describe("Retry.transient", function()
  it("treats luasocket transport errors (string codes) as transient", function()
    assert.is_true(Retry.transient("timeout"))
    assert.is_true(Retry.transient("closed"))
    assert.is_true(Retry.transient("connection refused"))
    assert.is_true(Retry.transient(nil))
  end)

  it("treats 5xx as transient (proxies answer 502/504)", function()
    assert.is_true(Retry.transient(500))
    assert.is_true(Retry.transient(502))
    assert.is_true(Retry.transient(504))
  end)

  it("does not retry success, client errors, or the local-file sentinel", function()
    assert.is_false(Retry.transient(200))
    assert.is_false(Retry.transient(401))
    assert.is_false(Retry.transient(404))
    assert.is_false(Retry.transient(-1))
  end)
end)
