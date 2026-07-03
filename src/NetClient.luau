--!strict
local RunService = game:GetService("RunService")
local NetUtils = require(script.Parent.NetUtils)

-- Client-side networking helper.
-- This module resolves the corresponding server network container,
-- receives remote events, and sends client requests back to the server.
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
--[=[
	Invoke a client-side method when the server fires a remote event.
]=]
local function onEvent(accessModule: Module, methodName: string, ...)
	-- Invoke the client-side handler for the incoming remote method.
	if not accessModule or not methodName then
		return
	end

	-- Check if Method Exits
	local method = accessModule[methodName] :: Method?

	if not method then
		return
	end

	-- Call
	method(method, ...)
end

-- Main Class
local NetClient = {}
NetClient.__index = NetClient

--[=[
	Initialize the client-side Networker and connect remote events.
]=]
function NetClient.init(tag: string, accessModule: Module)
	assert(RunService:IsClient(), "Can Only be Initialized on Client")
	assert(accessModule, "Access Module not Provided.")

	local self = {
		Tag = tag,
		Module = accessModule,
		LastFired = {},
	}

	local container = NetUtils.getNetworks(self.Tag)

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

--[=[
	Send a remote event from client to server. This supports
	reliable and unreliable event types.
]=]
function NetClient.Fire(self: NetClient, methodName: string, isUnreliable: boolean?, ...)
	assert(methodName, "Method Not Provided")
	-- Rate-limit outgoing client requests.
	local delay = 1 / NetUtils.MAXIMUM_CALLS

	if (os.clock() - (self.LastFired[methodName] or 0)) >= delay then
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

--[=[
	Invoke a server-side RemoteFunction and return the result.
]=]
function NetClient.Get(self: NetClient, methodName: string, ...): ...any?
	assert(methodName, "Method Not Provided")
	-- Rate-limit outgoing calls to the server function.
	local delay = 1 / NetUtils.MAXIMUM_CALLS

	if (os.clock() - (self.LastFired[methodName] or 0)) >= delay then
		self.LastFired[methodName] = os.clock()

		return self.Remotes.Function:InvokeServer(methodName, ...)
	else
		warn(`Get("{methodName}") was rate limited`)
		return nil
	end
end

return NetClient
