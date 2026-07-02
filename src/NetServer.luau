--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local NetUtils = require(script.Parent.NetUtils)

-- ====================================================
-- 		================== TYPES ================
-- ====================================================

type Method = (Player, ...any?) -> ...any?

export type NetServer = {
	Tag: string,
	Module: { [string]: Method }?,
	AccessFunctions: { Method },
	Remotes: NetUtils.Remotes,
	MaxCall: number?,
	LastResponse: { [Player]: { [string]: number } },

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
	Function to Create Remotes for given tag
]=]

local function createNewNetwork(tag: string): NetUtils.Remotes?
	assert(tag, "Tag not Provided.")

	if NetUtils.CONTAINER:FindFirstChild(tag) then
		warn(`{tag} already Exists. Creation Failed!`)
		return nil
	end

	-----------Create if doesn't Exist----------

	-- Create a Folder to Store all
	local container = Instance.new("Folder")
	container.Name = NetUtils.prefix .. tag
	container.Parent = NetUtils.CONTAINER

	--
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

local function onEvent(
	player: Player,
	methodName: string,
	module: { [string]: Method }?,
	accessFunctions: { Method }?,
	...
)
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
		return
	end

	-- Check if Method is accessible
	if not table.find(accessFunctions, method) then
		return
	end

	--
	local retVal = method(player, ...)

	return retVal
end

--[=[
	Function to Handle Client Events
]=]

--[=[

]=]

local NetServer = {}
NetServer.__index = NetServer

--[=[
	Class Constructor to Initialize Networker in Server
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

	setmetatable(self, NetServer)

	return self
end

--[=[
	Function To Fire to Client
]=]

function NetServer.Fire(
	self: NetServer,
	players: ((Player) -> boolean | { Player })?,
	methodName: string,
	isUnreliable: boolean?,
	...
)
	assert(methodName, "Method Wasn't Provided")

	local clients = {} :: { Player }

	if not players then
		clients = {}
	elseif type(players) == "function" then
		--
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

	if #clients < 1 then
		clients = Players:GetPlayers()
	end

	--
	for _, player in clients do
		if isUnreliable then
			self.Remotes.UEvent:FireClient(player, methodName, ...)
			continue
		end

		self.Remotes.Event:FireClient(player, methodName, ...)
	end
end

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

function NetServer.clean(self: NetServer)
	local container = NetUtils:getNetworks(self.Tag)

	if container then
		container:Destroy()
	end
end

return NetServer
