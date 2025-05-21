local M = {}

function M.count(text)
  return math.ceil(#text / 4)
end

return M
