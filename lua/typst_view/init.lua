local config = require('typst_view.config')

local M = {}

--- Configure typst-view. Idempotent: calling it twice replaces the config rather
--- than erroring, so a user's setup can be re-run from a scratch buffer.
--- @param overrides table?
--- @return table the resolved config
function M.setup(overrides)
  config.resolve(overrides or {})
  return config.values
end

--- What the plugin currently knows about itself. Handy while building: if this
--- reports the right version and config, the module graph is wired correctly.
--- @return table
function M.status()
  return {
    name = 'typst-view',
    loaded = true,
    config = config.values,
  }
end

return M
