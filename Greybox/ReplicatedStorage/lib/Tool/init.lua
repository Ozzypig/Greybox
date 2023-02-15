local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Tool = {}
Tool.__index = Tool
Tool.activationCooldown = 0.25
Tool.IS_CLIENT = RunService:IsClient()
Tool.IS_SERVER = RunService:IsServer()
Tool.onlyProcessOwnerRequests = true
Tool.REJECTED = "Rejected"

function Tool.new(tool)
	assert(tool and typeof(tool) == "Instance" and tool:IsA("Tool"), "Tool expected")
	local self = setmetatable({
		tool = tool;
	}, Tool)

	self._equippedConn = tool.Equipped:Connect(function (...)
		return self:onEquipped(...)
	end)
	self._unequippedConn = tool.Unequipped:Connect(function (...)
		return self:onUnequipped(...)
	end)
	self._activatedConn = tool.Activated:Connect(function (...)
		return self:onActivated(...)
	end)
	self._reenableFunc = function ()
		self.tool.Enabled = true
	end
	
	if self:isEquipped() then
		self:onEquipped(Players.LocalPlayer and Players.LocalPlayer:GetMouse())
	end
	
	return self
end

function Tool:cleanup()
	if RunService:IsServer() then
		if self.remoteFunction then
			self.remoteFunction:Destroy()
			self.remoteFunction = nil
		end
		if self.remoteEvent then
			self.remoteEvent:Destroy()
			self.remoteEvent = nil
		end
	elseif RunService:IsClient() then
		self.remoteFunction = nil
		self.remoteEvent = nil
	end
	if self._activatedConn then
		self._activatedConn:Disconnect()
		self._activatedConn = nil
	end
	if self._clientEventConn then
		self._clientEventConn:Disconnect()
		self.self._clientEventConn = nil
	end
end

function Tool:isEquipped()
	return typeof(self:getHumanoid()) ~= "nil" 
end

-- Various getters

function Tool:getHumanoid()
	return self.tool.Parent:FindFirstChildWhichIsA("Humanoid")
end

function Tool:getTargetPoint()
	local human = self:getHumanoid()
	return human and human.TargetPoint
end

function Tool:getPlayer()
	return Players:GetPlayerFromCharacter(self.tool.Parent)
end

function Tool:getActivationCooldown()
	return self.activationCooldown
end

function Tool:isOnCooldown()
	return self._lastActivation and workspace.DistributedGameTime - self._lastActivation < self:getActivationCooldown()
end

-- Callbacks

function Tool:onActivated()
	if not self.tool.Enabled then return end
	if self:isOnCooldown() then return end
	self.tool.Enabled = false
	self._lastActivation = workspace.DistributedGameTime
	self:activate()
	delay(self.activationCooldown, self._reenableFunc)
end

function Tool:onEquipped()
	-- Stub
end

function Tool:onUnequipped()
	-- Stub
end

function Tool:activate()
	warn("Tool:activate is abstract")
end

-- Networking

function Tool:initNetworking()
	if RunService:IsServer() then
		if not self.remoteFunction then
			self.remoteFunction = Instance.new("RemoteFunction")
			self.remoteFunction.OnServerInvoke = function (...)
				return self:processRequest(...)
			end
			self.remoteFunction.Parent = self.tool
		end
		if not self.remoteEvent then
			self.remoteEvent = Instance.new("RemoteEvent") 
			self.remoteEvent.Parent = self.tool
		end
	elseif RunService:IsClient() then
		if not self.remoteFunction then
			self.remoteFunction = self.tool:WaitForChild("RemoteFunction")
		end
		if not self.remoteEvent then
			self.remoteEvent = self.tool:WaitForChild("RemoteEvent")
			self._clientEventConn = self.remoteEvent.OnClientEvent:Connect(function (...)
				return self:onDataReceived(...)
			end)
		end
	end
end

-- Networking requests are client -> server commands

function Tool.addRequestHandler(cls, command, func)
	if not cls.requestHandlers then
		cls.requestHandlers = {}
	end
	cls.requestHandlers[command] = func
end

function Tool:processRequest(requester, command, ...)
	--warn("Tool:processRequest not implemented")
	if self.onlyProcessOwnerRequests and requester ~= self:getPlayer() then
		warn("Request rejected")
		return Tool.REJECTED
	end
	local requestHandler = self.requestHandlers and self.requestHandlers[command]
	assert(type(requestHandler) ~= "nil", "No request handler for command: " .. tostring(command))
	return requestHandler(self, ...)
end

function Tool:sendRequest(...)
	assert(RunService:IsClient(), "Not a client")
	return self.remoteFunction:InvokeServer(...)
end

-- Networking data is server -> client events

function Tool.addDataHandler(cls, event, func)
	if not cls.dataHandlers then
		cls.dataHandlers = {}
	end
	cls.dataHandlers[event] = func
end

function Tool:onDataReceived(event, ...)
	local dataHandler = self.dataHandlers and self.dataHandlers[event]
	assert(type(dataHandler) ~= "nil", "No data handler for event: " .. tostring(event))
	return dataHandler(self, ...)
end

function Tool:sendData(...)
	assert(RunService:IsServer(), "Not a server")
	local player = self:getPlayer()
	if player then
		self.remoteEvent:FireClient(player, ...)
	else
		warn("Tool:sendData called but no player found")
	end
end

-- Various useful bits

function Tool:swing()
	local anim = Instance.new("StringValue")
	anim.Name = "toolanim"
	anim.Value = "Slash"
	anim.Parent = self.tool
end

function Tool:facePoint(point)
	local pp = self.tool.Parent.PrimaryPart
	pp.CFrame = CFrame.new(pp.CFrame.Position, point * Vector3.new(1, 0, 1) + Vector3.new(0, pp.CFrame.Position.Y, 0))
end

return Tool
