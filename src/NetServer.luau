--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local NetUtils = require(script.Parent.NetUtils)

-- Server-side networking helper.
-- This module creates the remote objects, validates client requests,
-- and forwards allowed calls into the server-side service module.
-- ====================================================
-- 		================== TYPES ================
-- ====================================================

type Method = (Method, Player, ...any?) -> ...any?

export type NetServer = {
	Tag: string,
	Module: { [string]: Method }?,
	AccessFunctions: { Method },
	Remotes: NetUtils.Remotes,
	MaxCall: number?,
	LastResponse: { [Player]: { [string]: number } },
	PlayerRemovingConn: RBXScriptConnection,

	-- Methods
	clean: (self: NetServer) -> ...any?,
	Fire: (
		self: NetServer,
		players: ((Player) -> boolean | { Player })?,
		methodName: string,
		isUnreliable: boolean?
	) -> (),
	CheckRateLimitStatus: (self: NetServer, player: Player, methodName: string) -> boolean?,
}

-- ====================================================
-- ================== HELPER FUNCTIONS ================
-- ====================================================

--[=[
	Create the RemoteEvent, RemoteFunction, and UnreliableRemoteEvent
	for a given network tag. This runs only on the server.
]=]

local function createNewNetwork(tag: string): NetUtils.Remotes?
	assert(tag, "Tag not Provided.")

	if NetUtils.getNetworks(tag) then
		warn(`{tag} already Exists. Creation Failed!`)
		return nil
	end

	-----------Create if doesn't Exist----------

	-- Create a Folder to Store all
	local container = Instance.new("Folder")
	container.Name = NetUtils.prefix .. tag
	container.Parent = NetUtils.CONTAINER

	-- Create remotes used for events, functions, and unreliable events.
	local RE = Instance.new("RemoteEvent")
	RE.Parent = container

	local RF = Instance.new("RemoteFunction")
	RF.Parent = container

	local URE = Instance.new("UnreliableRemoteEvent")
	URE.Parent = container

	return {
		Event = RE,
		Function = RF,
		UEvent = URE,
	}
end

--[=[
	Validate an incoming remote call from a client, ensure the
	requested method exists and is accessible, then invoke it.
]=]
local function onEvent(
	player: Player,
	methodName: string,
	module: { [string]: Method }?,
	accessFunctions: { Method }?,
	...
)
	-- Validate the incoming client request and invoke the
	-- matching method on the server module if allowed.
	if not player or player.Parent ~= Players or not methodName then
		return
	end

	if not module then
		return
	end

	if not accessFunctions then
		return
	end

	-- Check if method exists
	local method = module[methodName]

	if not method or type(method) ~= "function" then
		warn("Method Not Found in Server...")
		return
	end

	-- Check if Method is accessible
	if not table.find(accessFunctions, method) then
		warn("Method Not Accessible to Client...")
		return
	end

	-- Call the server-side method with the player as first argument.
	local retVal = method(method, player, ...)

	return retVal
end

local NetServer = {}
NetServer.__index = NetServer

--[=[
	Create a server-side Networker, build the remotes folder,
	and wire event/function callbacks for client communication.
]=]

function NetServer.init(
	tag: string,
	module: { [string]: Method }?,
	accessFunctions: { Method }?,
	maximumCallPerSecond: number?
)
	assert(RunService:IsServer(), "Can Only be Initialized on Server")

	local self = {
		Tag = tag,
		Module = module,
		AccessFunctions = accessFunctions,
		MaxCall = maximumCallPerSecond,
		LastResponse = {},
	} :: NetServer

	local remotes = createNewNetwork(tag)

	assert(remotes, "Network Creation Failed for " .. tag)

	self.Remotes = remotes

	-- On Remote Event
	self.Remotes.Event.OnServerEvent:Connect(function(player: Player, method: string, ...)
		if self:CheckRateLimitStatus(player, method) then
			onEvent(player, method, self.Module, self.AccessFunctions, ...)
		end
	end)

	-- On Unreliable Remote Event
	self.Remotes.UEvent.OnServerEvent:Connect(function(player: Player, method: string, ...)
		if self:CheckRateLimitStatus(player, method) then
			onEvent(player, method, self.Module, self.AccessFunctions, ...)
		end
	end)

	-- On Fetch (called Remote Function)
	self.Remotes.Function.OnServerInvoke = function(player: Player, method: string, ...)
		if self:CheckRateLimitStatus(player, method) then
			return onEvent(player, method, self.Module, self.AccessFunctions, ...)
		end
	end

	--
	self.PlayerRemovingConn = Players.PlayerRemoving:Connect(function(player: Player)
		self.LastResponse[player] = nil
	end)

	setmetatable(self, NetServer)

	return self
end

--[=[
	Send a remote event to a subset of clients, all clients, or
	clients selected by a predicate. Supports unreliable events.
]=]

function NetServer.Fire(
	self: NetServer,
	players: (((Player) -> boolean) | { Player })?,
	methodName: string,
	isUnreliable: boolean?,
	...
)
	assert(methodName, "Method Wasn't Provided")

	local clients = {} :: { Player }

	-- If no filter is provided, fire to all players.
	if not players then
		if isUnreliable then
			self.Remotes.UEvent:FireAllClients(methodName, ...)
		else
			self.Remotes.Event:FireAllClients(methodName, ...)
		end
	elseif type(players) == "function" then
		-- Filter players with a predicate function.
		for _, player in Players:GetPlayers() do
			if players(player) then
				table.insert(clients, player)
			end
		end
	elseif type(players) == "table" then
		if #players >= 1 then
			for _, player in players :: { Player } do
				if player:IsA("Player") then
					table.insert(clients, player)
				end
			end
		end
	end

	-- Send the event to selected clients.
	for _, player in clients do
		if isUnreliable then
			self.Remotes.UEvent:FireClient(player, methodName, ...)
		else
			self.Remotes.Event:FireClient(player, methodName, ...)
		end
	end
end

--[=[
	Return true if the given client method call is allowed by rate
	limit settings. This prevents abuse of remote calls.
]=]
function NetServer.CheckRateLimitStatus(self: NetServer, player: Player, methodName: string): boolean?
	if not player then
		return false
	end

	--
	local maxCalls = self.MaxCall or math.huge
	--
	if not self.LastResponse[player] then
		self.LastResponse[player] = {}
	end

	local lastCall = self.LastResponse[player][methodName] or 0
	--

	if (os.clock() - lastCall) >= (1 / maxCalls) then
		-- Save New
		self.LastResponse[player][methodName] = os.clock()

		return true
	end

	return false
end

--[=[
	Destroy the network container and clear rate-limit state.
]=]
function NetServer.clean(self: NetServer)
	local container = NetUtils.getNetworks(self.Tag)

	if container then
		container:Destroy()
	end

	table.clear(self.LastResponse)
end

return NetServer
