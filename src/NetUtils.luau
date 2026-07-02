--!strict

-- Shared Types
export type Remotes = {
	Event: RemoteEvent,
	Function: RemoteFunction,
	UEvent: UnreliableRemoteEvent,
}

--[=[
	Create a Container to store all Remotes
]=]
const CONTAINER = Instance.new("Folder")
CONTAINER.Name = "Remotes"
CONTAINER.Parent = script.Parent

local NetUtils = {
	prefix = "Network_",
	CONTAINER = CONTAINER,
	MAXIMUM_CALLS = 1000,
}

--[=[
    Function to Fetch the Folder for respective Network tag
]=]
function NetUtils:getNetworks(tag: string): Folder?
	assert(tag, "Provide a Tag to fectch Network.")

	local container = NetUtils.CONTAINER:FindFirstChild(`{NetUtils.prefix}{tag}`) :: Folder?

	return container
end

return NetUtils
