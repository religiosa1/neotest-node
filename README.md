# Neotest Adapter for node test runner

Neovim [Neotest](https://github.com/nvim-neotest/neotest) adapter for [node test runner](https://nodejs.org/api/test.html)

Requires node 18+, for typescript support you need node v22.18.0+ (22.6.0 if you
add `--experimental-strip-types` to args)

## Features

- run node test runner tests and suites from your nvim;
- test results streaming - your results will appear in the UI one by one as
  they're processed by the node;
- detection of imports coming from
  `node:test`, so the plugin plays along nicely with your existing
  vitest/jest/bun adapter setup and doesn't trigger on foreign tests;
- DAP debugger connection;
- Typescript and JS test suites;
- environment and [global setup/teardown](https://nodejs.org/api/test.html#global-setup-and-teardown) parameters;
- output capture for you to see your console.logs and stuff run in a test;

### Not supported

- dynamic/parametrezied tests, e.g. this won't work:
  ```
  for (const arg of ["foo", "bar"]) {
    it(`smarty-pants ${arg} test`, (t) => {
      t.assert(false, "this won't work");
    });
  }
  ```

## Installation

### Lazyvim

In your neotest setup (e.g. `lua/plugins/neotest.lua`)

```lua
return {
  { "nvim-neotest/neotest-plenary" },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "religios1/neotest-node"
    },
    opts = {
      -- notice if you also mixed vitest/jest/bun in your project, this
      -- adapter must come first, otherwise the first adapter to get the file
      -- wins
      adapters = { "neotest-node" }
    },
  },
}
```

## Implementation details

### Node test detection

As I can imagine you also have vitest/jest/bun or whatever else in your
adapters, we must differentiate between node tests vs any other solution.
[jest](https://github.com/nvim-neotest/neotest-jest) and [vitest](https://github.com/marilari88/neotest-vitest) adapters check presence of their corresponding
testrunner in dependencies, while bun can check for bun lockfile.

We don't have this option, as node test runner won't be present in deps -- it
comes out of the box.

This detection must happen in `is_test_file` adapter function -- neotest passes
test execution to the first adapter matched by its is_test_file function.

So instead of inspecting package.json (which isn't required for this adapter),
if the file has the correct extension (e.g. `foo.test.ts` or `bar.spec.js`)
we're reading the first 2000 chars from the file and trying to find an import
from `node:test` with a regex (be that CJS or ESM import).

We're using regex instead of treesitter, to avoid extra overhead of parsing
every test files just to determine if we should anything with a file.

If you want to disable this functionality you can pass your custom `is_test_file`
in the adapter options in your config.
