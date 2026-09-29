-- In-file :substitute. Vim has no default replace key; the command is :s
-- (:help :s_flags, :s_c). Both menu choices confirm each match (y/n/a/q/l);
-- `a` replaces the rest, so there is no separate "replace all" item.
-- \< \> is a whole word. Project replace stays <leader>sr.

local M = {}

local WHOLE = { label = "Whole word", whole = true }
local SUB = { label = "Substring", whole = false }

function M.choices(prefer_word)
  if prefer_word then
    return { WHOLE, SUB }
  end
  return { SUB, WHOLE }
end

--- Very-nomagic literal.
--- "/" is escaped so it is not the delimiter. "|" is written as \%x7c:
--- a backslash-bar is alternation under \V, and a raw bar splits an Ex command.
function M.search_atom(text, whole_word)
  local atom = vim.fn.escape(text, "/\\"):gsub("|", "\\%%x7c")
  if whole_word then
    return "\\V\\<" .. atom .. "\\>"
  end
  return "\\V" .. atom
end

--- Literal replacement. & and ~ are special in :s; / is the delimiter.
--- A raw | is safe here because this string is passed to vim.cmd, which does
--- not split on it. \%x7c would be inserted literally, so leave the bar as-is.
function M.replace_atom(text)
  return vim.fn.escape(text, "/\\&~")
end

local preview_ns = vim.api.nvim_create_namespace("config.substitute.preview")

--- Byte spans [start, end) of every non-overlapping match.
function M.match_spans(line, regex)
  local spans = {}
  local offset = 0
  local rest = line
  while rest ~= "" do
    local start, finish = regex:match_str(rest)
    if not start then
      break
    end
    if finish <= start then
      offset = offset + start + 1
      if offset > #line then
        break
      end
      rest = line:sub(offset + 1)
    else
      spans[#spans + 1] = { offset + start, offset + finish }
      offset = offset + finish
      rest = line:sub(offset + 1)
    end
  end
  return spans
end

--- Replace each span. Marks are byte ranges of the inserted text in the new line.
function M.splice_line(line, spans, replacement)
  if #spans == 0 then
    return line, {}
  end
  local parts = {}
  local marks = {}
  local cursor = 0
  local out = 0
  for _, span in ipairs(spans) do
    parts[#parts + 1] = line:sub(cursor + 1, span[1])
    out = out + (span[1] - cursor)
    local mark_start = out
    parts[#parts + 1] = replacement
    out = out + #replacement
    marks[#marks + 1] = { mark_start, out }
    cursor = span[2]
  end
  parts[#parts + 1] = line:sub(cursor + 1)
  return table.concat(parts), marks
end

local function without_undo(buf, fn)
  vim.api.nvim_buf_call(buf, function()
    local levels = vim.bo.undolevels
    vim.bo.undolevels = -1
    local ok, err = pcall(fn)
    vim.bo.undolevels = levels
    if not ok then
      error(err)
    end
  end)
end

--- Live :s preview for the lines in [line1, line2]. `update("")` only highlights
--- matches; a non-empty replacement rewrites those spans the way inccommand would.
--- `close()` puts the original text back and does not touch the undo stack.
function M.attach_preview(buf, win, line1, line2, pattern)
  local original = vim.api.nvim_buf_get_lines(buf, line1 - 1, line2, false)
  local was_modified = vim.bo[buf].modified
  local regex = vim.regex(pattern)
  local view = vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_call(win, vim.fn.winsaveview) or nil
  local closed = false
  local timer = vim.uv.new_timer()

  local function restore_view()
    if view and vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(view)
      end)
    end
  end

  local function clear_highlights()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, preview_ns, 0, -1)
    end
  end

  local function write_original()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    without_undo(buf, function()
      vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, original)
      clear_highlights()
      vim.bo[buf].modified = was_modified
    end)
    restore_view()
  end

  local function highlight(row, start_col, end_col, group)
    if end_col <= start_col then
      return
    end
    vim.api.nvim_buf_set_extmark(buf, preview_ns, row, start_col, {
      end_col = end_col,
      hl_group = group,
      strict = false,
    })
  end

  local function update(replacement)
    if closed or not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    without_undo(buf, function()
      vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, original)
      clear_highlights()
      if replacement == "" then
        for i, line in ipairs(original) do
          for _, span in ipairs(M.match_spans(line, regex)) do
            highlight(line1 - 2 + i, span[1], span[2], "IncSearch")
          end
        end
      else
        local replaced = {}
        local marks = {}
        for i, line in ipairs(original) do
          local new_line, line_marks = M.splice_line(line, M.match_spans(line, regex), replacement)
          replaced[i] = new_line
          for _, mark in ipairs(line_marks) do
            marks[#marks + 1] = { line1 - 2 + i, mark[1], mark[2] }
          end
        end
        vim.api.nvim_buf_set_lines(buf, line1 - 1, line2, false, replaced)
        for _, mark in ipairs(marks) do
          highlight(mark[1], mark[2], mark[3], "Substitute")
        end
      end
      vim.bo[buf].modified = was_modified
    end)
    restore_view()
    pcall(vim.api.nvim__redraw, { flush = true, win = win })
  end

  local preview = {}

  function preview.schedule(replacement)
    if closed then
      return
    end
    timer:start(25, 0, vim.schedule_wrap(function()
      update(replacement)
    end))
  end

  function preview.update(replacement)
    update(replacement)
  end

  function preview.close()
    if closed then
      return
    end
    closed = true
    timer:stop()
    timer:close()
    write_original()
  end

  return preview
end

function M.ex_command(range, text, whole_word, replacement)
  return string.format(
    "%ss/%s/%s/gc",
    range,
    M.search_atom(text, whole_word),
    M.replace_atom(replacement)
  )
end

--- Short title for the replacement prompt. The full text still goes into :s.
function M.prompt_for(text)
  local shown = text:gsub("%s+", " ")
  if vim.fn.strchars(shown) > 48 then
    shown = vim.fn.strcharpart(shown, 0, 45) .. "..."
  end
  return "Replace " .. shown .. " with"
end

function M.visual_text()
  local vmode = vim.fn.visualmode()
  if vmode == "" then
    return "", false
  end
  local lines = vim.fn.getregion(vim.fn.getpos("'<"), vim.fn.getpos("'>"), { type = vmode })
  if not lines or #lines == 0 then
    return "", false
  end
  return table.concat(lines, "\n"), #lines > 1
end

function M.open_grug_within()
  local ok, grug = pcall(require, "grug-far")
  if not ok then
    vim.notify("grug-far is not available", vim.log.levels.WARN)
    return
  end
  grug.open({
    transient = true,
    visualSelectionUsage = "operate-within-range",
  })
end

function M.apply(text, range, whole_word, replacement)
  vim.cmd(M.ex_command(range, text, whole_word, replacement))
end

function M.range_bounds(buf, range)
  if range == "%" then
    return 1, vim.api.nvim_buf_line_count(buf)
  end
  local first = vim.fn.line("'<")
  local last = vim.fn.line("'>")
  if first > last then
    first, last = last, first
  end
  return first, last
end

local function ask_replacement(prompt, on_confirm)
  local ok, Snacks = pcall(require, "snacks")
  if ok and Snacks.input then
    return Snacks.input({ prompt = prompt }, on_confirm)
  end
  vim.ui.input({ prompt = prompt }, on_confirm)
end

function M.choose(text, range, prefer_word)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local line1, line2 = M.range_bounds(buf, range)
  vim.ui.select(M.choices(prefer_word), {
    prompt = "Replace",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    local pattern = M.search_atom(text, choice.whole)
    local preview = M.attach_preview(buf, win, line1, line2, pattern)
    -- Let the select window close before opening the input float.
    vim.schedule(function()
      local input_win = ask_replacement(M.prompt_for(text), function(repl)
        preview.close()
        if repl == nil then
          return
        end
        vim.schedule(function()
          M.apply(text, range, choice.whole, repl)
        end)
      end)
      if type(input_win) ~= "table" or not input_win.buf then
        return
      end
      preview.update("")
      vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        buffer = input_win.buf,
        callback = function()
          if input_win:valid() then
            preview.schedule(input_win:text())
          end
        end,
      })
    end)
  end)
end

function M.start(from_visual)
  if from_visual then
    local text, multiline = M.visual_text()
    if multiline then
      M.open_grug_within()
      return
    end
    if text == "" then
      vim.notify("Nothing to replace", vim.log.levels.WARN)
      return
    end
    M.choose(text, "'<,'>", false)
    return
  end

  local text = vim.fn.expand("<cword>")
  if text == "" then
    vim.notify("Nothing to replace", vim.log.levels.WARN)
    return
  end
  M.choose(text, "%", true)
end

return M
