-- see https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua
local lib = require("neotest.lib")
local TapParser = require("neotest-node.node-tap-parser")

local NodeNeotestAdapter = { name = "neotest-node" }

local all_tests_shell_pattern = "*.{test,spec}.{js,ts}"
local test_filename_re = ".*%.test%.[tj]s$"

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param dir string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function NodeNeotestAdapter.root(dir)
	return lib.files.match_root_pattern("package.json")(dir)
end

---Filter directories when searching for test files
---@async
---@param name string Name of directory
---@param rel_path string Path to directory, relative to root
---@param root string Root directory of project
---@return boolean
---@diagnostic disable-next-line: unused-local
function NodeNeotestAdapter.filter_dir(name, rel_path, root)
	return name ~= "node_modules"
end

function NodeNeotestAdapter.has_node_test_imports(file_path)
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
function NodeNeotestAdapter.is_test_file(file_path)
	if file_path:match(test_filename_re) == nil then
		return false
	end
	return NodeNeotestAdapter.has_node_test_imports(file_path)
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function NodeNeotestAdapter.discover_positions(file_path)
	-- The [] alternation syntax works in treesitter, but not in neotest's
	-- parse_positions, as it moves namespace after test, and this can't be
	-- handled by neotest. We're keeping namespace queries duplicated, so they
	-- come before test results.
	local query = [[
; -- Namespaces --
; Matches: `describe('context', () =>{})
((call_expression
  function: (identifier) @func_name (#eq? @func_name "describe")
  arguments: (arguments
    (string (string_fragment) @namespace.name)
    (arrow_function)
  )
)) @namespace.definition
((call_expression
  function: (identifier) @func_name (#eq? @func_name "describe")
  arguments: (arguments
    (string (string_fragment) @namespace.name)
    (function_expression)
  )
)) @namespace.definition

; Matches: `describe.only('context', () =>{})`
((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "describe")
  )
  arguments: (arguments
    (string (string_fragment) @namespace.name)
    (arrow_function)
  )
)) @namespace.definition

((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "describe")
  )
  arguments: (arguments
    (string (string_fragment) @namespace.name)
    (function_expression)
  )
)) @namespace.definition

; there is no .each or anything like that in node at the moment

; -- Tests --

; Matches: `test('test') / it('test')`
((call_expression
  function: (identifier) @func_name (#any-of? @func_name "it" "test")
  arguments: (arguments
    (string (string_fragment) @test.name)
    [(arrow_function) (function_expression)]
  )
)) @test.definition

; Matches: `test.only('test') / it.only('test')`
((call_expression
  function: (member_expression
    object: (identifier) @func_name (#any-of? @func_name "test" "it")
  )
  arguments: (arguments
    (string (string_fragment) @test.name)
    [(arrow_function) (function_expression)]
  )
)) @test.definition
  ]]
	-- complaints about position_id constructor, but default is actually provided for it
	---@diagnostic disable-next-line: missing-fields
	local positions = lib.treesitter.parse_positions(file_path, query, {
		nested_tests = true,
		require_namespaces = false,
	})
	return positions
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function NodeNeotestAdapter.build_spec(args)
	if not args.tree then
		return
	end
	local position = args.tree:data()
	local cwd = NodeNeotestAdapter.root(position.path)

	local command = {
		"node",
		"--test",
		"--test-reporter",
		"tap",
	}
	if position.type == "test" or position.type == "namespace" then
		vim.list_extend(command, {
			"--test-name-pattern",
			position.name,
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

	local parser = TapParser.new(position.path)
	return {
		command = command,
		context = {
			parser = parser,
		},
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
function NodeNeotestAdapter.results(spec, result, tree)
	local parser = spec.context.parser
	assert(parser, "Unable to extract reporter parser for test results retrieval from test context")
	return parser:get_results()

	-- vim.print(g_positions)
	-- results["/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/src/emailTemplates/html.test.ts::html"] =
	-- 	{
	-- 		status = "failed",
	-- 		short = "html: passed",
	-- 		output = "/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/blah1",
	-- 	}
	-- results["/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/src/emailTemplates/html.test.ts::html::renders provided html as a string"] =
	-- 	{
	-- 		status = "failed",
	-- 		short = "failed",
	-- 		output = "/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/blah2",
	-- 		errors = {
	-- 			{
	-- 				message = "qwert dsf asd msg",
	-- 				line = 5,
	-- 				-- severity = vim.diagnostic.severity.ERROR
	-- 			},
	-- 		},
	-- 	}
	-- results["/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/src/emailTemplates/html.test.ts::html::escapes provided values"] =
	-- 	{ status = "skipped", short = "mnbv" }
	-- results["/home/religiosa/projects/blueprint-mozio/packages/blueprint-mozio-backend/src/emailTemplates/html.test.ts::html::doesn't escape raw values"] =
	-- 	{ status = "passed", short = "zxcv" }
end

return NodeNeotestAdapter
