const { describe, it, suite } = require("node:test");
const { double } = require("./mockFn.js");

suite("top level desc", () => {
	describe("nested desc", () => {
		it("mock failed test", (t) => {
			const got = double("qwerty");
			t.assert.equal(got, 4);
		});

		it.skip("mock skipped test", (t) => {
			const got = double("qwerty");
			t.assert.equal(got, 4);
		});
	});

	describe("nested desc2", () => {
		it.skip("mock skipped test", (t) => {
			const got = double("qwerty");
			t.assert.equal(got, 4);
		});
	});
	it("mock passed test", (t) => {
		const got = double(2);
		t.assert.equal(got, 4);
	});
});
it("mock passed test", (t) => {
	const got = double(2);
	t.assert.equal(got, 4);
});
