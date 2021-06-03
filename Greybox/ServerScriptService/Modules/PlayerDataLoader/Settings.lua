local Settings = {}
Settings.__index = Settings

Settings.ATTR_LOAD_IN_STUDIO = "LoadInStudio"
Settings.loadInStudio = true

Settings.ATTR_SAVE_IN_STUDIO = "SaveInStudio"
Settings.saveInStudio = false

Settings.ATTR_LOAD_FAILED_MESSAGE = "LoadFailedMessage"
Settings.loadFailedMessage = "Oh no! Roblox couldn't load your data. Please re-join to try again!"

Settings.ATTR_NUKE_MESSAGE = "NukeMessage"
Settings.nukeMessage = "Your data has been reset. Please re-join the game."

function Settings.new()
	local self = setmetatable({
		loadInStudio = nil;
		saveInStudio = nil;
	}, Settings)
	return self
end

function Settings:shouldLoadInStudio()
	return self.loadInStudio
end

function Settings:shouldSaveInStudio()
	return self.saveInStudio
end

function Settings:getLoadFailedMessage()
	return self.loadFailedMessage
end

function Settings:getNukeMessage()
	return self.nukeMessage
end

function Settings:readAttributes(object)
	self.loadInStudio = object:GetAttribute(self.ATTR_LOAD_IN_STUDIO)
	self.saveInStudio = object:GetAttribute(self.ATTR_SAVE_IN_STUDIO)
	self.loadFailedMessage = object:GetAttribute(self.ATTR_LOAD_FAILED_MESSAGE)
	self.nukeMessage = object:GetAttribute(self.ATTR_NUKE_MESSAGE)
end

return Settings
