local CollectionService = game:GetService("CollectionService")

local Binder = {}
Binder.__index = Binder

function Binder.new(tag, class)
	local self = setmetatable({
		class = class;
		tag = tag;
		objects = {};
		bound = false;
		onlyBindDescendantsOf = nil;
		debugMode = false;
	}, Binder)
	self.evInstanceAdded = CollectionService:GetInstanceAddedSignal(self.tag)
	self.evInstanceRemoved = CollectionService:GetInstanceRemovedSignal(self.tag)
	self.instanceAddedConn = nil
	self.instanceRemovedConn = nil
	
	return self
end

function Binder:__tostring()
	return ("<Binder %q>"):format(self.tag)
end

function Binder:print(...)
	if self.debugMode then
		print(tostring(self), ...)
	end
end

function Binder:warn(...)
	if self.debugMode then
		warn(tostring(self), ...)
	end
end

function Binder:bind()
	assert(not self.bound, "Already bound")
	self.bound = true
	-- Connect
	self.instanceAddedConn = self.evInstanceAdded:Connect(function (...)
		return self:onInstanceAdded(...)
	end)
	self.instanceRemovedConn = self.evInstanceRemoved:Connect(function (...)
		return self:onInstanceRemoved(...)
	end)
	-- Construct
	for _, object in pairs(CollectionService:GetTagged(self.tag)) do
		self:onInstanceAdded(object)
	end
	self:print("Is binding")
end

function Binder:unbind()
	assert(self.bound, "Not bound")
	self.bound = false
	-- Disconnect
	self.instanceAddedConn:Disconnect()
	self.instanceAddedConn = nil
	self.instanceRemovedConn:Disconnect()
	self.instanceRemovedConn = nil
	-- Deconstruct
	for instance, object in pairs(self.objects) do
		object:cleanup()
		self.objects[instance] = nil
	end
	self:print("Has unbound")
end

function Binder:getObject(instance)
	return self.objects[instance]
end

function Binder:shouldBind(instance)
	return not self.onlyBindDescendantsOf or instance:IsDescendantOf(self.onlyBindDescendantsOf)
end

function Binder:onInstanceAdded(instance)
	if not self.bound then return end
	if self:getObject(instance) then
		return
	end
	-- Ignore certain objects
	if not self:shouldBind(instance) then
		self:print(instance:GetFullName(), "Ignored")
		return
	end
	-- Construct
	local object = self.class.new(instance)
	self.objects[instance] = (object)
	self:print(instance:GetFullName(), "Bound")
end

function Binder:onInstanceRemoved(instance)
	-- Deconstruct
	local object = self.objects[instance]
	if not object then
		return
	end
	object:cleanup()
	object = nil
	self.objects[instance] = nil
	self:print(instance:GetFullName(), "Unbound")
end

return Binder
