-- Parsing utilities
local util = {}

---Decode a JavaScript string literal by removing quotes and unescaping
---
---@param js_string string as captured from source (with quotes)
---@return string decoded string value
function util.decode_js_string_literal(js_string)
	---@type string
	local string_to_decode
	if js_string:match("^'") and js_string:match("'$") then
		string_to_decode = js_string:gsub("\\'", "'")
		string_to_decode = string_to_decode:gsub('"', '\\"')
		string_to_decode = string_to_decode:gsub("^'", '"')
		string_to_decode = string_to_decode:gsub("'$", '"')
	else
		string_to_decode = js_string
	end

	local ok, decoded = pcall(vim.json.decode, string_to_decode)
	assert(ok, decoded)
	assert(type(decoded) == "string", string.format("Decoded JS string is not a string, but a %s", type(decoded)))
	return decoded
end

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
