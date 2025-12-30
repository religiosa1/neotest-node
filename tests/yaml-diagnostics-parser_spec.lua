local TEST_FILE = "/home/john/proj/src/foo.test.ts"

describe("YamlDiagnosticsParser", function()
	local YamlDiagnosticsParser = require("neotest-node.yaml-diagnostics-parser")

	it("Extracts error message from a regular error", function()
		local diagnostics = [[
      duration_ms: 0.593691
      type: 'test'
      location: '/home/john/proj/src/foo.test.ts:7:1'
      failureType: 'testCodeFailure'
      error: 'Must be an int'
      code: 'ERR_TEST_FAILURE'
      name: 'TypeError'
      stack: |-
        module.exports.double (/home/john/proj/src/mockFn.js:3:36)
        TestContext.<anonymous> (/home/john/proj/src/foo.test.ts:8:14)
        Test.runInAsyncScope (node:async_hooks:214:14)
        Test.run (node:internal/test_runner/test:1106:25)
        Test.start (node:internal/test_runner/test:1003:17)
        startSubtestAfterBootstrap (node:internal/test_runner/harness:358:17)
    ]]
		-- TODO: literal expansion
		local WANT_ERROR_MSG = "Must be an int"
		local WANT_ERROR_LINE_NUM = 7

		local parser = YamlDiagnosticsParser.new(TEST_FILE)
		for line in vim.gsplit(diagnostics, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_errors()
		assert.are.same({
			{
				message = WANT_ERROR_MSG,
				line = WANT_ERROR_LINE_NUM,
			},
		}, results)
	end)

	it("Extracts error message from assertion failure", function()
		local diagnostics = [[
      duration_ms: 0.514198
      type: 'test'
      location: '/home/john/proj/src/foo.test.ts:9:2'
      failureType: 'testCodeFailure'
      error: "'<p>Hi-- &lt;br /&gt; there!</p>' == '<p>Hi &lt;br /&gt; there!</p>'"
      code: 'ERR_ASSERTION'
      name: 'AssertionError'
      expected: '<p>Hi &lt;br /&gt; there!</p>'
      actual: '<p>Hi-- &lt;br /&gt; there!</p>'
      operator: '=='
      stack: |-
        assert.<computed> [as equal] (node:internal/test_runner/test:325:18)
        TestContext.<anonymous> (file:///home/john/proj/src/foo.test.ts:10:12)
        Test.runInAsyncScope (node:async_hooks:214:14)
        Test.run (node:internal/test_runner/test:1106:25)
        Suite.processPendingSubtests (node:internal/test_runner/test:788:18)
        Test.postRun (node:internal/test_runner/test:1235:19)
        Test.run (node:internal/test_runner/test:1163:12)
        async Promise.all (index 0)
        async Suite.run (node:internal/test_runner/test:1516:7)
        async startSubtestAfterBootstrap (node:internal/test_runner/harness:358:3)
    ]]
		-- TODO: literal expansion
		local WANT_ASSERTION_MSG = [['<p>Hi-- &lt;br /&gt; there!</p>' == '<p>Hi &lt;br /&gt; there!</p>']]
		local WANT_ASSERT_LINE_NUM = 9

		local parser = YamlDiagnosticsParser.new(TEST_FILE)
		for line in vim.gsplit(diagnostics, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_errors()
		assert.are.same({
			{
				message = WANT_ASSERTION_MSG,
				line = WANT_ASSERT_LINE_NUM,
			},
		}, results)
	end)

	it("Returns nil if no error was captured", function()
		local diagnostics = [[
  duration_ms: 0.141686
  type: 'test'
    ]]
		local parser = YamlDiagnosticsParser.new(TEST_FILE)
		for line in vim.gsplit(diagnostics, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_errors()
		assert.Nil(results)
	end)

	it("Returns just the message, if no stack trace was present at all", function()
		local diagnostics = [[
      duration_ms: 2.653306
      type: 'suite'
      location: '/home/religiosa/Projects/personal/blueprint-mozio/packages/blueprint-mozio-backend/src/emailTemplates/html.test.ts:4:1'
      failureType: 'subtestsFailed'
      error: '1 subtest failed'
      code: 'ERR_TEST_FAILURE'
    ]]
		local parser = YamlDiagnosticsParser.new(TEST_FILE)
		for line in vim.gsplit(diagnostics, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_errors()
		assert.are.same({
			{
				message = "1 subtest failed",
			},
		}, results)
	end)

	it("Returns just the message, if no line was found in the stacktrace", function()
		local diagnostics = [[
      duration_ms: 0.593691
      type: 'test'
      location: '/home/john/proj/src/foo.test.ts:7:1'
      failureType: 'testCodeFailure'
      error: 'Must be an int'
      code: 'ERR_TEST_FAILURE'
      name: 'TypeError'
      stack: |-
        module.exports.double (/home/john/proj/src/mockFn.js:3:36)
        TestContext.<anonymous> (/home/john/proj/src/MESSED_UP:8:14)
        Test.runInAsyncScope (node:async_hooks:214:14)
        Test.run (node:internal/test_runner/test:1106:25)
        Test.start (node:internal/test_runner/test:1003:17)
        startSubtestAfterBootstrap (node:internal/test_runner/harness:358:17)
    ]]
		local parser = YamlDiagnosticsParser.new(TEST_FILE)
		for line in vim.gsplit(diagnostics, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_errors()
		assert.are.same({
			{
				message = "Must be an int",
			},
		}, results)
	end)
end)
