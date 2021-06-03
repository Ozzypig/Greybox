--- ThreadPool
-- A utility class for keeping track of running functions at once
-- wrap(func, ...) - arbitrary functions using wrap(func, ...)
-- wait()          - yield until all functions have halted
-- getCount()      - inspect number of currently unhalted functions 

local ThreadPool = {}
ThreadPool.__index = ThreadPool

function ThreadPool.new()
	local self = setmetatable({
		_count = 0;
		evCountChanged = Instance.new("BindableEvent");
	}, ThreadPool)
	self.onCountChanged = self.evCountChanged.Event
	return self
end

function ThreadPool:cleanup()
	if self.evCountChanged then
		self.evCountChanged:Destroy()
		self.evCountChanged = nil
	end
	self.onCountChanged = nil
end

function ThreadPool:_setCount(count)
	self._count = count
	self.evCountChanged:Fire(count) -- Not self._count, could cause race condition
end

function ThreadPool:getCount()
	return self._count
end

function ThreadPool:wrap(func, ...)
	-- First, increase the running function count
	self:_setCount(self._count + 1)
	-- Call the function using pcall
	local retVals
	local success, err = pcall(function (...) retVals = { func(...) }; end, ...)
	-- Function halted, so decrease the running function counter 
	-- This resumes wait()-ing threads
	self:_setCount(self._count - 1)
	-- Raise errors (if any) to the thread that wrapped this function
	if not (success and retVals) then
		error("ThreadPool:wrap function raised error: " .. err)
	end
	-- Finally, return values from the function
	return unpack(retVals)
end

function ThreadPool:wait()
	if self._count == 0 then return end
	local count
	repeat
		count = self.onCountChanged:wait()
	until count == 0
end

return ThreadPool
