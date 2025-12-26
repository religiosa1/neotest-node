local test_tap = [[
TAP version 13
# making some noise here
# Subtest: mock suite
    # Subtest: mock failed test
    not ok 1 - mock failed test
      ---
      duration_ms: 0.547406
      type: 'test'
      location: '/home/religiosa/projects/neotest-node/tests/mock.test.js:14:2'
      failureType: 'testCodeFailure'
      error: 'Must be an int'
      code: 'ERR_TEST_FAILURE'
      name: 'TypeError'
      stack: |-
        double (/home/religiosa/projects/neotest-node/tests/mock.test.js:8:36)
        TestContext.<anonymous> (/home/religiosa/projects/neotest-node/tests/mock.test.js:15:15)
        Test.runInAsyncScope (node:async_hooks:214:14)
        Test.run (node:internal/test_runner/test:1106:25)
        Test.start (node:internal/test_runner/test:1003:17)
        node:internal/test_runner/test:1516:71
        node:internal/per_context/primordials:464:82
        new Promise (<anonymous>)
        new SafePromise (node:internal/per_context/primordials:433:3)
        node:internal/per_context/primordials:464:9
      ...
    # Subtest: mock skipped test
    ok 2 - mock skipped test # SKIP
      ---
      duration_ms: 0.117623
      type: 'test'
      ...
    # Subtest: mock passed test
    ok 3 - mock passed test
      ---
      duration_ms: 1.177788
      type: 'test'
      ...
    1..3
not ok 1 - mock suite
  ---
  duration_ms: 2.643471
  type: 'suite'
  location: '/home/religiosa/projects/neotest-node/tests/mock.test.js:13:1'
  failureType: 'subtestsFailed'
  error: '1 subtest failed'
  code: 'ERR_TEST_FAILURE'
  ...
1..1
# tests 3
# suites 1
# pass 1
# fail 1
# cancelled 0
# skipped 1
# todo 0
# duration_ms 51.655553
]]

local test_flat_tap = [[
TAP version 13
# making some noise here
# Subtest: mock failed test
not ok 1 - mock failed test
  ---
  duration_ms: 0.592131
  type: 'test'
  location: '/home/religiosa/projects/neotest-node/tests/mockFlat.test.js:13:1'
  failureType: 'testCodeFailure'
  error: 'Must be an int'
  code: 'ERR_TEST_FAILURE'
  name: 'TypeError'
  stack: |-
    double (/home/religiosa/projects/neotest-node/tests/mockFlat.test.js:8:36)
    TestContext.<anonymous> (/home/religiosa/projects/neotest-node/tests/mockFlat.test.js:14:14)
    Test.runInAsyncScope (node:async_hooks:214:14)
    Test.run (node:internal/test_runner/test:1106:25)
    Test.start (node:internal/test_runner/test:1003:17)
    startSubtestAfterBootstrap (node:internal/test_runner/harness:358:17)
  ...
# Subtest: mock skipped test
ok 2 - mock skipped test # SKIP
  ---
  duration_ms: 0.130848
  type: 'test'
  ...
# Subtest: mock passed test
ok 3 - mock passed test
  ---
  duration_ms: 1.17839
  type: 'test'
  ...
1..3
# tests 3
# suites 0
# pass 1
# fail 1
# cancelled 0
# skipped 1
# todo 0
# duration_ms 47.270872
]]

describe("TapParser", function()
	local TapParser = require("lua/neotest-node/node-tap-parser")

	it("creates a new instance with empty results (smoketest)", function()
		local parser = TapParser.new("foo", "bar")
		local results = parser:get_results()
		assert(vim.tbl_isempty(results))
	end)

	it("parses flat tests structure", function()
		local parser = TapParser("foo", "bar")
		for line in vim.gsplit(test_flat_tap, "\n") do
			parser:parse_line(line)
		end
		local results = parser:get_results()
		assert.equal(#results, 3)
		-- TODO: results comparison
	end)
end)
