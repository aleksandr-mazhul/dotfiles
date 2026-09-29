-- In-file :substitute. Vim has no default replace key; the command is :s
-- (:help :s_flags, :s_c). g replaces every match on the line, c confirms each
-- one (y/n/a/q/l), and \< \> is a whole word. Project replace stays <leader>sr.

local M = {}

local WORD_CONFIRM = { label = "Целое слово, подтверждать каждое", whole = true, flags = "gc" }
local WORD_ALL = { label = "Целое слово, заменить все", whole = true, flags = "g" }
local SUB_CONFIRM = { label = "Подстрока, подтверждать каждое", whole = false, flags = "gc" }
local SUB_ALL = { label = "Подстрока, заменить все", whole = false, flags = "g" }

function M.choices(prefer_word)
  if prefer_word then
    return { WORD_CONFIRM, WORD_ALL, SUB_CONFIRM, SUB_ALL }
  end
  return { SUB_CONFIRM, SUB_ALL, WORD_CONFIRM, WORD_ALL }
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

function M.cmdline(range, text, whole_word, flags)
  return string.format(":%ss/%s//%s", range, M.search_atom(text, whole_word), flags)
end

--- Command-line keys with "<" written as <lt>, then <Left> into the replacement slot.
function M.feed_keys(cmdline, cursor_from_end)
  return (cmdline:gsub("<", "<lt>")) .. string.rep("<Left>", cursor_from_end)
end

function M.open_cmdline(cmdline, flags)
  local keys = M.feed_keys(cmdline, #flags + 1)
  -- do_lt: <lt> becomes a literal "<" (word boundaries and the text itself).
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, true, true), "n", false)
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
    vim.notify("grug-far недоступен", vim.log.levels.WARN)
    return
  end
  grug.open({
    transient = true,
    visualSelectionUsage = "operate-within-range",
  })
end

function M.choose(text, range, prefer_word)
  vim.ui.select(M.choices(prefer_word), {
    prompt = "Замена",
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    local cmdline = M.cmdline(range, text, choice.whole, choice.flags)
    vim.schedule(function()
      M.open_cmdline(cmdline, choice.flags)
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
      vim.notify("Нечего заменять", vim.log.levels.WARN)
      return
    end
    M.choose(text, "'<,'>", false)
    return
  end

  local text = vim.fn.expand("<cword>")
  if text == "" then
    vim.notify("Нечего заменять", vim.log.levels.WARN)
    return
  end
  M.choose(text, "%", true)
end

return M
