-- Node.js TAP reporter implementation reference:
-- https://github.com/nodejs/node/blob/main/lib/internal/test_runner/reporter/tap.js
-- The tapEscape() function escapes: # \ \n \t \r \f \b \v

local util = require("neotest-node.util")
local YamlDiagnosticsParser = require("neotest-node.yaml-diagnostics-parser")

---@enum ParserState
local parser_state = {
	General = 0,
	TestResult = 1,
	YamlDiagnostic = 2,
}

---Remove TAP escaping from a line -- but only the minimal part \\ and \#,
---@param line string input line
---@return string line with escaping expanded
local function unescape(line)
	local unescaped = line:gsub("\\(.)", function(c)
		if c == "\\" or c == "#" then
			return c
		else
			return "\\" .. c -- Not a recognized escape, keep as-is
		end
	end)
	return unescaped
end

---Split a line into the contents part and optional comment part, considering
---potential comment escaping syntax "\#"
---Comment char '#' won't be included into either of return parts. Single
---whitespace before the '#' char will also be stripped away.
---Leading whitespaces are preserved in both return values.
---@return string the contents part
---@return string? comment part of a string
local function split_comment(line)
	---@type number | nil
	local found_position = nil
	local has_preceding_whitespace = false
	local has_preceding_backslash = false
	for i = 1, #line do
		local v = string.sub(line, i, i)
		local ws = (not has_preceding_backslash) and v == " "
		local bs = v == "\\"

		if v == "#" and not has_preceding_backslash then
			found_position = i
			break
		end
		has_preceding_whitespace = ws
		has_preceding_backslash = bs and not has_preceding_backslash
	end

	if found_position ~= nil then
		if has_preceding_whitespace then
			return unescape(line:sub(1, found_position - 2)), line:sub(found_position + 1)
		else
			return unescape(line:sub(1, found_position - 1)), line:sub(found_position + 1)
		end
	end
	return unescape(line), nil
end

---@param line string TAP test line without comment ("ok" or "not ok")
---@param comment string? comment part (as retrieved by split_comment)
---@return neotest.ResultStatus
local function get_result_status(line, comment)
	if not line:match("^%s*ok ") then
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
local function get_test_name(test_line)
	return test_line:match("^%s*ok %d+ %- (.+)$") or test_line:match("^%s*not ok %d+ %- (.+)$")
end

---Parser for node-flavored TAP reporter.
---see TAP website https://testanything.org/
---@class TapParser
---@field file_path string Path of the test-file executed (prepended to position_id)
---@field private parser_state ParserState
---@field private suite_stack string[]
---@field private results table<string, neotest.Result>
---@field private current_error_lines string[]
---@field private current_test_name string?
---@field private tap_line_number number
---@field private indentation_level number
---@field private diagnosticsParser YamlDiagnosticsParser?
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
	self.indentation_level = 0
	return self
end

---Parse a single line of TAP output
---@param line string Line of TAP input
function TapParser:parse_line(line)
	self.tap_line_number = self.tap_line_number + 1
	if self.parser_state == parser_state.YamlDiagnostic then
		if line:match("^%s*...$") then
			self.parser_state = parser_state.General
			if self.diagnosticsParser then
				local position_id = self:make_position_id(self.current_test_name)
				if self.results[position_id] then
					self.results[position_id].errors = self.diagnosticsParser:get_errors()
				end
			end
			self.diagnosticsParser = nil
			return
		else
			self.diagnosticsParser:parse_line(line)
		end
	elseif self.parser_state == parser_state.TestResult then
		if self.parser_state == parser_state.TestResult and line:match("^%s*---$") then
			self.parser_state = parser_state.YamlDiagnostic
			self.diagnosticsParser = YamlDiagnosticsParser.new(self.file_path)
			return
		else
			self.parser_state = parser_state.General
			self:parse_general_line(line)
		end
	else
		self:parse_general_line(line)
	end
end

---Get all results parsed so far (cumulative)
---@return table<string, neotest.Result>
function TapParser:get_results()
	return self.results
end

---@private
---@param line string
function TapParser:parse_general_line(line)
	-- Header info
	if line:match("TAP version 1[34]") then
		return
	end

	local stripped, indentation_level = util.strip_identation(line)
	local indentation_diff = self.indentation_level - indentation_level
	self.indentation_level = indentation_level

	-- Execution plan; in node TAP, it comes immediately after a suite,
	-- so we're popping a suite from the stack
	if stripped:match("^%d+%.%.%d+") then
		table.remove(self.suite_stack)
		return
	end
	-- Subtest marker: can be a test or a suite, we don't know for now;
	-- if it's a test we'll pop it back in test line parsing
	local subtest_marker = stripped:match("^# Subtest: (.+)")
	if subtest_marker then
		table.insert(self.suite_stack, subtest_marker)
	end
	-- Test Line, aka result
	if stripped:match("^ok %d") or stripped:match("^not ok %d") then
		self.parser_state = parser_state.TestResult
		-- the same indentation as subtest marker previously, so it's a test, not a suite
		if indentation_diff == 0 then
			table.remove(self.suite_stack)
		end
		local payload, comment = split_comment(stripped)
		local test_name = get_test_name(payload)
		assert(test_name, "No test name extracted from a test result line")
		self.current_test_name = test_name
		self.results[self:make_position_id(test_name)] = {
			status = get_result_status(stripped, comment),
		}
		return
	end
end

---@private
---@param test_name string
---@return string position_id as concatenation of file_path, suite stack and name
function TapParser:make_position_id(test_name)
	local position_id = self.file_path or ""
	for _, suite in ipairs(self.suite_stack) do
		position_id = position_id .. "::" .. suite
	end
	position_id = position_id .. "::" .. test_name
	return position_id
end

return TapParser
