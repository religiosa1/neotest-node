---Parser for node-flavored TAP reporter.
---@class TapParser
---@field filename string Name of test file (used in position_id generation)
---@field private suite_stack string[] Stack of nested test suites
local TapParser = {}
TapParser.__index = TapParser

---Create a new TapParser instance
---@param filename string Name of test file (used in position_id generation)
---@return TapParser
function TapParser.new(filename)
	local self = setmetatable({}, TapParser)
	self.filename = filename
	self.suite_stack = {}
	return self
end

---Consume TAP file line, potentially returning a test result.
---
---@param line string Line of TAP input to be parsed
---@return table<string, neotest.Result>? Map of test IDs to results, if any
---tests completed with the line provided
function TapParser:process_line(line)
	error("Not implemented")
end

return TapParser
