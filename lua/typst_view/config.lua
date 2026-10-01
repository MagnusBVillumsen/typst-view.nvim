-- Resolved configuration, kept separate from the public API so that every other
-- module can read config.values without going through M and without circular
-- requires once more modules arrive.

local M = {}

--- Defaults are deliberately conservative: nothing renders until a later step
--- opts in, so a half-finished plugin cannot misbehave.
local defaults = {
  -- Absolute path avoids PATH dependence at render time.
  typst_binary = 'typst',
  -- Rendered resolution. Typst's own default is 144.
  ppi = 300,
  -- 0 disables auto-render entirely.
  auto_render_delay = 250,
}

M.values = {}

--- Merge defaults with user overrides.
--- @param overrides table
function M.resolve(overrides)
  local resolved = {}
  for k, v in pairs(defaults) do
    resolved[k] = v
  end
  for k, v in pairs(overrides) do
    resolved[k] = v
  end
  M.values = resolved
  return resolved
end

return M
