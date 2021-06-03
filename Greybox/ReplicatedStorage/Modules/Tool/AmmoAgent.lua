local RunService = game:GetService("RunService")

local AmmoAgent = {}
AmmoAgent.__index = AmmoAgent
AmmoAgent.ATTR_AMMO = "Ammo"
AmmoAgent.ATTR_AMMO_MAX = "AmmoMax"
AmmoAgent.ATTR_AMMO_RECHARGE_TIME = "AmmoRechargeTime"
AmmoAgent.ATTR_AMMO_TIME_STOCK = "AmmoTimeStock"

function AmmoAgent.new(tool)
	assert(typeof(tool) == "Instance" and tool:IsA("Tool"), "Tool expected")
	local self = setmetatable({
		tool = tool;
	}, AmmoAgent)
	if RunService:IsServer() then
		self._ammoStepConn = RunService.Stepped:Connect(function (...) return self:ammoStep(...) end)
		self:restockAmmo()
	end
	return self
end

function AmmoAgent:cleanup()
	if self._ammoStepConn then
		self._ammoStepConn:Disconnect()
		self._ammoStepConn = nil
	end
	self.tool = nil
end

function AmmoAgent._attrGetterSetter(attr)
	local function getter(self)
		return self.tool:GetAttribute(attr)
	end
	local function setter(self, newValue)
		self.tool:SetAttribute(attr, newValue)
	end
	return getter, setter
end

AmmoAgent.getAmmo, AmmoAgent.setAmmo = AmmoAgent._attrGetterSetter(AmmoAgent.ATTR_AMMO)
AmmoAgent.getAmmoMax, AmmoAgent.setAmmoMax = AmmoAgent._attrGetterSetter(AmmoAgent.ATTR_AMMO_MAX)
AmmoAgent.getAmmoRechargeTime, AmmoAgent.setAmmoRechargeTime = AmmoAgent._attrGetterSetter(AmmoAgent.ATTR_AMMO_RECHARGE_TIME)
AmmoAgent.getAmmoTimeStock, AmmoAgent.setAmmoTimeStock = AmmoAgent._attrGetterSetter(AmmoAgent.ATTR_AMMO_TIME_STOCK)

function AmmoAgent:giveAmmo(n)
	n = n or 1
	assert(n > 0, "Cannot give a negative amount of ammo")
	self:setAmmo(math.min(self:getAmmoMax(), self:getAmmo() + n))
end

function AmmoAgent:takeAmmo(n)
	n = n or 1
	assert(n > 0, "Cannot take a negative amount of ammo")
	self:setAmmo(math.max(0, self:getAmmo() - n))
end

function AmmoAgent:ammoStep(t, dt)
	local ammo = self:getAmmo()
	local ammoMax = self:getAmmoMax()
	local ammoRechargeTime = self:getAmmoRechargeTime()
	local ammoTimeStock = self:getAmmoTimeStock()
	local ammoTimeStockBefore = ammoTimeStock
	if ammo < ammoMax then
		ammoTimeStock = ammoTimeStock + dt
		while ammoTimeStock >= ammoRechargeTime do
			self:giveAmmo(1)
			ammoTimeStock = ammoTimeStock - ammoRechargeTime 
		end
	else
		ammoTimeStock = 0
	end
	if ammoTimeStockBefore ~= ammoTimeStock then
		self:setAmmoTimeStock(ammoTimeStock)
	end
end

function AmmoAgent:restockAmmo()
	self:setAmmo(self:getAmmoMax())
end

return AmmoAgent
