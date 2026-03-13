repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local currentJob = game.JobId

task.wait(6)

-- Inventory Path
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

-- Stand Data
local liveFolder = workspace:WaitForChild("Live")

-- Item Spawn Folder
local itemsFolder = workspace:FindFirstChild("Items") or workspace

-- Remote
local useArrow = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- Root
local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- Summon Stand
local function summonStand()

    local char = player.Character or player.CharacterAdded:Wait()

    char:WaitForChild("client_character_controller")
    :WaitForChild("SummonStand")
    :FireServer()

end

-- Read Stand
local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- Use Arrow
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- Arrow Amount
local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- Find Nearest Arrow
local function getNearestArrow()

    local root = getRoot()
    local nearest
    local dist = math.huge

    for _,v in pairs(itemsFolder:GetChildren()) do

        if v.Name == "Stand Arrow" then

            local part = v:IsA("BasePart") and v or v:FindFirstChildWhichIsA("BasePart")

            if part then

                local d = (root.Position - part.Position).Magnitude

                if d < dist then
                    dist = d
                    nearest = part
                end

            end

        end

    end

    return nearest
end

-- Collect Arrow
local function collectArrow(arrow)

    local root = getRoot()

    root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

    task.wait(0.3)

    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

    if prompt then
        fireproximityprompt(prompt)
    end

end


-- SERVER HOP (Public Only)
local function serverHop()

    local cursor = ""
    local foundServer = nil

    for i = 1,5 do

        local url = "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100&cursor="..cursor

        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)

        for _,server in pairs(data.data) do

            if server.playing < server.maxPlayers
            and server.id ~= currentJob
            and server.playing > 3 then

                foundServer = server.id
                break

            end

        end

        if foundServer then break end

        cursor = data.nextPageCursor

        if not cursor then break end

        task.wait(0.2)

    end

    if foundServer then

        warn("Teleporting to new public server")

        TeleportService:TeleportToPlaceInstance(
            placeId,
            foundServer,
            player
        )

    else

        warn("Retry server hop...")
        task.wait(2)
        serverHop()

    end

end


-- Check Stand On Join
local startStand = getStand()

if startStand == "Whitesnake" then
    warn("Already have Whitesnake")
    return
end


while task.wait(0.5) do

    local arrow = getNearestArrow()

    if arrow then

        collectArrow(arrow)

    else

        local amount = getArrowAmount()

        if amount <= 0 then

            warn("Arrow empty waiting 10s")

            task.wait(10)

            if getArrowAmount() <= 0 then
                serverHop()
                break
            end

        end

        rollStand()

        task.wait(2)

        summonStand()

        task.wait(1)

        local stand = getStand()

        print("Current Stand:",stand)

        if stand == "Whitesnake" then

            warn("WHITESNAKE FOUND")
            break

        end

    end

end
