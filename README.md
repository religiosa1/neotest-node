# Neotest Adapter for node test runner

[Neotest](https://github.com/nvim-neotest/neotest) adapter for [node test runner](https://nodejs.org/api/test.html).

## Installation

### Lazy

In your neotest setup (e.g. `lua/plugins/neotest.lua`)

```lua
return {
  { "nvim-neotest/neotest-plenary" },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "religios1/neotest-node"
    },
    opts = { adapters = { "neotest-node" } },
  },
}
```
