const { it } = require("node:test");
const { double } = require("./mockFn.js");

// Launch this test with
// node --test --test-reporter=tap **/*.test.js

it("contains # inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});

it("ends with whitespace ", (t) => {
	t.assert.equal(double(2), 4);
});

it("contains \\ inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});

it("contains \n inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});

it("contains fake \\n inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});

it.skip("skipped: contains # inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});

it.skip("skipped: ends with whitespace ", (t) => {
	t.assert.equal(double(2), 4);
});

it.skip("skipped: contains \\ inside of the name", (t) => {
	t.assert.equal(double(2), 4);
});
