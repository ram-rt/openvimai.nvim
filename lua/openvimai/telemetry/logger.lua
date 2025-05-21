local util      = require("openvimai.core.util")
local cfg       = require("openvimai.config")
local keyc      = require("openvimai.core.keychain")
local jwt       = require("openvimai.core.jwt")
local uv        = vim.loop
local data_dir  = vim.fn.stdpath("data") .. "/openvimai"
local spool     = data_dir .. "/telemetry_queue.json"   -- persisted backlog

local M = {}

local Q          = {}          -- in-mem ring
local MAX        = 64          -- events before forced flush
local FLUSH_MS   = 2000        -- interval
local flushing   = false       -- guard
----------------------------------------------------------------
-- JWT helpers (reuse logic from client.lua)
----------------------------------------------------------------
local function ensure_token()
    if cfg.options.jwt_token ~= "" then
        if cfg._token_ts and (os.time() - cfg._token_ts) < 3000 then return end
    end

    local secret = cfg.options.jwt_secret
    if secret == "" then
        secret = keyc.get_token() or ""
        cfg.options.jwt_secret = secret
    end
    if secret == "" then return end

    local payload = { sub = vim.fn.hostname(), exp = os.time() + 3600 }
    cfg.options.jwt_token = jwt.encode(payload, secret)
    cfg._token_ts = os.time()
end

-- ensure spool dir exists
vim.fn.mkdir(data_dir, "p")

----------------------------------------------------------------
-- helpers
----------------------------------------------------------------
local function dump_backlog()
    local f = io.open(spool, "w")
    if f then f:write(util.json_encode(Q)); f:close() end
end

local function load_backlog()
    local f = io.open(spool, "r")
    if not f then return end
    local ok, arr = pcall(util.json_decode, f:read("*a"))
    f:close()
    if ok and type(arr) == "table" then
        for _, ev in ipairs(arr) do table.insert(Q, ev) end
        os.remove(spool)
    end
end

local function post_batch(batch)
    ensure_token()
    local ok = vim.fn.jobwait({ vim.fn.jobstart({
        "curl", "-sS", "-X", "POST",
        cfg.options.endpoint .. "/telemetry",
        "-H", "Content-Type: application/json",
        (cfg.options.jwt_token ~= "" and "-H" or ""),
        (cfg.options.jwt_token ~= "" and ("Authorization: Bearer " .. cfg.options.jwt_token) or ""),
        "-d", util.json_encode(batch)
    }, { detach = false }) }, 5000)[1] == 0       -- 0 = success
    return ok
end

----------------------------------------------------------------
-- core: flush()
----------------------------------------------------------------
local function flush()
    if flushing or #Q == 0 then return end
    flushing = true

    local batch = Q
    Q = {}

    if not post_batch(batch) then
        for _, ev in ipairs(batch) do table.insert(Q, ev) end
        dump_backlog()
    end
    flushing = false
end

local timer
local function ensure_timer()
    if timer then return end
    timer = uv.new_timer()
    timer:start(FLUSH_MS, FLUSH_MS, vim.schedule_wrap(flush))
end

----------------------------------------------------------------
-- public: M.send(event_type, payload)
----------------------------------------------------------------
function M.send(event_type, payload)
    -- lazy-load
    if not timer then load_backlog() end

    table.insert(Q, {
        ts         = os.time(),
        event_type = event_type,
        payload    = payload,
    })

    if #Q >= MAX then flush() end
    ensure_timer()
end

vim.api.nvim_create_autocmd("VimLeavePre", {
    callback = function() flush() end,
})

return M
