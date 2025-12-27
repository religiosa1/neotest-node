# Neotest Adapter for node test runner

Neovim [Neotest](https://github.com/nvim-neotest/neotest) adapter for [node test runner](https://nodejs.org/api/test.html)

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
