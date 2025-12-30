-- Parsing utilities

local util = {}

---Strip leading whitespace from a line
---@param line string
---@return string line without indentation
---@return number indentation level (number of leading whitespaces)
function util.strip_identation(line)
	local indentation = line:match("^%s+")
	if indentation then
		return line:sub(#indentation + 1), #indentation
	else
		return line, 0
	end
end

return util
