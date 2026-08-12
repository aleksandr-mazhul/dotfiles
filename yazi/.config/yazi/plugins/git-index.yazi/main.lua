--- @since 25.5.31
-- Pretty preview for .git/index (DIRC), no git CLI.

local M = {}

local function preview_script()
	local conf = os.getenv("YAZI_CONFIG_HOME")
	if not conf or conf == "" then
		local xdg = os.getenv("XDG_CONFIG_HOME")
		if xdg and xdg ~= "" then
			conf = xdg .. "/yazi"
		else
			conf = (os.getenv("HOME") or "") .. "/.config/yazi"
		end
	end
	return conf .. "/plugins/git-index.yazi/preview.py"
end

function M:peek(job)
	local child, err = Command("python3")
		:arg({ preview_script(), tostring(job.file.url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		ya.preview_widget(job, ui.Text(string.format("Failed to start preview: %s", err)):area(job.area))
		return
	end

	local limit = job.area.h
	local i, lines = 0, {}
	repeat
		local next_line, event = child:read_line()
		if event ~= 0 then
			break
		end
		i = i + 1
		if i > job.skip then
			lines[#lines + 1] = next_line:gsub("\r?\n$", "")
		end
	until i >= job.skip + limit

	child:start_kill()

	if job.skip > 0 and i < job.skip + limit then
		ya.emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
		return
	end

	ya.preview_widget(job, ui.Text(table.concat(lines, "\n")):area(job.area):wrap(ui.Wrap.YES))
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then
		return
	end

	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step

	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

function M:spot(job)
	require("file"):spot(job)
end

return M
