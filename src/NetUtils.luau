--!strict
local RunService = game:GetService("RunService")

-- Shared Types
export type Remotes = {
	Event: RemoteEvent,
	Function: RemoteFunction,
	UEvent: UnreliableRemoteEvent,
}

--[=[
	Create a Container to store all Remotes
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
    Function to Fetch the Folder for respective Network tag
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
