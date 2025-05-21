local ntok = require("openvimai.core.approx_token").count   -- ~1 токен / 4 символа
local MAX  = 8192

local M = {}

----------------------------------------------------------------
-- helper:
----------------------------------------------------------------
local function collect_changed(patch)
    local out = {}
    for line in patch:gmatch("[^\n]+") do
        local prefix = line:sub(1, 1)
        if (prefix == "+" or prefix == "-")
            and not line:match("^%-%-%-")
            and not line:match("^%+%+%+") then
            table.insert(out, line:sub(2))
        end
    end
    return table.concat(out, "\n")
end

----------------------------------------------------------------
-- main: trim(old_code, new_code) -> context_string
----------------------------------------------------------------
function M.trim(old_code, new_code)
    old_code = old_code or ""
    new_code = new_code or ""

    if ntok(new_code) <= MAX then
        return new_code
    end

    local patch = vim.diff(
        old_code, new_code,
        { result_type = "unified", algorithm = "patience" }
    )

    local ctx = collect_changed(patch)

    while ntok(ctx) > MAX do
        ctx = ctx:sub(1, math.floor(#ctx / 2))
    end

    return ctx
end

return M
