-- see https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua
local lib = require("neotest.lib")
local logger = require("neotest.logging")
local TapParser = require("neotest-node.node-tap-parser")

local adapter = { name = "neotest-node" }

---@class neotest.AdapterOptions
---@field env? table<string, string> | fun(): table<string, string>
---@field cwd? string | fun(position_path: string): string?
---@field filter_dir? fun(name: string, rel_path: string, root: string): boolean
---@field is_test_file? fun(file_path: string): boolean

local all_tests_shell_pattern = "*.{test,spec}.{js,ts}"

---@return table<string, string>
local getEnv = function()
	return {}
end

---@type fun(position_path: string): string?
local getCwd = function(position_path)
	return adapter.root(position_path)
end

setmetatable(adapter, {
	---@param opts neotest.AdapterOptions
	__call = function(_, opts)
		if vim.is_callable(opts.env) then
			getEnv = opts.env --[[@as fun():table<string>]]
		elseif opts.env then
			getEnv = function()
				return opts.env
			end
		end

		if vim.is_callable(opts.cwd) then
			getCwd = opts.cwd --[[@as fun(string):string]]
		elseif opts.cwd then
			getCwd = function()
				return opts.cwd --[[@as string]]
			end
		end

		if vim.is_callable(opts.filter_dir) then
			adapter.filter_dir = opts.filter_dir
		end

		if vim.is_callable(opts.is_test_file) then
			adapter.is_test_file = opts.is_test_file
		end

		return adapter
	end,
})

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function adapter.root(dir)
	return lib.files.match_root_pattern("package.json")(dir)
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
---@diagnostic disable-next-line: unused-local
function adapter.filter_dir(name, rel_path, root)
	return name ~= "node_modules"
end

function adapter.has_node_test_imports(file_path)
	local file = io.open(file_path, "r")
	if not file then
		return false
	end
	local content = file:read(2000)
	file:close()
	return content
		and (content:match("from%s+[\"']node:test[\"']") or content:match("require%s*%(%s*[\"']node:test[\"']%s*%)"))
end

---@async
---@param file_path string
---@return boolean
function adapter.is_test_file(file_path)
	if file_path:match(".*%.test%.[tj]s$") == nil then
		return false
	end
	return adapter.has_node_test_imports(file_path)
end

--- Tap always applies escaping to control characters to test names, so we're
--- doing the same thing. TAP itself also escapes \# and '\' itself, we don't
--- do it here, instead we're stripping that in tap parser.
---See: https://github.com/nodejs/node/blob/main/lib/internal/test_runner/reporter/tap.js
---@param str string
---@return string
local function test_name_escape(str)
	local result = str
	result = result:gsub("\b", "\\b")
	result = result:gsub("\f", "\\f")
	result = result:gsub("\t", "\\t")
	result = result:gsub("\n", "\\n")
	result = result:gsub("\r", "\\r")
	result = result:gsub("\v", "\\v")
	return result
end

---Decode a JavaScript string literal by removing quotes and unescaping
---@param js_string string The string as captured from source (with quotes)
---@return string The decoded string value
local function parse_test_name_literal(js_string)
	local ok, decoded = pcall(vim.fn.json_decode, js_string)
	if not ok then
		logger.warn("Unable to decode test name ", js_string)
		return js_string
	end
	return decoded
end

---Convert escaped test name to a re pattern that will be passed to node test
---runner to pinpoint test name
---@param test_pattern string
---@return string
local function convert_test_name_to_node_re(test_pattern)
	-- Escape special regex characters for Node.js regular expressions
	local escaped = vim.fn.escape(test_pattern, "^$*.()+?{}[]|\\-")

	-- Node TAP reporter always substitutes line breaks for '\n'. We're storing
	-- position_id exactly as node reports it, so for us here there's no way to
	-- tell literal line break and "\n" apart -- so we're matching for both.
	local re = escaped:gsub("\\\\b", "(\\b|\\\\b)")
	re = re:gsub("\\\\f", "(\\f|\\\\f)")
	re = re:gsub("\\\\t", "(\\t|\\\\t)")
	re = re:gsub("\\\\n", "(\\n|\\\\n)")
	re = re:gsub("\\\\r", "(\\r|\\\\r)")
	re = re:gsub("\\\\v", "(\\v|\\\\v)")
	return "^" .. re .. "$"
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function adapter.discover_positions(file_path)
	-- The [] alternation syntax works in treesitter, but not in neotest's
	-- parse_positions, as it moves namespace after test, and this can't be
	-- handled by neotest. We're keeping namespace queries duplicated, so they
	-- come before test results.
	--
	-- We're using (string) with a post-processing with decode_js_string for names
	-- instead of string fragment directly, because of potential presence of
	-- escape literals, which will break string into multiple fragments
	local query = [[
; -- Namespaces --
; Matches: `describe('context', () =>{})
((call_expression
  function: (identifier) @func_name (#eq? @func_name "describe")
  arguments: (arguments
    (string) @namespace.name
    (arrow_function)
  )
)) @namespace.definition
((call_expression
  function: (identifier) @func_name (#eq? @func_name "describe")
  arguments: (arguments
    (string) @namespace.name
    (function_expression)
  )
)) @namespace.definition

; Matches: `describe.only('context', () =>{})`
((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "describe")
  )
  arguments: (arguments
    (string) @namespace.name
    (arrow_function)
  )
)) @namespace.definition

((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "describe")
  )
  arguments: (arguments
    (string) @namespace.name
    (function_expression)
  )
)) @namespace.definition

; there is no .each or anything like that in node at the moment

; -- Tests --

; Matches: `test('test') / it('test')`
((call_expression
  function: (identifier) @func_name (#any-of? @func_name "it" "test")
  arguments: (arguments
    (string) @test.name
    [(arrow_function) (function_expression)]
  )
)) @test.definition

; Matches: `test.only('test') / it.only('test')`
((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "test" "it")
  )
  arguments: (arguments
    (string) @test.name
    [(arrow_function) (function_expression)]
  )
)) @test.definition
  ]]
	local positions = lib.treesitter.parse_positions(file_path, query, {
		nested_tests = true,
		require_namespaces = false,
		-- Building position_id, decoding JavaScript string literals (remove quotes and unescape)
		position_id = function(position, parents)
			if position.name then
				position.name = parse_test_name_literal(position.name)
			end

			local parts = { position.path }
			for _, parent in ipairs(parents) do
				if parent.type ~= "file" then
					table.insert(parts, parent.name)
				end
			end
			if position.type ~= "file" then
				-- for namespaces and tests we're additional replacing potential control
				-- characters, such as \n, \t, etc.
				position.name = test_name_escape(position.name)
				table.insert(parts, position.name)
			end
			return table.concat(parts, "::")
		end,
	})
	return positions
end

---@param strategy string
---@param command string[]
---@param cwd string?
---@return table?
local function get_strategy(strategy, command, cwd)
	if strategy == "dap" then
		return {
			name = "Debug Node Tests",
			type = "pwa-node",
			request = "launch",
			runtimeExecutable = "node",
			args = vim.list_slice(command, 2),
			console = "integratedTerminal",
			internalConsoleOptions = "neverOpen",
			rootPath = "${workspaceFolder}",
			cwd = cwd or "${workspaceFolder}",
		}
	end
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function adapter.build_spec(args)
	if not args.tree then
		return
	end
	local position = args.tree:data()

	local command = {
		"node",
		"--test",
		"--test-reporter",
		"tap",
	}
	if position.type == "test" or position.type == "namespace" then
		local name_pattern = convert_test_name_to_node_re(position.name)
		vim.list_extend(command, {
			"--test-name-pattern",
			name_pattern,
			-- must come after --test-name-pattern argument
			position.path,
		})
	elseif position.type == "file" then
		table.insert(command, position.path)
	elseif position.type == "dir" then
		-- TODO: this will require custom reporter for node -- extension for
		-- TAP reporter, that also gives info on locations
		assert(false, "DIR tests are not supported yet")
		table.insert(command, position.path .. "/" .. all_tests_shell_pattern)
	end

	local cwd = getCwd(position.path)
	local parser = TapParser.new(position.path)
	return {
		command = command,
		context = {
			parser = parser,
		},
		strategy = get_strategy(args.strategy, command, cwd),
		env = getEnv(),
		cwd = cwd,
		stream = function(output_stream)
			return function()
				local new_lines = output_stream()
				for _, line in ipairs(new_lines) do
					parser:parse_line(line)
				end
				return parser:get_results()
			end
		end,
	}
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(spec, result, tree)
	local parser = spec.context.parser
	assert(parser, "Unable to extract reporter parser for test results retrieval from test context")
	return parser:get_results()
end

return adapter
