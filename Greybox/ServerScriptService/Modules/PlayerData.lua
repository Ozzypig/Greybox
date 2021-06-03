local RunService = game:GetService("RunService")

local PlayerData = {}
PlayerData.__index = PlayerData
PlayerData.DS_SCOPE = "Parakeet"
PlayerData.DS_NAME = "PlayerData"

PlayerData.DS_UNAVAILABLE = "DataStoresUnavailable"
PlayerData.DS_FAILED = "DataStoresFailed"
PlayerData.LOAD_NO_DATA = "LoadNoData"
--PlayerData.DS_INVALID_JSON = "DataStoresInvalidJSON"
PlayerData.LOAD_SUCCESS = "LoadSuccess"
PlayerData.LOAD_IN_STUDIO_DISABLED = "LoadInStudioDisabled"
PlayerData.NO_SAVE_ID = -1

PlayerData.SAVE_SUCCESS = "SaveSuccess"
PlayerData.SAVE_FAILED = "SaveFailed"
PlayerData.INTEGRITY_CHECK_FAILED = "integrityCheckPassed"
PlayerData.SAVE_IN_STUDIO_DISABLED = "SaveInStudioDisabled"

PlayerData.DEBUG_MODE = true

--- Generate a random save id, 24 unique characters, every 4 chars separated by -
-- Example: taCh-hKZh-87gZ-4vkf-1oPf-bn0u
PlayerData.SAVE_ID_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ01234567890"
PlayerData.SAVE_ID_LENGTH = 24
function PlayerData:generateSaveId()
	local saveId = {}
	for i = 1, PlayerData.SAVE_ID_LENGTH do
		if (i - 1) % 4 == 0 and i ~= 1 then
			table.insert(saveId, "-")
		end 
		local i = math.random(1, PlayerData.SAVE_ID_CHARS:len())
		table.insert(saveId, PlayerData.SAVE_ID_CHARS:sub(i, i))
	end
	return table.concat(saveId)
end

function PlayerData.new(loader, player)
	assert(loader)
	assert(player)
	local self = setmetatable({
		_loader = loader;
		_player = player;
		_saveId = PlayerData.NO_SAVE_ID;
		_loaded = false;
		_lastLoadedPayload = nil;
		_lastSavedPayload = nil;
	}, PlayerData)
	
	-- Other events
	self._playerChattedConn = self._player.Chatted:connect(function (...) return self:onChatted(...) end)
	
	-- Used with GlobalDataStore:OnUpdate
	self._updateAsyncFunc = function (...) return self:updateAsync(...) end
	
	return self
end

function PlayerData:warn(...)
	warn(...)
end

function PlayerData:getLoader()
	return self._loader
end

function PlayerData:getDataStore()
	return self:getLoader():getDataStore()
end

function PlayerData:areDataStoresAvailable()
	return type(self:getDataStore()) ~= "nil"
end

function PlayerData:cleanup()
	if self._playerChattedConn then
		self._playerChattedConn:Disconnect()
		self._playerChattedConn = nil 
	end
	self._player = nil
	self._lastSavedPayload = nil
	self._lastLoadedPayload = nil
end

function PlayerData:getDataStoreKey()
	return tostring(self._player.UserId)
end

function PlayerData:getSerializedData()
	print("Getting serialized data")
	return self:getLoader():_serializeDataModules(self._player)
end

function PlayerData:serialize()
	return {
		["saveId"] = self:generateSaveId();
		["time"] = os.time();
		["data"] = self:getSerializedData();
	}
end

function PlayerData:deserialize(payload)
	assert(typeof(payload) == "table")
	assert(typeof(payload["saveId"]) == "string")
	if type(payload["data"]) == "table" then
		self:getLoader():_deserializeDataModules(self._player, payload["data"])
	end
end

function PlayerData:initialize()
	self:getLoader():_initializeDataModules(self._player)
end

function PlayerData:loaded(payload)
	
end

function PlayerData:tryLoad()
	if RunService:IsStudio() and not self:getLoader():getSettings():shouldLoadInStudio() then return false, PlayerData.LOAD_IN_STUDIO_DISABLED end
	
	if not self:areDataStoresAvailable() then return false, PlayerData.DS_UNAVAILABLE end
	
	local dataStore = self:getDataStore()
	local success, payload = pcall(dataStore.GetAsync, dataStore, self:getDataStoreKey())
	-- Check for data store failure
	if success then
		self._lastLoadedPayload = payload
		self:loaded(payload)
		if type(payload) ~= "nil" then
			-- Load the payload
			self._saveId = payload["saveId"]
			self:deserialize(payload)
			self._loaded = true
			return true, PlayerData.LOAD_SUCCESS
		else
			-- No data means first visit
			self._loaded = true
			self._saveId = PlayerData.NO_SAVE_ID
			self:initialize()
			return true, PlayerData.LOAD_NO_DATA
		end
		
	else
		self:warn(("PlayerData:tryLoad() failed for %s: %s"):format(self._player.Name, tostring(payload)))
		return false, PlayerData.DS_FAILED
	end
end

function PlayerData:checkIntegrity(payload)
	-- If no data was loaded, we cannot check integrity of old data
	if self._saveId == PlayerData.NO_SAVE_ID then return true end
	-- Non-table data is assumed OK to overwrite
	if typeof(payload) ~= "table" then return true end
	-- If the loaded saveId doesn't match our own, that means
	-- another server saved after this server loaded but before our save.
	-- Therefore, we'd be overwriting more recent data.
	return payload["saveId"] == self._saveId
end

function PlayerData:updateAsync(oldPayload)
	local payload = self:serialize()
	self.integrityCheckPassed = true
	
	if type(oldPayload) == "nil" then
		-- No data! Save for the first time
		return payload
	else
		-- Integrity check
		if not self:checkIntegrity(oldPayload) then
			self:warn("Data integrity check failed, update cancelled")
			self.integrityCheckPassed = false
			return nil
		end
		-- Everything's OK, overwrite
		return payload
	end
end

function PlayerData:saved(payload)
	-- The game could notify the player that their data got saved (if they're still in-game, that is)
	if RunService:IsStudio() then
		print("PlayerData successfully saved")
		print(payload)
	end
end

function PlayerData:trySave()
	if RunService:IsStudio() then 
		if not self:getLoader():getSettings():shouldSaveInStudio() then
			return false, PlayerData.SAVE_IN_STUDIO_DISABLED
		else
			warn("Saving data to DataStores while in Roblox Studio")
		end
	end
	
	if not self:areDataStoresAvailable() then return false, PlayerData.DS_UNAVAILABLE end
	local dataStore = self:getDataStore()
	
	-- Reset the integrity check flag, as this will get set by updateAsync
	self.integrityCheckPassed = nil
	
	-- Invoke UpdateAsync, which calls self:updateAsync(oldPayload)
	local key = self:getDataStoreKey()
	local success, payload = pcall(dataStore.UpdateAsync, dataStore, key, self._updateAsyncFunc)
	if not success then
		self:warn(("PlayerData:trySave() failed for %s: %s"):format(self._player.Name, tostring(payload)))
		return false, PlayerData.SAVE_FAILED
	end
	
	-- Verify integrity check passed by flag set by updateAsync
	if not self.integrityCheckPassed then
		self:warn("Integrity check failed")
		return false, PlayerData.INTEGRITY_CHECK_FAILED
	end
	
	if payload then
		self._saveId = payload["saveId"]
		self._lastSavedPayload = payload
		self:saved(payload)
		return true, PlayerData.SAVE_SUCCESS
	else
		self:warn(("UpdateAsync finished but did not return a value"))
		return false, PlayerData.SAVE_FAILED
	end
end

function PlayerData:nuked()
	-- Now's the time for the game to reset the mechanisms whose
	-- data would normally be used in the serialization process.
	-- By default, just reinitialize each of the data modules.
	self:initialize()
end

function PlayerData:tryNuke()
	if RunService:IsStudio() and not self:getLoader():getSettings():shouldSaveInStudio() then return false, PlayerData.SAVE_IN_STUDIO_DISABLED end
	
	if not self:areDataStoresAvailable() then return false, PlayerData.DS_DISABLED end
	local dataStore = self:getDataStore()
	
	local success, payload = pcall(dataStore.RemoveAsync, dataStore, self:getDataStoreKey())
	if success then
		self._saveId = PlayerData.NO_SAVE_ID
		self:nuked()
		return true, PlayerData.SAVE_SUCCESS
	else
		warn(("PlayerData:tryNuke() failed for %s: %s"):format(self._player.Name, tostring(payload)))
		return false, PlayerData.SAVE_FAILED
	end
end

function PlayerData:onChatted(message, recipient)
	if not RunService:IsStudio() then return end
	if message == "::trySave" then
		print("trySave>", self:trySave())
	elseif message == "::tryLoad" then
		print("tryLoad>", self:tryLoad())
	elseif message == "::tryNuke" then
		print("tryNuke>", self:tryNuke())
	end
end

return PlayerData
