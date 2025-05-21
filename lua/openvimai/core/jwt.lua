local jwt  = {}
local uv   = vim.loop

-- base64url helpers ----------------------------------------------------------
local b64 = function(data) return vim.fn.system("base64 | tr '+/' '-_' | tr -d '='", data):gsub("%s+$","") end
local hmac = function(key, data)
  local bin = vim.fn.system({"openssl", "dgst", "-binary", "-sha256", "-hmac", key}, data)
  return b64(bin)
end

local function json(obj)
  return vim.fn.json_encode(obj):gsub("\\u0026","&")   -- cleaner
end

-- generate HS256 JWT ---------------------------------------------------------
function jwt.encode(payload, secret)
  local header  = { alg = "HS256", typ = "JWT" }
  local seg1    = b64(json(header))
  local seg2    = b64(json(payload))
  local sig     = hmac(secret, seg1 .. "." .. seg2)
  return seg1 .. "." .. seg2 .. "." .. sig
end

return jwt
