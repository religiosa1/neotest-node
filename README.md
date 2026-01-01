# Neotest Adapter for node test runner

Neovim [Neotest](https://github.com/nvim-neotest/neotest) adapter for [node test runner](https://nodejs.org/api/test.html)

https://github.com/user-attachments/assets/e492aba8-41f8-4e1d-9306-39f785b3d742

This isn't for running jest or vitest tests, but node built-in test runner tests
(but it will play along nicely if you have neotest-vitest or neotest-jest).

Requires node 18+, for typescript support you need node v22.18.0+ (22.6.0 if you
add `--experimental-strip-types` to args)

## Features

- run node test runner tests and suites from your nvim;
- test results streaming - your results will appear in the UI one by one as
  they're processed by the node;
- [detection](#node-test-detection) of imports coming from
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
- template strings and any kind of string manipulation in test/suite names,
  tests must be statically analyzable
- import renames of it/test/describe/suite -- why would you do that?..

## Installation

### Lazyvim

In your neotest setup (e.g. `lua/plugins/neotest.lua`)

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "religios1/neotest-node"
    },
    opts = {
      -- notice if you also mixed vitest/jest/bun tests in your project, this
      -- adapter most likely must come last, otherwise other adapters will
      -- intercept the test file
      adapters = { "neotest-node" }
    },
  },
}
```

### Configuration options (and their default values)

Default values are provided for the reference, you don't need to copy them.

```lua
return {
  {
    "nvim-neotest/neotest",
    dependencies = {
      "religios1/neotest-node"
    },
    opts = {
      adapters = {
        ["neotest-node"] = {
          ---Additional environment options
          ---@type table<string, string> | fun(): table<string, string>
          env = function()
            return {}
          end,
          ---Command (`node --test`) current working dir
          ---@type string | fun(position_path: string): string?
          cwd = function(position_path)
            local lib = require("neotest.lib")
            return lib.files.match_root_pattern("package.json")(position_path)
          end,
          ---Filtering out dirs from tests detection
          ---@type fun(name: string, rel_path: string, root: string): boolean
          filter_dir = function (name, rel_path, root)
            return name ~= "node_modules"
          end,
          ---Is file with given path a node test runner test file?
          ---@type fun(file_path: string): boolean
          is_test_file = function (file_path)
          	if file_path:match(".*%.test%.[cm]?[tj]sx?$") == nil
              and file_path:match(".*%.spec%.[cm]?[tj]sx?$") == nil then
              return false
            end
            local util = require("neotest-node.util")
            return util.has_node_test_imports(file_path)
          end,
          ---Command (`node --test`) additional arguments
          ---@type string[] | fun(args: neotest.RunArgs): string[]
          args = {},
        }
      },
    },
  },
}
```

## Implementation details

Plugin is running `node --test --test-reporter tap` for the selected file/
test pattern, and then parses node test runner [TAP](https://testanything.org/)
output to report results and capture potential error messages + error lines.

### Node test detection

As I can imagine you also have vitest/jest/bun or whatever else in your
adapters, we must differentiate between node tests vs any other solution.
[jest](https://github.com/nvim-neotest/neotest-jest) and [vitest](https://github.com/marilari88/neotest-vitest) adapters check presence of their corresponding
testrunner in dependencies, while bun can check for bun lockfile.

We don't have this option, as node test runner won't be present in deps -- it
comes out of the box.

So instead of inspecting package.json (which isn't required for this adapter),
if the file has the correct extension (e.g. `foo.test.ts` or `bar.spec.js`)
we're reading the first 2000 chars from the file and trying to find an import
from `node:test` with a regex (be that CJS or ESM import).

We're using regex instead of treesitter, to avoid extra overhead of parsing
every test files just to determine if we should anything with a file.

This detection must happen in `is_test_file` adapter function -- neotest passes
test execution to the first adapter matched by its is_test_file function.
Iteration over adapters [is performed](https://github.com/nvim-neotest/neotest/blob/deadfb1af5ce458742671ad3a013acb9a6b41178/lua/neotest/client/init.lua#L340)
with `pairs()` call over object, so order of adapters matter but not guaranteed.
Most likely neotest-node must come last in your adapters list. If you still
experience problems with adapter order matching, you can try explicitly
checking in your other adapters for a node test with

```lua
require("neotest-node.util").has_node_test_imports(file_path)
```

If you want to disable this functionality you can pass your custom `is_test_file`
in the adapter options in your config, e.g.:

```lua
-- opts in config:
{
  is_test_file = function (file_path)
    return file_path:match(".*%.test%.[cm]?[tj]sx?$") ~= nil
  end
}
```

## Local Development

### Running Tests

For running tests you need a neovim setup and node 20+ available in your path.

To run the whole test suite:

```sh
./scripts/test.sh
```

You can launch a specific unit-test by:

```sh
./scripts/test.sh tests/yaml-diagnostics-parser_spec.lua
```

On the initial launch script will retrieve its deps by cloning the corresponding
github repos into `.testsdep` folder.

## License

neotest-node is MIT licensed.
