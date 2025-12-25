-- see https://github.com/nvim-neotest/neotest/blob/master/lua/neotest/adapters/interface.lua
local lib = require("neotest.lib")
local async = require("neotest.async")

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

---@async
---@param file_path string
---@return boolean
function NodeNeotestAdapter.is_test_file(file_path)
	if string.match(file_path, test_filename_re) == nil then
		return false
	end
	-- TODO: filter out files not having describe/it/test imports from node:test
	return true
end

---Given a file path, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function NodeNeotestAdapter.discover_positions(file_path)
	-- for some reason [] syntax doesn't work for describe arguments, so we just
	-- entering describe blocks twice once for arrow_function and once for function_expression
	-- TODO: figure out why
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
	local results_path = async.fn.tempname()
	if not args.tree then
		return
	end
	local position = args.tree:data()
	local cwd = assert(NodeNeotestAdapter.root(position.path), "could not locate root directory of " .. position.path)

	local command = { "node", "--test", "--test-reporter", "tap" }
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
		table.insert(command, all_tests_shell_pattern)
	end
	return {
		command = command,
		context = {
			results_path = results_path,
		},
		cwd = cwd,
	}
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function NodeNeotestAdapter.results(spec, result, tree)
	-- TODO:
	return {}
end

return NodeNeotestAdapter
