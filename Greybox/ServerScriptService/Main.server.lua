local ServerScriptService = game:GetService("ServerScriptService")
local Server = require(ServerScriptService:WaitForChild("Server"))

local server

local function onClose()
	print("onClose")
	server:onClose()
	server:destroy()
	server = nil
end

local function main()
	server = Server.new()
	game:BindToClose(onClose)
	server:main()
end

main()
