local M = {}

M.defaults = {
	endpoint = "http://127.0.0.1:8000",  -- FastAPI proxy endpoint
    ----------------------------------------------------------------
    -- ⚑ JWT token for the proxy
    -- • use the one from setup{ jwt_token = … }            (priority 1)
    -- • otherwise, use $OPENVIMAI_JWT_TOKEN                (priority 2)
    -- • otherwise, try to fetch it from the system keychain (fallback)
    ----------------------------------------------------------------
    jwt_token  = os.getenv("OPENVIMAI_JWT_TOKEN") or "",
    jwt_secret = os.getenv("JWT_SECRET_KEY") or os.getenv("OPENVIMAI_JWT_SECRET") or "",
	timeout  = 15000                    -- Request timeout in milliseconds
}

--- Merge user-provided options with default configuration
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

-- Fallback to defaults if plugin is loaded without calling setup()
M.setup()

return M
