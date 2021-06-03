local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayerData = require(script.Parent.PlayerData)

local ThreadPool = require(script.ThreadPool)
local Settings = require(script.Settings)

local PlayerDataLoader = {}
PlayerDataLoader.__index = PlayerDataLoader
PlayerDataLoader.PlayerDataClass = PlayerData
PlayerDataLoader.DEBUG_MODE = true

function PlayerDataLoader.new(dataStore)
	assert(typeof(dataStore) == "nil" or typeof(dataStore) == "Instance" and dataStore:IsA("GlobalDataStore"), "GlobalDataStore or nil expected, got " .. typeof(dataStore))
	if not dataStore then
		warn("PlayerDataLoader instantiated without DataStore - are DataStores unavailable?")
	end
	local self = setmetatable({
		_dataStore = dataStore;
		_playerDatas = {};
		_autoLoad = false;
		_dataStoreThreadPool = ThreadPool.new();
		_boundToClose = false;
		_settings = Settings.new();
		_dataModules = {};
	}, PlayerDataLoader)
	self._playerAddedConn = Players.PlayerAdded:connect(function (...) return self:_onPlayerAdded(...) end)
	self._playerRemovingConn = Players.PlayerRemoving:connect(function (...) return self:_onPlayerRemoving(...) end)
	self._onCloseFunc = function (...) return self:onClose(...) end
	return self
end

function PlayerDataLoader:print(...)
	if self.DEBUG_MODE then print(...) end
end

function PlayerDataLoader:warn(...)
	warn(...)
end

function PlayerDataLoader:cleanup()
	if self:isLoading() then self:stopLoading() end
	for player, playerData in pairs(self._playerDatas) do
		playerData:cleanup()
	end
	self._playerDatas = nil
	if self._playerAddedConn then
		self._playerAddedConn:disconnect()
		self._playerAddedConn = nil
	end
	if self._playerRemovingConn then
		self._playerRemovingConn:Disconnect()
		self._playerRemovingConn = nil
	end
	self._dataModules = nil
end

function PlayerDataLoader:getPlayerDataClass()
	return self.PlayerDataClass
end

function PlayerDataLoader:getDataStore()
	return self._dataStore
end

function PlayerDataLoader:getSettings()
	return self._settings
end

function PlayerDataLoader:isAutoLoading()
	return self._autoLoad
end

function PlayerDataLoader:_eachDataModule(func)
	for key, dataModule in pairs(self._dataModules) do
		func(dataModule)
	end
end

function PlayerDataLoader:_initializeDataModules(player)
	self:_eachDataModule(function (dataModule)
		if dataModule["initialize"] then
			dataModule["initialize"](player)
		end
	end)
end

function PlayerDataLoader:_serializeDataModules(player)
	local serializedData = {}
	self:_eachDataModule(function (dataModule)
		local retVal = dataModule["serialize"](player)
		if type(retVal) == "nil" then
			warn("Data Module returned nil during serialization")
		end
		serializedData[dataModule["key"]] = retVal
	end)
	return serializedData
end

function PlayerDataLoader:_deserializeDataModules(player, payload)
	self:_eachDataModule(function (dataModule)
		dataModule["deserialize"](player, payload[dataModule["key"]]) 
	end)
end

function PlayerDataLoader:addDataModule(dataModule)
	assert(type(dataModule) == "table")
	assert(type(dataModule["key"]) == "string", "DataModule requires string \"key\"")
	assert(type(dataModule["serialize"]) == "function", "DataModule requires function \"serialize\"")
	assert(type(dataModule["deserialize"]) == "function", "DataModule requires function \"deserialize\"")
	self._dataModules[dataModule["key"]] = dataModule
end

function PlayerDataLoader:newPlayerData(player)
	assert(typeof(player) == "Instance" and player:IsA("Player") and player.Parent, "Player expected")
	return self:getPlayerDataClass().new(self, player)
end

function PlayerDataLoader:getPlayerData(player)
	return self._playerDatas[player]
end

function PlayerDataLoader:onNuked(player)
	player:Kick(self:getSettings():getNukeMessage())
end

function PlayerDataLoader:initPlayerData(player, tryToLoad)
	local playerData = self:getPlayerData(player) or self:newPlayerData(player)
	self._playerDatas[player] = playerData
	
	if tryToLoad then
		local loadSuccess, loadResult = playerData:tryLoad()
		print("tryLoad", loadSuccess, loadResult)
		if not loadSuccess then
			if not RunService:IsStudio() then
				player:Kick(self:getSettings():getLoadFailedMessage())
			else
				warn(("Data load failed (%s), initializing for studio"):format(loadResult))
				playerData:initialize()
			end
		end
	end
	return playerData
end

function PlayerDataLoader:nuke(player)
	local playerData = self._playerDatas[player]
	if not playerData then return end
	self._playerDatas[player] = nil
	
	local success, reason = self._dataStoreThreadPool:wrap(playerData.tryNuke, playerData)
	if success then
		playerData:cleanup()
		playerData = nil
		self:onNuked(player)
		playerData = self:initPlayerData(player, false)
		playerData:init()
		return true
	else
		self:warn(("Nuke for %s (%d) failed: %s"):format(player.Name, player.UserId, reason or "Unknown reason"))
		self._playerDatas[player] = playerData
		return false, reason
	end
end

function PlayerDataLoader:_onPlayerAdded(player)
	if not self:isAutoLoading() then return end
	self:initPlayerData(player, true)
end

function PlayerDataLoader:_onPlayerRemoving(player)
	local playerData = self._playerDatas[player]
	if not playerData then return end
	self._playerDatas[player] = nil
	playerData:cleanup()
	playerData = nil
end

function PlayerDataLoader:startAutoLoading(ignoreExistingPlayers)
	assert(not self:isAutoLoading(), "Already loading")
	self._autoLoad = true
	if not ignoreExistingPlayers then
		for _, player in pairs(Players:GetPlayers()) do
			self:_onPlayerAdded(player)
		end
	end
end

function PlayerDataLoader:stopAutoLoading()
	assert(self:isAutoLoading(), "Not loading")
	self._autoLoad = false
end

function PlayerDataLoader:onClose()
	if self:isAutoLoading() then self:stopAutoLoading() end
	for player, playerData in pairs(self._playerDatas) do
		-- Remove from table, save, cleanup
		self._playerDatas[player] = nil
		self._dataStoreThreadPool:wrap(playerData.trySave, playerData)
		playerData:cleanup()
	end
	-- Ensure there is nothing saving so the game doesn't end early
	self._dataStoreThreadPool:wait()
end

function PlayerDataLoader:bindToClose()
	assert(not self._boundToClose, "Already bound to close")
	self._boundToClose = true
	game:BindToClose(self._onCloseFunc)
end

return PlayerDataLoader
