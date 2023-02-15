local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lib = require(ReplicatedStorage:WaitForChild("lib"))

local Promise = lib.Promise

local UI = require(script:WaitForChild("UI"))

local Client = {}
Client.__index = Client

Client.cmdrClientModulePromise = Promise.promisify(ReplicatedStorage.WaitForChild)(ReplicatedStorage, "CmdrClient")
Client.cmdrClientPromise = Client.cmdrClientModulePromise:andThen(function (cmdrClientModule)
	return Promise.resolve(require(cmdrClientModule))
end)

function Client.new(player)
	assert(typeof(player) == "Instance" and player:IsA("Player"), "Player expected")
	local self = setmetatable({
		player = player;
		
	}, Client)

	self.playerModule = require(self.player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	self.ui = UI.new(self, self.player:WaitForChild("PlayerGui"))

	self.cmdrClientPromise:andThen(function (cmdrClient)
		self.cmdrClient = cmdrClient
		self:initCmdr()
	end)

	return self
end

function Client:main()
	self.ui:main()
end

function Client:initCmdr()
	self.cmdrClient:SetActivationKeys({ Enum.KeyCode.F2 })
end

function Client:destroy()
	self.playerModule = nil
	self.ui:destroy()
	self.ui = nil
end

return Client
