local ui     = require("openvimai.ui.float")
local client = require("openvimai.core.client")

local Chat = {}
Chat.__index = Chat

-- Singleton: stores a single active chat session
local CURRENT = nil

--- Returns existing chat session or creates a new one
function Chat.get()
	if CURRENT then
		local buf_valid = vim.api.nvim_buf_is_valid(CURRENT.buf)
		local win_valid = vim.api.nvim_win_is_valid(CURRENT.win)

		if buf_valid and not win_valid then
			local win = ui.show("OpenVimAI Chat", "")
			vim.api.nvim_win_set_buf(win, CURRENT.buf)
			CURRENT.win = win
			ui.resize(win, vim.api.nvim_buf_get_lines(CURRENT.buf, 0, -1, false))
			return CURRENT
		elseif buf_valid and win_valid then
			return CURRENT
		end
	end

	local win, buf = ui.show("OpenVimAI Chat", "")
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype   = "markdown"
	CURRENT = setmetatable({ win = win, buf = buf, history = {} }, Chat)
	return CURRENT
end

--- Build full prompt from conversation history
function Chat.build_prompt(history)
	local parts = {}
	for _, msg in ipairs(history) do
		local tag = (msg.role == "user") and "User:" or "Assistant:"
		table.insert(parts, tag .. " " .. msg.content)
	end
	table.insert(parts, "Assistant:")
	return table.concat(parts, "\n")
end

--- Append a new line to the buffer and resize the window
function Chat:append_line(line)
	vim.api.nvim_buf_set_lines(self.buf, -1, -1, false, { line })
	ui.resize(self.win, vim.api.nvim_buf_get_lines(self.buf, 0, -1, false))
end

--- Add user message and trigger assistant response
function Chat:user_say(text)
	if text:match("^%s*$") then return end
	table.insert(self.history, { role = "user", content = text })
	self:append_line("**You:** " .. text)
	self:model_reply()
end

--- Generate assistant response and stream output to popup
function Chat:model_reply()
	local prompt = Chat.build_prompt(self.history)
	local start_row = vim.api.nvim_buf_line_count(self.buf)
	vim.api.nvim_buf_set_lines(self.buf, start_row, start_row, false, { "" })

	local acc = {}

	client.stream_prompt(
		prompt,
		function(tok)
			table.insert(acc, tok)
			vim.schedule(function()
				local lines = vim.split(table.concat(acc), "\n", { plain = true })
				vim.api.nvim_buf_set_lines(self.buf, start_row, -1, false, lines)
				ui.resize(self.win, vim.api.nvim_buf_get_lines(self.buf, 0, -1, false))
			end)
		end,
		function(full)
			vim.schedule(function()
				local lines = vim.split(full, "\n", { plain = true })
				vim.api.nvim_buf_set_lines(self.buf, start_row, -1, false, lines)
				table.insert(self.history, { role = "assistant", content = full })
				ui.resize(self.win, vim.api.nvim_buf_get_lines(self.buf, 0, -1, false))
			end)
		end
	)
end

return Chat
