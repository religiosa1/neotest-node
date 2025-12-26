describe("TapParser", function()
	local TapParser = require("lua/neotest-node/node-tap-parser")

	it("creates a new instance with filename (smoketest)", function()
		local parser = TapParser.new("test.spec.js")

		assert.equal("test.spec.js", parser.filename)
	end)
end)
