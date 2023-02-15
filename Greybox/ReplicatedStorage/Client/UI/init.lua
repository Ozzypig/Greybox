local UI = {}
UI.__index = UI

function UI.new(client, playerGui)
	assert(typeof(playerGui) == "Instance" and playerGui:IsA("PlayerGui"), "PlayerGui expected")
	local self = setmetatable({
		client = client;
		playerGui = playerGui;

	}, UI)
	
	return self
end

function UI:main()
	
end

function UI:destroy()
	self.playerGui = nil
	self.client = nil
end

return UI
