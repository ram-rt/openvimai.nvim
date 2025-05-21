local M = {}

--- Safely close a floating window
local function close(win)
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

--- Show a floating popup window with optional title and initial text
function M.show(title, text)
	local lines = vim.split(text or "", "\n", { plain = true })

	local width = 20
	local height = math.max(#lines, 1)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		border = "rounded",
		title = title or "OpenVimAI",
		style = "minimal",
	})

	pcall(vim.api.nvim_win_set_option, win, "winhl", "NormalFloat:Normal,FloatBorder:FloatBorder")

	local opts = { nowait = true, noremap = true, silent = true, buffer = buf }
	vim.keymap.set("n", "<Esc>", function() close(win) end, opts)
	vim.keymap.set("n", "q",     function() close(win) end, opts)

	return win, buf
end

--- Resize an existing popup window based on given lines
function M.resize(win, lines)
	if not vim.api.nvim_win_is_valid(win) then return end

	local max_width = math.floor(vim.o.columns * 0.5)
	local max_height = math.floor(vim.o.lines * 0.5)

	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(math.max(width, 20), max_width)
	local height = math.min(#lines, max_height)

	vim.api.nvim_win_set_config(win, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2),
		col = math.floor((vim.o.columns - width) / 2),
	})
end

return M
