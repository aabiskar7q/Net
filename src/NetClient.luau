--!strict
local RunService = game:GetService("RunService")
local NetUtils = require(script.Parent.NetUtils)

-- ====================================================
-- 		================== TYPES ================
-- ====================================================

type Method = (...any?) -> ...any?
type Module = { [string]: Method }

export type NetClient = {
	Tag: string,
	Module: Module,
	Remotes: NetUtils.Remotes,
	LastFired: { [string]: number },

	Fire: (self: NetClient, methodName: string, isUnreliable: boolean?, ...any?) -> (),
	Get: (self: NetClient, methodName: string, ...any?) -> ...any?,
}

-- Helper Functions
local function onEvent(accessModule: Module, methodName: string, ...)
	if not accessModule or not methodName then
		return
	end

	-- Check if Method Exits
	local method = accessModule[methodName] :: Method?

	if not method then
		return
	end

	-- Call
	method(...)
end

-- Main Class
local NetClient = {}
NetClient.__index = NetClient

function NetClient.init(tag: string, accessModule: Module)
	assert(RunService:IsClient(), "Can Only be Initialized on Client")
	assert(accessModule, "Access Module not Provided.")

	local self = {
		Tag = tag,
		Module = accessModule,
		LastFired = {},
	}

	local container = NetUtils:getNetworks(self.Tag)

	assert(container, tag .. "_Networker not created by Server...")

	-- If Created Then add to Remotes
	local RE = container:FindFirstChildOfClass("RemoteEvent")
	local RF = container:FindFirstChildOfClass("RemoteFunction")
	local URE = container:FindFirstChildOfClass("UnreliableRemoteEvent")

	assert(RE and RF and URE, "Error Occured while trying to fetch Networker.")

	-- Add to Remotes
	self.Remotes = {
		Event = RE,
		Function = RF,
		UEvent = URE,
	} :: NetUtils.Remotes

	-- Handle When Remote Events are Fired by Server
	RE.OnClientEvent:Connect(function(methodName, ...)
		onEvent(self.Module, methodName, ...)
	end)

	URE.OnClientEvent:Connect(function(methodName, ...)
		onEvent(self.Module, methodName, ...)
	end)

	setmetatable(self, NetClient)

	return self :: NetClient
end

function NetClient.Fire(self: NetClient, methodName: string, isUnreliable: boolean?, ...)
	assert(methodName, "Method Not Provided")
	--
	local delay = 1 / NetUtils.MAXIMUM_CALLS

	if (os.clock() - (self.LastFired[methodName] or 0)) >= delay then
		--
		self.LastFired[methodName] = os.clock()

		if isUnreliable then
			self.Remotes.UEvent:FireServer(methodName, ...)
		else
			self.Remotes.Event:FireServer(methodName, ...)
		end
	else
		warn(`Fire("{methodName}") was rate limited`)
	end
end

function NetClient.Get(self: NetClient, methodName: string, ...): ...any?
	assert(methodName, "Method Not Provided")
	--
	local delay = 1 / NetUtils.MAXIMUM_CALLS

	if (os.clock() - (self.LastFired[methodName] or 0)) >= delay then
		--
		self.LastFired[methodName] = os.clock()

		return self.Remotes.Function:InvokeServer(methodName, ...)
	else
		warn(`Get("{methodName}") was rate limited`)
		return nil
	end
end

return NetClient
