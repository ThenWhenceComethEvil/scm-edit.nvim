---@class Cursor
---@field row    integer
---@field column integer
local Cursor = {
   get_node = vim.treesitter.get_node,
   is_in_node_range = vim.treesitter.is_in_node_range,
}

---@return string
--
-- Returns the user-facing string representation of a cursor object, setting
-- one-based indices.
--
-- While cursors are stored with a zero-index, this representation better
-- reflects the output on the screen, and is more useful in debugging.
-- Displays `_' if null row/column.
function Cursor:__tostring()
   local row    = self.row    and (self.row    + 1) or "_"
   local column = self.column and (self.column + 1) or "_"
   return "{" .. row .. ", " .. column .. "}"
end


---@return Cursor, TSNode
--
-- Underlying `nvim_win_get_cursor` returns a {row,column} of index {1,0}.
-- Normalizing here such that everything in this module is zero-based.
function Cursor:get()
   local cursor = vim.api.nvim_win_get_cursor(0)
   return setmetatable({
      row    = cursor[1] - 1,
      column = cursor[2]
   }, {
      __index = self
   }), Cursor.get_node()
end


---@param node TSNode
---@param side "start" | "end"
function Cursor:set(node, side)
   if not node then
      error("expecting non-nil TSNode", 2)
   end

   local row, column
   if side == "start" then
      row, column = node:start()
   elseif side == "end" then
      row, column = node:end_()
      column = column - 1 -- end column is non-inclusive
   else
      error("side must be one of ['start', 'end']", 2)
   end

   return vim.api.nvim_win_set_cursor(0, {row+1, column})
end


---@param opts { row:integer, column:integer }
function Cursor:set_offset(opts)
   vim.api.nvim_win_set_cursor(0, {
      self.row    + (opts.row    or 0) + 1,
      self.column + (opts.column or 0)
   })
end


---@param  node    TSNode
---@param  side    "start" | "end"
---@return boolean
-- 
-- Is the cursor behind the left edge of the node?
function Cursor:is_behind(node, side)
   local node_row, node_col
   if side == "start" then
      node_row, node_col = node:start()
   elseif side == "end" then
      node_row, node_col = node:end_()
      node_col = node_col - 1 -- end column is non-inclusive
   else
      error("side must be one of ['start', 'end']", 2)
   end

   return (node_row   > self.row) or   -- Later line.
          ((node_row == self.row) and  -- Same line...
           (node_col >= self.column))  -- ...later column.
end


---@param  node    TSNode
---@param  side    "start" | "end"
---@return boolean
-- 
-- Is the cursor ahead the right edge of the node?
function Cursor:is_ahead(node, side)
   local node_row, node_col
   if side == "start" then
      node_row, node_col = node:start()
   elseif side == "end" then
      node_row, node_col = node:end_()
      node_col = node_col - 1 -- end column is non-inclusive
   else
      error("side must be one of ['start', 'end']", 2)
   end

   return (node_row   < self.row) or   -- Previous line.
          ((node_row == self.row) and  -- Same line...
           (node_col  < self.column))  -- ...previous column.
end


local function contains(cursor, node)
   local start_row, start_column, end_row, end_column = node:range()
   end_column = end_column - 1

end


---@param node TSNode
---@return boolean
--
-- Cursor is within a node, but after its start position. Example:
--
-- ```scheme
-- ;; These are valid positions:
--    (define foo "bar")
-- ;;   ^---^  ^^  ^--^
--
-- ;; These are not.
--   (define foo "bar")
-- ;; ^      ^   ^
-- ```
--
-- I didn't know of `vim.treesitter.is_in_node_range()`. Before I was working
-- on this...
--
-- ```lua
-- ```
function Cursor:after_start(node)
   local start_row, start_column, end_row, end_column = node:range()
   end_column = end_column - 1 -- non-inclusive upper bound offset.

   return
      -- cursor between start & end lines, implicitly falls after the start, yet
      -- before the end.
      ((self.row > start_row) and
       (self.row < end_row))

      or -- single-line node
      ((start_row == end_row) and
       (self.column >= start_column) and
       (self.column <= end_column))

      or -- cursor on initial row
      ((self.row == start_row) and
       (self.column > start_column))

      or -- cusor on ending row
      ((self.row == end_row) and
       (self.column <= end_column))
end


---@param node TSNode
---@return boolean
--
-- Cursor is within a node, but before its end position. Example:
-- ```scheme
-- ;; These are valid positions:
--    (define foo "bar")
-- ;;  ^---^  ^^  ^--^
--
-- ;; These are not.
--   (define foo "bar")
-- ;;      ^   ^     ^
-- ```
function Cursor:before_end(node)
   local start_row, start_column, end_row, end_column = node:range()
   end_column = end_column - 1 -- non-inclusive upper bound offset.

   return
      -- cursor between start & end lines, obviously falls after the start, yet
      -- before the end.
      ((self.row > start_row) and
       (self.row < end_row))

      or -- single-line node
      ((start_row == end_row) and
       (self.column >= start_column) and
       (self.column  < end_column))

      or -- cursor on initial row
      ((self.row == start_row) and
       (self.column > start_column))

      or -- cusor on ending row
      ((self.row == end_row) and
       (self.column  < end_column))
end



return Cursor
