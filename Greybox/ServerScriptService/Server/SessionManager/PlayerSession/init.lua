local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lib = require(ReplicatedStorage:WaitForChild("lib"))
local Promise = lib.Promise

local PlayerData = require(script:WaitForChild("PlayerData"))

local PlayerSession = {}
PlayerSession.__index = PlayerSession
PlayerSession.ERR_DATA_LOAD_FAILED = "ErrDataLoadFailed"

function PlayerSession.new(manager, player)
	local self = setmetatable({
		manager = manager;
		player = player;
		active = false;
	}, PlayerSession)
	self.playerData = PlayerData.new(self);
	return self
end

function PlayerSession:destroy()
	self.playerData:destroy()
	self.playerData = nil
	self.active = nil
	self.player = nil
	self.manager = nil
end

function PlayerSession:isActive()
	return self.active
end

function PlayerSession:startAsync()
	assert(not self.active, "PlayerSession already active")
	self.active = true
	return self.playerData:loadAsync():catch(function (err)
		warn("PlayerData:loadAsync rejected", tostring(err))
		return Promise.reject(PlayerSession.ERR_DATA_LOAD_FAILED)
	end)
end

function PlayerSession:stopAsync()
	assert(self.active, "PlayerSession not active")
	self.active = false
	return self.playerData:saveAsync():catch(function (err)
		warn("PlayerSession:stopAsync rejected:\n" .. tostring(err))
	end)
end

return PlayerSession
