local Players = game:GetService("Players")

local PlayerSession = require(script:WaitForChild("PlayerSession"))

local SessionManager = {}
SessionManager.__index = SessionManager
SessionManager.KICK_MESSAGE_SESSION = "Failed to start your session. Please try again."
SessionManager.KICK_MESSAGE_LOAD_FAILED = "Your data failed to load! Please try again."

function SessionManager.new(server)
	local self = setmetatable({
		server = server;
		sessions = {};
		stopSessionPromises = {};
	}, SessionManager)

	self._playerRemoving = Players.PlayerRemoving:Connect(function (...)
		return self:onPlayerRemoving(...)
	end)

	return self
end

function SessionManager:destroy()
	if self._playerAddedConn then
		self._playerAddedConn:Disconnect()
		self._playerAddedConn = nil
	end
	self._playerRemoving:Disconnect()
	self._playerRemoving = nil
	for player, session in pairs(self.sessions) do
		session:destroy()
		self.sessions[player] = nil
	end
	self.stopSessionPromises = nil
	self.sessions = nil
	self.server = nil
end

function SessionManager:getSession(player)
	return self.sessions[player]
end

function SessionManager:hasSession(player)
	return self:getSession(player) ~= nil
end

function SessionManager:startSessionsAsync()
	if not self._playerAddedConn then
		self._playerAddedConn = Players.PlayerAdded:Connect(function (...)
			return self:onPlayerAdded(...)
		end)
	end
	local promises = {}
	for _, player in pairs(Players:GetPlayers()) do
		if not self:hasSession(player) then
			table.insert(promises, self:startSessionAsync(player))
		end
	end
	return promises
end

function SessionManager:stopSessions()
	local promises = {}
	for player, _ in pairs(self.sessions) do
		table.insert(promises, self:stopSessionAsync(player))
	end
	for _, promise in pairs(self.stopSessionPromises) do
		table.insert(promises, promise)
	end
	return promises
end

function SessionManager:startSessionAsync(player)
	local session = PlayerSession.new(self, player)
	self.sessions[player] = session
	return session:startAsync():catch(function (err)
		warn("SessionManager:startSessionAsync failed to start", player, tostring(err))
		local kickReason = SessionManager.KICK_MESSAGE_SESSION
		if err == PlayerSession.ERR_DATA_LOAD_FAILED then
			kickReason = SessionManager.KICK_MESSAGE_LOAD_FAILED
		end
		return self:stopSessionAsync(player, true, kickReason)
	end)
end

function SessionManager:stopSessionAsync(player, kick, kickReason)
	assert(self:hasSession(player), "No session for " .. player.Name)
	local session = self.sessions[player]
	self.sessions[player] = nil
	return session:stopAsync():andThen(function ()
		session:destroy()
		session = nil
		if kick then
			player:Kick(kickReason)
		end
	end)
end

function SessionManager:onPlayerAdded(player)
	if not self:hasSession(player) then
		self:startSessionAsync(player)
	end
end

function SessionManager:onPlayerRemoving(player)
	if self:hasSession(player) then
		local promise = self:stopSessionAsync(player, false, nil)
		table.insert(self.stopSessionPromises, promise)
		promise:finally(function ()
			local idx = table.find(self.stopSessionPromises, promise)
			if idx then
				table.remove(self.stopSessionPromises, idx)
			end
		end)
	end
end

return SessionManager
