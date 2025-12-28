const { it } = require("node:test");
const { double } = require("./mockFn.js");

// Launch this test with
// node --test --test-reporter=tap **/*.test.js

it("mock failed test", (t) => {
	const got = double("qwerty");
	t.assert.equal(got, 4);
});

it.skip("mock skipped test", (t) => {
	const got = double("qwerty");
	t.assert.equal(got, 4);
});

it("mock passed test", (t) => {
	const got = double(2);
	t.assert.equal(got, 4);
});
