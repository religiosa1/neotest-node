local util = require("neotest-node.util")

---@enum DiagnosticsParserState
local DiagnosticsParserState = {
	---Waiting for a first line to be parsed to determine the base indent
	Pending = 0,
	---General diagnostics object parsing
	General = 1,
	---Accumulating stack trace multi-string
	StackTrace = 2,
}

--- Parser for YAML blocks of node TAP reporter, containing error message and
--- a stack trace.
---@class YamlDiagnosticsParser
---@field file_path string name of the test file that is being processed
---@field private state DiagnosticsParserState
---@field private base_indent number
---@field private error_message string?
---@field private stack_trace string[]
local YamlDiagnosticsParser = {}
YamlDiagnosticsParser.__index = YamlDiagnosticsParser

---Create a new YamlDiagnosticParser
---@param file_path string Path to test file being parsed
---@return YamlDiagnosticsParser
function YamlDiagnosticsParser.new(file_path)
	local self = setmetatable({}, YamlDiagnosticsParser)
	self.file_path = file_path
	self.base_indent = 0
	self.state = DiagnosticsParserState.Pending
	self.stack_trace = {}
	return self
end

---Parse a line of the yaml block
---@param line string
function YamlDiagnosticsParser:parse_line(line)
	local stripped, indent = util.strip_identation(line)
	if self.state == DiagnosticsParserState.Pending then
		self.base_indent = indent
		self.state = DiagnosticsParserState.General
	end
	if self.state == DiagnosticsParserState.StackTrace then
		if indent <= self.base_indent then
			self.state = DiagnosticsParserState.General
		else
			table.insert(self.stack_trace, stripped)
		end
		return
	end
	-- General state parsing
	local error_msg_literal = stripped:match("^%s*error:%s*(.*)")
	if error_msg_literal then
		-- TODO: literal expansion
		self.error_message = error_msg_literal
		return
	elseif stripped:match("^stack: [>|][+-]?") then -- YML block scalar
		self.state = DiagnosticsParserState.StackTrace
		return
	end
end

---Get parsed errors if any
---@return neotest.Error[]?
function YamlDiagnosticsParser:get_errors()
	if not self.error_message then
		return nil
	end
	---@type neotest.Error
	local error = {
		message = self.error_message,
		line = self:extract_error_line_from_stack(),
	}
	return { error }
end

---@private
---@return number?
function YamlDiagnosticsParser:extract_error_line_from_stack()
	local testfile_stacktrace_line = vim.iter(self.stack_trace):find(function(line)
		return string.find(line, self.file_path, 1, true)
	end)

	if not testfile_stacktrace_line then
		return nil
	end

	local line_number_str = testfile_stacktrace_line:match(":(%d+)")
local line_number = line_number_str and tonumber(line_number_str)
  if not line_number then
    return nil
  end
  return line_number - 1 -- node reports next line for some reason
end

return YamlDiagnosticsParser
