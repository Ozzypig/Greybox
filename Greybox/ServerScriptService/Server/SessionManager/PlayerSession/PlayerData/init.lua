local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local lib = require(ReplicatedStorage:WaitForChild("lib"))
local Promise = lib.Promise
local uuid = lib.uuid

local PlayerData = {}
PlayerData.__index = PlayerData
PlayerData.DS_PLAYER_DATA = "PlayerData"
PlayerData.DS_SCOPE = nil
PlayerData.dataStore = Promise.promisify(DataStoreService.GetDataStore)(DataStoreService, PlayerData.DS_PLAYER_DATA, PlayerData.DS_SCOPE):catch(warn):expect()
PlayerData.NO_ID = -1
PlayerData.NO_UPDATE_TIME = -1
PlayerData.ERR_INTEGRITY_CHECK_FAILED = "IntegrityCheckFailed"
PlayerData.ERR_NOT_UPDATED = "NotUpdated"
PlayerData.ERR_NO_DATA_STORE = "ErrNoDataStore"
PlayerData.Keys = {
	Id = "id";
	Data = "data";
	LastUpdate = "lastUpdate";
}

function PlayerData.new(playerSession)
	local self = setmetatable({
		playerSession = playerSession;
		id = PlayerData.NO_ID;
		lastUpdate = PlayerData.NO_UPDATE_TIME;
	}, PlayerData)
	self._updateAsyncFunc = function (...)
		return self:updateAsync(...)
	end
	self._serializeCallbacks = {}
	self._deserializeCallbacks = {}
	return self
end

function PlayerData:destroy()
	self._updateAsyncFunc = nil
	self.playerSession = nil
	self._lastPayload = nil
	self._lastKeyInfo = nil
	self._serializeCallbacks = nil
	self._deserializeCallbacks = nil
end

function PlayerData:getKey()
	return self.playerSession.player.UserId
end

function PlayerData:getDataStore()
	return self.dataStore
end

function PlayerData:addDataCallback(key, serializeFunc, deserializeFunc)
	assert(typeof(key) == "string", "string key expected")
	assert(typeof(serializeFunc) == "function", "function serializeFunc expected")
	assert(typeof(deserializeFunc) == "function", "function deserializeFunc expected")
	self._serializeCallbacks[key] = serializeFunc
	self._deserializeCallbacks[key] = deserializeFunc
end

function PlayerData:getId()
	return self.id
end

function PlayerData:_setId(newId)
	print("PlayerData:_setId", newId)
	self.id = newId
end

function PlayerData:getLastUpdate()
	return self.lastUpdate
end

function PlayerData:_setLastUpdate(newLastUpdate)
	print("PlayerData:_setLastUpdate", newLastUpdate)
	self.lastUpdate = newLastUpdate
end

function PlayerData:saveAsync()
	local integrityCheck
	local key = self:getKey()
	local dataStore = self:getDataStore()
	if not dataStore then
		return Promise.reject(PlayerData.ERR_NO_DATA_STORE)
	end
	return Promise.promisify(dataStore.UpdateAsync)(dataStore, key, function (oldPayload, oldKeyInfo)
		self._lastPayload = oldPayload
		self._lastKeyInfo = oldKeyInfo
		
		local newPayload = self:serialize()

		integrityCheck = self:checkIntegrity(oldPayload)
		if integrityCheck then
			print("updateAsync", newPayload)
			return newPayload, { self.playerSession.player.UserId }, nil
		else
			print("integrity check failed!")
			-- Don't update
			return nil, nil, nil
		end
	end):andThen(function (newPayload, newKeyInfo)
		self._lastPayload = newPayload
		self._lastKeyInfo = newKeyInfo

		if integrityCheck then
			if newPayload then
				local id = newPayload[PlayerData.Keys.Id]
				self:_setId(id)
				local lastUpdate = newPayload[PlayerData.Keys.LastUpdate]
				self:_setLastUpdate(lastUpdate)
				local data = newPayload[PlayerData.Keys.Data]
				return Promise.resolve(data)
			else
				return Promise.reject(PlayerData.ERR_NOT_UPDATED)
			end
		else
			return Promise.reject(PlayerData.ERR_INTEGRITY_CHECK_FAILED)
		end
	end)
end

function PlayerData:checkIntegrity(payload)
	if self.id == PlayerData.NO_ID then return true end
	if payload == nil then return true end
	if typeof(payload) ~= "table" then return true end
	
	-- Ensure the data did not change since the last time it was loaded
	if self.id ~= PlayerData.NO_ID and typeof(payload[PlayerData.Keys.Id]) ~= "nil" and self.id ~= payload[PlayerData.Keys.Id] then
		return false
	end
	if self.lastUpdate ~= PlayerData.NO_UPDATE_TIME and typeof(payload[PlayerData.Keys.LastUpdate]) ~= "nil" and self.lastUpdate ~= payload[PlayerData.Keys.LastUpdate] then
		return false
	end
	return true
end

function PlayerData:getUpdateTime()
	return os.time()
end

function PlayerData:serialize()
	local id = uuid()
	local data = {}
	local updateTime = self:getUpdateTime()
	for key, serializeFunc in pairs(self._serializeCallbacks) do
		data[key] = serializeFunc(self, id)
	end
	return {
		[PlayerData.Keys.Id] = id;
		[PlayerData.Keys.Data] = data;
		[PlayerData.Keys.LastUpdate] = updateTime;
	}
end

function PlayerData:loadAsync()
	local key = self:getKey()
	local dataStore = self:getDataStore()
	if not dataStore then
		return Promise.reject(PlayerData.ERR_NO_DATA_STORE)
	end
	return Promise.promisify(dataStore.GetAsync)(dataStore, key):andThen(function (payload, keyInfo)
		self._lastPayload = payload
		self._lastKeyInfo = keyInfo
		return self:deserializeAsync(payload)
	end)
end

function PlayerData:deserializeAsync(payload)
	if payload == nil then return end
	assert(typeof(payload) == "table", "payload must be table or nil, is " .. typeof(payload) .. ": " .. tostring(payload))

	local id = payload[PlayerData.Keys.Id] or PlayerData.NO_ID
	assert(typeof(id) == "string", PlayerData.Keys.Id .. " must be string, is " .. typeof(id))
	self:_setId(id)

	local lastUpdate = payload[PlayerData.Keys.LastUpdate] or PlayerData.NO_UPDATE_TIME
	assert(typeof(lastUpdate) == "number", PlayerData.Keys.LastUpdate .. " must be number, is " .. typeof(lastUpdate))
	self:_setLastUpdate(lastUpdate)
	
	local data = payload[PlayerData.Keys.Data]
	assert(typeof(data) == "table", PlayerData.Keys.Data .. " must be table, is " .. typeof(data) .. ": " .. tostring(data))

	local promises = {}
	for key, value in pairs(data) do
		local deserializeFunc = self._deserializeCallbacks[key]
		if deserializeFunc then
			table.insert(promises, Promise.promisify(deserializeFunc)(self, value))
		end
	end
	return Promise.allSettled(promises)
end

return PlayerData
