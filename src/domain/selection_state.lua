-- SPDX-License-Identifier: AGPL-3.0-or-later
-- Copyright (C) 2026 Jonathan Willian

local SelectionState = {}

function SelectionState.new() return { set = {}, count = 0 } end

function SelectionState.set(state, id, on)
  on = on and true or nil
  if on == state.set[id] then return end
  state.set[id] = on
  state.count = state.count + (on and 1 or -1)
end

function SelectionState.has(state, id) return state.set[id] == true end

function SelectionState.clear(state) state.set, state.count = {}, 0 end

function SelectionState.prune(state, presentIds)
  local kept, n = {}, 0
  for id in pairs(state.set) do
    if presentIds[id] then kept[id], n = true, n + 1 end
  end
  state.set, state.count = kept, n
end

return SelectionState
