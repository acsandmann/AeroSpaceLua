## AeroSpaceLua

This essentially just connects to the AeroSpace server and sends commands directly to it as opposed to going through the CLI.

### Usage

see example in [`example.lua`](example.lua)

how to import/initialize below

```lua
-- init.lua
local Aerospace = require("aerospace")
local aerospace = Aerospace.new() -- it finds socket on its own
while not aerospace:is_initialized() do
    os.execute("sleep 0.1") -- wait for connection, not the best workaround, i am not a lua professional
end

require("install.sbar")

sbar = require("sketchybar")
sbar.aerospace = aerospace
sbar.begin_config()
sbar.hotload(true)
require("constants")
require("config")
require("bar")
require("default")
require("items")

sbar.end_config()
sbar.event_loop()
```
