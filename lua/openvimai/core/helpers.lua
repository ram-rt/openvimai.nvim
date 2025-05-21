local M = {}

--- Return text from current visual selection, or nil if not available
function M.get_visual_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" and mode ~= "" then
		return nil
	end

	local start = vim.fn.getpos("'<")
	local finish = vim.fn.getpos("'>")
	local lines = vim.api.nvim_buf_get_lines(0, start[2] - 1, finish[2], false)

	if #lines == 0 then return nil end

	-- Trim first and last lines based on selected columns
	lines[1] = lines[1]:sub(start[3])
	lines[#lines] = lines[#lines]:sub(1, finish[3])

	return table.concat(lines, "\n")
end

return M
