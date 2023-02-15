local TYPE = "fruit"
local TYPE_NAME = "Fruit"
local VALUES = {"apple", "orange", "banana", "kiwi", "strawberry", "grape"}

local config = script

return function (registry)
	registry:RegisterType(TYPE, registry.Cmdr.Util.MakeEnumType(TYPE_NAME, VALUES))
end
