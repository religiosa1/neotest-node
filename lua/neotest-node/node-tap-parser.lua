local logger = require("neotest.logging")

---@enum ParserState
local parser_state = {
	General = 0,
	TestResult = 1,
	YamlDiagnostic = 2,
}

---Split a line into the contents part and optional comment part, considering
---potential comment escaping syntax "\#"
---Comment char '#' won't be included into either of return parts. Single
---whitespace before the '#' char will also be stripped away.
---Leading whitespaces are preserved in both return values.
---@return string the contents part
---@return string? comment part of a string
local split_comment = function(line)
	local pos = line:find(" #")
	if pos then
		return line:sub(1, pos - 1), line:sub(pos + 2)
	end

	if line:find("^#") then
		return "", line:sub(2)
	end

	pos = line:find("[^\\]#")
	if pos then
		return line:sub(1, pos), line:sub(pos + 2)
	end

	local escaping = string.match(line, "(\\+)#")
	if escaping and #escaping % 2 == 0 then
		pos = line:find("\\+#")
		return line:sub(1, pos - 1), line:sub(pos + #escaping + 1)
	end

	return line, nil
end

---@param line string TAP test line without comment ("ok" or "not ok")
---@param comment string? comment part (as retrieved by split_comment)
---@return neotest.ResultStatus
local get_result_status = function(line, comment)
	if not string.match(line, "^%s*ok ") then
		return "failed"
	end
	if comment == " SKIP" or comment == " TODO" then
		return "skipped"
	end
	return "passed"
end

---Extract test name from the test line like "ok 3 - mock passed test"
---Test line MUST not contain any comments, i.e. be preprocessed with
---strip_comment call first.
---@param test_line string
---@return string? test name if successfully parsed, nil otherwise
local get_test_name = function(test_line)
	return string.match(test_line, "^%s*ok %d+ %- (.+)$") or string.match(test_line, "^%s*not ok %d+ %- (.+)$")
end

---Parser for node-flavored TAP reporter.
---@class TapParser
---@field file_path string Path of the test-file executed (prepended to position_id)
---@field private parser_state ParserState
---@field private suite_stack string[]
---@field private results table<string, neotest.Result>
---@field private current_error_lines string[]
---@field private current_test_name string?
---@field private tap_line_number number
local TapParser = {}
TapParser.__index = TapParser

---Create a new TapParser instance
---@param file_path string Path to test file being parsed
---@return TapParser
function TapParser.new(file_path)
	local self = setmetatable({}, TapParser)
	self.file_path = file_path
	self.parser_state = parser_state.General
	self.suite_stack = {}
	self.results = {}
	self.current_test_name = nil
	self.tap_line_number = 0
	return self
end

---@private
---@param test_name string
---@return string position_id as concatenation of file_path, suite stack and name
function TapParser:make_position_id(test_name)
	local position_id = self.file_path or ""
	-- TODO: iterate over suite stack and join namespaces here
	position_id = position_id .. "::" .. test_name
	return position_id
end

---Parse a single line of TAP output
---@param line string Line of TAP input
function TapParser:parse_line(line)
	logger.info("Parsing line: ", line)
	self.tap_line_number = self.tap_line_number + 1
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
		local payload, comment = split_comment(line)
		local test_name = get_test_name(payload)
		if not test_name then
			logger.warn(
				string.format("Unable to parse test name from test line, on line %d of tap file", self.tap_line_number)
			)
		else
			self.current_test_name = test_name
			self.results[self:make_position_id(test_name)] = {
				status = get_result_status(line, comment),
			}
		end
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
