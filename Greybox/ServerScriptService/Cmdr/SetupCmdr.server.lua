local folder = script.Parent

local Cmdr = require(folder.Cmdr)
Cmdr:RegisterDefaultCommands()
Cmdr:RegisterCommandsIn(folder.Commands)
Cmdr:RegisterTypesIn(folder.Types)
Cmdr:RegisterHooksIn(folder.Hooks)
