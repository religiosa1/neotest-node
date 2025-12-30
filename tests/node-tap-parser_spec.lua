local test_dir = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h") .. "/js/"

-- Helper function to generate TAP output from a JS test file in the adjacent
-- Requires node.js to actually be present in your system
local function generate_tap(test_file)
	local cmd = string.format("node --test --test-reporter tap %s", test_dir .. test_file)
	local result = vim.fn.system(cmd)
	return result
end

-- Helper to split results into statuses (without errors) and errors separately
-- Returns: statuses_only, errors_by_position
local function split_results(results)
	local statuses = {}
	local errors = {}

	for position_id, result in pairs(results) do
		statuses[position_id] = { status = result.status }
		if result.errors then
			errors[position_id] = result.errors
		end
	end

	return statuses, errors
end

describe("TapParser", function()
	local TapParser = require("neotest-node.node-tap-parser")

	it("creates a new instance with empty results (smoketest)", function()
		local parser = TapParser.new("foo")
		local results = parser:get_results()
		assert(vim.tbl_isempty(results))
	end)

	it("parses flat tests structure", function()
		local test_flat_tap = generate_tap("flat.test.js")
		local parser = TapParser.new("foo")
		for line in vim.gsplit(test_flat_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		local statuses = split_results(results)
		assert.equal(3, vim.tbl_count(results))
		assert.are.same({
			["foo::mock failed test"] = { status = "failed" },
			["foo::mock skipped test"] = { status = "skipped" },
			["foo::mock passed test"] = { status = "passed" },
		}, statuses)
	end)

	it("parses suited tests structure", function()
		local test_tap = generate_tap("describe.test.js")
		local parser = TapParser.new("foo")
		for line in vim.gsplit(test_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		local statuses = split_results(results)
		assert.equal(4, vim.tbl_count(results))
		assert.are.same({
			["foo::mock suite::mock failed test"] = { status = "failed" },
			["foo::mock suite::mock skipped test"] = { status = "skipped" },
			["foo::mock suite::mock passed test"] = { status = "passed" },
			["foo::mock suite"] = { status = "failed" },
		}, statuses)
	end)

	it("parses nested tree structure", function()
		local test_nested_tap = generate_tap("nested.test.js")
		local parser = TapParser.new("foo")
		for line in vim.gsplit(test_nested_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		local statuses = split_results(results)
		assert.equal(8, vim.tbl_count(results))
		assert.are.same({
			["foo::top level desc"] = { status = "failed" },
			["foo::top level desc::nested desc"] = { status = "failed" },
			["foo::top level desc::nested desc::mock failed test"] = { status = "failed" },
			["foo::top level desc::nested desc::mock skipped test"] = { status = "skipped" },

			["foo::top level desc::nested desc2"] = { status = "passed" },
			["foo::top level desc::nested desc2::mock skipped test"] = { status = "skipped" },

			["foo::top level desc::mock passed test"] = { status = "passed" },

			["foo::mock passed test"] = { status = "passed" },
		}, statuses)
	end)

	it("parses error diagnostics for failed tests", function()
		local test_flat_tap = generate_tap("flat.test.js")
		local parser = TapParser.new("foo")
		for line in vim.gsplit(test_flat_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		local _, errors = split_results(results)

		-- Validate that the failed test has errors
		local failed_test_errors = errors["foo::mock failed test"]
		assert.is_not_nil(failed_test_errors, "Failed test should have errors")
		assert.is_table(failed_test_errors, "Errors should be a table")
		assert.is_true(#failed_test_errors > 0, "Should have at least one error")

		-- Validate error structure (without checking exact line numbers or messages)
		for _, err in ipairs(failed_test_errors) do
			assert.is_table(err, "Each error should be a table")
			assert.is_string(err.message, "Error should have a message string")
			-- Line is optional, but if present must be a number
			if err.line ~= nil then
				assert.is_number(err.line, "Error line should be a number if present")
			end
		end

		-- Verify passed/skipped tests don't have errors
		assert.is_nil(errors["foo::mock passed test"], "Passed test should not have errors")
		assert.is_nil(errors["foo::mock skipped test"], "Skipped test should not have errors")
	end)

	it("parses tests that contain weird names", function()
		local test_nested_tap = generate_tap("namingEdgeCases.test.js")
		local parser = TapParser.new("foo")
		for line in vim.gsplit(test_nested_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		assert.are.same({
			["foo::contains # inside of the name"] = { status = "passed" },
			["foo::ends with whitespace "] = { status = "passed" },
			["foo::contains \\ inside of the name"] = { status = "passed" },
			-- note that line break is escaped for internal storage
			["foo::contains \\n inside of the name"] = { status = "passed" },
			-- here it is escaped exactly the same, even it wasn't a literal \n
			["foo::contains fake \\n inside of the name"] = { status = "passed" },
			-- We're doing it twice -- because skipped tests contain a comment
			-- so in this way we can test both split lines with a comment, and just
			-- the unescaping part
			["foo::skipped: contains # inside of the name"] = { status = "skipped" },
			["foo::skipped: ends with whitespace "] = { status = "skipped" },
			["foo::skipped: contains \\ inside of the name"] = { status = "skipped" },
		}, results)
	end)
end)
