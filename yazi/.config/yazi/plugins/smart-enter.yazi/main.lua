--- @since 25.5.31
--- @sync entry
-- Enter always opens in nvim (files AND directories). Use `l` / Right to enter a folder.

local function setup(self, opts)
	self.open_multi = opts and opts.open_multi
end

local function entry(self)
	ya.emit("open", { hovered = not self.open_multi })
end

return { entry = entry, setup = setup }
