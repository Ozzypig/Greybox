local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer

local Client = require(ReplicatedStorage:WaitForChild("Client"))

local function main()
	local client = Client.new(player)
	client:main()
end

main()
