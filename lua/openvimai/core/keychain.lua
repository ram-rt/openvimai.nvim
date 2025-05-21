local uv = vim.loop

local function exec(cmd)
    local handle = io.popen(cmd, "r")
    if not handle then return nil end
    local out = handle:read("*a")
    handle:close()
    return (out:gsub("%s+$", ""))      -- trim
end

local M = {}

--- best-effort fetch of stored JWT token
function M.get_token()
    -- macOS Keychain
    if uv.os_uname().sysname == "Darwin" then
        return exec([[security find-generic-password -s openvimai_jwt -w 2>/dev/null]])
    end

    -- Linux secret-tool (freedesktop/gnome-keyring)
    return exec([[secret-tool lookup openvimai jwt 2>/dev/null]])
end

return M
