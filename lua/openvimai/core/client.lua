local cfg  = require("openvimai.config")
local util = require("openvimai.core.util")
local keyc = require("openvimai.core.keychain")
local jwt  = require("openvimai.core.jwt")

local function refresh_token()
    local now = os.time()
    if cfg._token_ts and now - cfg._token_ts < 3000 then return end  -- <50 мин, ок

    if cfg.options.jwt_token ~= "" then
        cfg._token_ts = now
        return
    end

    local secret = cfg.options.jwt_secret
    if secret == "" then
        secret = keyc.get_token() or ""
        cfg.options.jwt_secret = secret
    end

    if secret ~= "" then
        local payload = { 
            sub = "openvimai", 
            exp = now + 3600 }
        cfg.options.jwt_token = jwt.encode(payload, secret)
        cfg._token_ts = now
    end
end

cfg.options.timeout_ms = cfg.options.timeout_ms or 15000

local M = {}

----------------------------------------------------------------
--  /health
----------------------------------------------------------------
function M.ping(cb)
    local result = vim.fn.systemlist({ "curl", "-s", cfg.options.endpoint .. "/health" })
    cb(table.concat(result, "\n"))
end

----------------------------------------------------------------
--  SSE
----------------------------------------------------------------
local function handle_line(line, acc, on_token, on_done)
    line = line:gsub("\r$", "")
    if line == "" then return end

    if line:match("^data:%s*%[DONE%]") then
        if on_done then on_done(table.concat(acc)) end
        return
    end

    local json = line:gsub("^data:%s*", "")
    local ok, chunk = pcall(util.json_decode, json)
    if not ok or not chunk or not chunk.choices then return end

    local delta = chunk.choices[1].delta
    local tok   = delta and delta.content
    if tok then
        table.insert(acc, tok)
        if on_token then on_token(tok) end
    end
end

----------------------------------------------------------------
--  stream_prompt
----------------------------------------------------------------
function M.stream_prompt(prompt, on_token, on_done)
    local acc = {}
    refresh_token()
    local cmd = {
        "curl", "-Ns",
        "--connect-timeout", tostring(cfg.options.timeout_ms / 1000),
        "-X", "POST", cfg.options.endpoint .. "/completion",
        "-H", "Content-Type: application/json",
    }

    --  Authorization
    if cfg.options.jwt_token ~= "" then
        table.insert(cmd, "-H")
        table.insert(cmd, "Authorization: Bearer " .. cfg.options.jwt_token)
    end

    -- JSON
    table.insert(cmd, "-d")
    table.insert(cmd, util.json_encode({
        prompt = prompt,
        mode   = "completion",
        stream = true,
    }))

    vim.fn.jobstart(cmd, {
        stdout_buffered = false,

        on_stdout = function(_, data)
            if not data then return end
            for _, raw in ipairs(data) do
                vim.schedule(function()
                    handle_line(raw, acc, on_token, on_done)
                end)
            end
        end,

        on_stderr = function(_, err)
            if err and err[1] ~= "" and on_done then
                vim.schedule(function()
                    on_done("ERROR: " .. table.concat(err, "\n"))
                end)
            end
        end,
    })
end

return M
