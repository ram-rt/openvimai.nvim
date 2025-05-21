local uv = vim.loop
local M  = {}

--- Return SHA‑256 hash of a string using `shasum` CLI
function M.sha256(text)
	local path = vim.fn.tempname()
	local fd = assert(uv.fs_open(path, "w", 384)) -- 0600 permissions
	uv.fs_write(fd, text, -1)
	uv.fs_close(fd)
	local handle = io.popen("shasum -a 256 " .. path .. " | cut -d' ' -f1")
	local hash = handle:read("*l") or ""
	handle:close()
	os.remove(path)
	return hash
end

-- JSON encode/decode helpers (Neovim ≥ 0.9)
M.json_encode = vim.json.encode
M.json_decode = vim.json.decode

return M
