const { describe, it } = require("node:test");

// Launch this test with
// node --test --test-reporter=tap **/*.test.js

/** mock function to call */
function double(val) {
	if (!Number.isInteger(val)) throw new TypeError("Must be an int");
	console.log("making some noise here");
	return val * 2;
}

describe("mock suite", () => {
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
});
