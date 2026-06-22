-- Luacheck config for the Komga KOReader plugin.
-- KOReader runs under LuaJIT (Lua 5.1 semantics + a few 5.2 extras).
std = "luajit+lua52"

-- Line length is not enforced (some prose comments run long).
max_line_length = false

-- Globals injected by the KOReader runtime that plugin code may read.
read_globals = {
  "G_reader_settings",
}

-- Specs use the busted DSL. Unit specs monkeypatch os.remove to assert cleanup;
-- the integration spec stubs package.path / UIManager.show to drive real widgets.
-- Both intentionally set read-only fields of globals, so allow that under spec/.
files["spec/"] = {
  std = "luajit+lua52+busted",
  ignore = {
    "122", -- setting a read-only field of a global (os.remove / package.path / UIManager stubs)
  },
}
