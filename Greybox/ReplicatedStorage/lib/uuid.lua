local HttpService = game:GetService("HttpService")

local function uuid()
	return HttpService:GenerateGUID(false):lower()
end

return uuid
