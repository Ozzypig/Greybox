local RunService = game:GetService("RunService")

local GROUPS = {"Admin", "DefaultAdmin"}

return function (registry)
	registry:RegisterHook("BeforeRun", function(context)
		if table.find(GROUPS, context.Group) and context.Executor.UserId ~= game.CreatorId and not RunService:IsStudio() then
			return "You don't have permission to run this command"
		end
	end)
end
