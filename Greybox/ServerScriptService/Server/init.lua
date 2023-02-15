local SessionManager = require(script:WaitForChild("SessionManager"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lib = require(ReplicatedStorage:WaitForChild("lib"))

local Promise = lib.Promise

local Server = {}
Server.__index = Server

function Server.new()
	local self = setmetatable({
		closing = false;
	}, Server)
	self.sessionManager = SessionManager.new(self)

	return self
end

function Server:destroy()
	self.closing = nil
	self.sessionManager:destroy()
	self.sessionManager = nil
end

function Server:main()
	self:initCmdr()
	self.sessionManager:startSessionsAsync()
end

do
	local cmdrFolder = script:WaitForChild("Cmdr")
	local Cmdr = require(cmdrFolder:WaitForChild("Cmdr"))
	local cmdrCommands = cmdrFolder:WaitForChild("Commands")
	local cmdrTypes = cmdrFolder:WaitForChild("Types")
	local cmdrHooks = cmdrFolder:WaitForChild("Hooks")

	function Server:initCmdr()
		Cmdr:RegisterDefaultCommands()
		Cmdr:RegisterCommandsIn(cmdrCommands)
		Cmdr:RegisterTypesIn(cmdrTypes)
		Cmdr:RegisterHooksIn(cmdrHooks)
	end
end

function Server:onClose()
	self.closing = true
	local promise = Promise.allSettled(self.sessionManager:stopSessions())
	promise:catch(warn)
	promise:await()
end

return Server
