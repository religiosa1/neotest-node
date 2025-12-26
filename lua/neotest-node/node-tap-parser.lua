---@enum ParserState
local parser_state = {
	General = 0,
	TestResult = 1,
	YamlDiagnostic = 2,
}

---@param line string TAP test line ("ok" or "not ok")
---@return neotest.ResultStatus
local get_result_status = function(line)
	if not string.match(line, "%s*ok ") then
		return "failed"
	end
	if string.match(line, "# SKIP$") then
		return "skipped"
	end
	return "passed"
end

---Parser for node-flavored TAP reporter.
---@class TapParser
---@field file_path string Path of the test-file executed (prepended to position_id)
---@field output string Path to file, containing test output
---@field private parser_state ParserState
---@field private suite_stack string[]
---@field private results table<string, neotest.Result>
---@field private current_error_lines string[]
---@field private current_test_name string?
local TapParser = {}
TapParser.__index = TapParser

---Create a new TapParser instance
---@param file_path string Path to test file being parsed
---@param output string Path to file, containing test run output
---@return TapParser
function TapParser.new(file_path, output)
	local self = setmetatable({}, TapParser)
	self.file_path = file_path
	self.output = output
	self.parser_state = parser_state.General
	self.suite_stack = {}
	self.results = {}
	self.current_test_name = nil
	return self
end

---@private
---@param test_name string
---@return string position_id as concatenation of file_path, suite stack and name
function TapParser:make_position_id(test_name)
	local position_id = ""
	position_id = position_id .. "::" .. test_name
	return position_id
end

---Parse a single line of TAP output
---@param line string Line of TAP input
function TapParser:parse_line(line)
	-- General State operations
	-- Header info
	if string.match(line, "TAP version 1[34]") then
		return
	end
	-- Execution plan
	if string.match(line, "^%s*%d+%.%.%d+") then
		return
	end
	-- Test Result
	if string.match(line, "^%s*ok %d") or string.match(line, "^%s*not ok %d") then
		self.parser_state = parser_state.TestResult
		-- TODO: capture indentation level change for capturing stack trace
		local test_name = string.match(line, "ok %d - (.+)( ?#.*)?$")
		self.current_test_name = test_name
		self.results[self:make_position_id(test_name)] = {
			status = get_result_status(line),
			output = self.output,
		}
		return
	end
	if self.parser_state == parser_state.TestResult and string.match(line, "^%s*---$") then
		self.parser_state = parser_state.YamlDiagnostic
	end
	if self.parser_state == parser_state.YamlDiagnostic then
		if string.match(line, "^%s*...$") then
			self.parser_state = parser_state.General
		else
			-- TODO: stateful diagnostics parser; capture error message and line number
		end
	end
end

---Get all results parsed so far (cumulative)
---@return table<string, neotest.Result>
function TapParser:get_results()
	return self.results
end

return TapParser
