# Net

## Introduction

Net is a Roblox networking library for building fast, reliable remote communication between client and server.

## Getting Started
## 1. Installation
Add Net to your ```wally.toml``` file:

```toml
[dependencies]
net = "aabiskar7q/net@1.0.3"
```

<b>Then run:</b>

```bash
wally install
```

## 2. Initialize a Networker
### <li> On Server: </li>
<b>Syntax:</b>

```lua
Service.Networker = Net.Server.init(NetworkTag, Module, AccessFunctions, MaximumCallPerSecond)
```
<b>Example: </b>
```lua
MyService.Networker = Net.Server.init("MyService", MyService, {
    MyService.DoSomething,
})
```

##
### <li> On Client: </li>
<b>Syntax:</b>

```lua
Service.Networker = Net.Client.init(NetworkTag, Module)
```
<b>Example: </b>
```lua
MyClientService.Networker = Net.Client.init("MyClientService", MyClientService)
```

>Note: Networker needs to be created on Server First and Same Network Tag should be used in Client for Networking

## 3. Fire/Get

### <li> On Server: </li>
<b>Syntax:</b>
```lua
self.Networker:Fire(
    players: (((Player) -> boolean) | { Player })?,
	methodName: string,
	isUnreliable: boolean?,
    ...
    )
```

####  1. Fire Selected Players

```lua
self.Networker:Fire({player1, player2}, "DoSomething", false, {Coins = 10})
```
####  2. Fire All Players

```lua
self.Networker:Fire(nil, "DoSomething", false, {Coins = 10})
```
####  3. Conditional Fire

```lua
self.Networker:Fire(function (player:Player)
    if player:GetAttribute("Role") == "Hunter" then
        return true
    end

    return false
end, 
"LocateSurvivors", false, {Weapon = "Knife"})
```

### <li> On Client: </li>
<b>Syntax:</b>

```lua
self.Networker:Fire(methodName: string, isUnreliable: boolean?, ...)
-- AND --
self.Networker:Get(methodName: string, ...)
```

> `Fire` can use `isUnreliable = true` to send via `UnreliableRemoteEvent`.
> `Get` always uses `RemoteFunction` and returns the server response.

#### 1. Fire Server

```lua
self.Networker:Fire("DoSomething", false, {Coins = 10})
```

#### 2. Get Response from Server

```lua
local response = self.Networker:Get("DoSomething")
```

## Example:
### <li> Server Side:
```lua
local Net = require(path.to.Net)
local TestService = {}

function TestService:PrintPlayerName(player:Player)
    print(player.Name)
end

function TestService:OnPlayerWin(player:Player)
    -- Show Stats and Victory Screen
    self.Networker:Fire(
        { player }, 
        "ShowVictoryScreen", 
        false, 
        {
            Kills = 10,
            Deaths = 5,
            TotalScore = 150,
        }
    )
end

function TestService:init()
    TestService.Networker = Net.Server.init(
        "TestService", 
        TestService, 
        {
            TestService.PrintPlayerName,
        }
    )
end
```

### <li> Client Side: 
```lua
local Net = require(path.to.Net)
local TestService = {}

function TestService:ShowVictoryScreen(data: {
	Kills: number,
	Deaths: number,
	TotalScore: number,
})

	-- --------------------------
	-- --------------------------
	-- Code to Display The Stats
	-- --------------------------
	-- --------------------------
end

function TestService:init()
    TestService.Networker = Net.Client.init(
        "TestService", 
        TestService,
    )
end
```
