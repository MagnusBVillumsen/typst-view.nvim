-- Finds renderable Typst blocks with tree-sitter. Read-only: this module never
-- touches the terminal, never renders, never mutates a buffer. It answers one
-- question -- "what blocks are in this buffer, and what should be done with each"
-- -- so that the render layer can stay ignorant of grammar details.

local M = {}

-- Code that configures the document rather than producing output. These are not
-- rendered; they are collected and replayed as a prelude for later blocks.
local PRELUDE_TYPES = { let = true, set = true, import = true, show = true }

-- Calls that produce no visible content worth an image.
local SKIP_CALLS = { pagebreak = true }

--- @class Block
--- @field kind 'math' | 'code'
--- @field subtype string  'math' | 'prelude' | 'call' | 'other'
--- @field ident string    for calls: the callee name, else ''
--- @field node userdata   the tree-sitter node
--- @field range integer[] {start_row, start_col, end_row, end_col}, 0-based

--- Classify a code node by its first meaningful child.
--- @param bufnr integer
--- @param node userdata
--- @return string subtype, string ident
local function classify_code(bufnr, node)
  for child in node:iter_children() do
    if child:named() then
      local ctype = child:type()
      if PRELUDE_TYPES[ctype] then
        return 'prelude', ''
      end
      if ctype == 'call' then
        -- nvim 0.12 returns a list of nodes per field name, not a single node.
        local callee = (child:field('item') or {})[1]
        local ident = callee and vim.treesitter.get_node_text(callee, bufnr) or ''
        return 'call', ident
      end
    end
  end
  return 'other', ''
end

--- Collect outermost math and code nodes. Descent stops at a collected node, so
--- a nested node can never be reported twice -- which is why this needs no
--- containment bookkeeping.
--- @param bufnr integer
--- @param node userdata
--- @param out Block[]
local function walk(bufnr, node, out)
  local ctype = node:type()
  if ctype == 'math' then
    out[#out + 1] = {
      kind = 'math',
      subtype = 'math',
      ident = '',
      node = node,
      range = { node:range() },
    }
    return
  elseif ctype == 'code' then
    local subtype, ident = classify_code(bufnr, node)
    out[#out + 1] = {
      kind = 'code',
      subtype = subtype,
      ident = ident,
      node = node,
      range = { node:range() },
    }
    return
  end
  for child in node:iter_children() do
    walk(bufnr, child, out)
  end
end

--- Scan a buffer for blocks.
--- @param bufnr integer
--- @return Block[] ordered by position in the document
function M.scan(bufnr)
  local ok, blocks = pcall(function()
    local parser = vim.treesitter.get_parser(bufnr, 'typst')
    local trees = parser:parse()
    if not trees or not trees[1] then
      return {}
    end
    local out = {}
    walk(bufnr, trees[1]:root(), out)
    return out
  end)
  if not ok then
    -- Surfaced rather than swallowed: a silent empty result is indistinguishable
    -- from a document with no math, which makes grammar breakage invisible.
    vim.schedule(function()
      vim.notify('typst-view: block scan failed: ' .. tostring(blocks), vim.log.levels.WARN)
    end)
    return {}
  end
  return blocks
end

--- Whether a block should be rendered as an image.
--- @param block Block
--- @return boolean
function M.is_renderable(block)
  if block.kind == 'math' then
    return true
  end
  if block.subtype == 'prelude' then
    return false
  end
  if block.subtype == 'call' and SKIP_CALLS[block.ident] then
    return false
  end
  return block.subtype == 'call' or block.subtype == 'other'
end

--- Whether a block feeds the prelude that later blocks are rendered against.
--- @param block Block
--- @return boolean
function M.is_prelude(block)
  return block.kind == 'code' and block.subtype == 'prelude'
end

return M
