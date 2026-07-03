--!strict
local RunService = game:GetService("RunService")

-- Shared Types
export type Remotes = {
	Event: RemoteEvent,
	Function: RemoteFunction,
	UEvent: UnreliableRemoteEvent,
}

--[=[
	Create a container to store all remotes for this module.
	On the server this is created under script.Parent.
	On the client it is resolved by waiting for that folder.
]=]

local CONTAINER: Folder?

if RunService:IsServer() then
	CONTAINER = Instance.new("Folder")
	CONTAINER.Name = "Remotes"
	CONTAINER.Parent = script.Parent
else
	CONTAINER = script.Parent:WaitForChild("Remotes", 10) :: Folder?
end

local NetUtils = {
	prefix = "Network_",
	CONTAINER = CONTAINER,
	MAXIMUM_CALLS = 1000,
}

--[=[
    Find the remotes container for a given network tag.
]=]
function NetUtils.getNetworks(tag: string): Folder?
	assert(tag, "Provide a Tag to fectch Network.")

	if not NetUtils.CONTAINER then
		return nil
	end

	local container = NetUtils.CONTAINER:FindFirstChild(`{NetUtils.prefix}{tag}`) :: Folder?

	return container
end

return NetUtils
