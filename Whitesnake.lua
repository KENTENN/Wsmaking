repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local currentJob = game.JobId

task.wait(6)

-- INVENTORY
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

-- STAND DATA
local liveFolder = workspace:WaitForChild("Live")

-- REMOTE
local useItem = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- ROOT
local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- SUMMON STAND
local function summonStand()

    local char = player.Character or player.CharacterAdded:Wait()

    local controller = char:FindFirstChild("client_character_controller")

    if controller then
        local remote = controller:FindFirstChild("SummonStand")
        if remote then
            remote:FireServer()
        end
    end

end

-- GET CURRENT STAND
local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- INVENTORY COUNT
local function getItemAmount(name)

    local item = holder:FindFirstChild(name)

    if item then
        local text = item.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- USE ITEM
local function useArrow(name)

    local args = {name}
    useItem:FireServer(unpack(args))

end

-- FIND ARROWS IN MAP (METHOD เดิม)
local function findArrows()

    local arrows = {}

    for _,v in pairs(workspace:GetChildren()) do

        if v:FindFirstChild("Lucky Arrow") then
            table.insert(arrows, v["Lucky Arrow"])
        end

        if v:FindFirstChild("Stand Arrow") then
            table.insert(arrows, v["Stand Arrow"])
        end

    end

    return arrows

end

-- NEAREST ARROW
local function getNearestArrow()

    local root = getRoot()
    local nearest
    local dist = math.huge

    for _,arrow in pairs(findArrows()) do

        local d = (root.Position - arrow.Position).Magnitude

        if d < dist then
            dist = d
            nearest = arrow
        end

    end

    return nearest

end

-- COLLECT
local function collectArrow(arrow)

    local root = getRoot()

    root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

    task.wait(0.4)

    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

    if prompt then
        fireproximityprompt(prompt)
    end

end

-- SERVER HOP
local function serverHop()

    warn("Server hopping...")

    task.wait(math.random(8,15))

    local cursor = ""
    local found

    for i = 1,5 do

        local success,data = pcall(function()

            local url =
            "https://games.roblox.com/v1/games/"
            ..placeId..
            "/servers/Public?sortOrder=Asc&limit=100&cursor="
            ..cursor

            return HttpService:JSONDecode(game:HttpGet(url))

        end)

        if success and data then

            for _,server in pairs(data.data) do

                if server.playing < server.maxPlayers
                and server.id ~= currentJob then

                    found = server.id
                    break

                end

            end

            if found then break end

            cursor = data.nextPageCursor

            if not cursor then break end

        else

            warn("HTTP 429 wait 15s")
            task.wait(15)
            return serverHop()

        end

        task.wait(1)

    end

    if found then

        TeleportService:TeleportToPlaceInstance(
            placeId,
            found,
            player
        )

    else

        task.wait(5)
        serverHop()

    end

end

-- CHECK STAND ON JOIN
local startStand = getStand()

if startStand == "Whitesnake" then
    warn("Already Whitesnake")
    return
end

-- MAIN LOOP
while task.wait(0.5) do

    local arrow = getNearestArrow()

    if arrow then

        collectArrow(arrow)

    else

        local lucky = getItemAmount("Lucky Arrow")
        local stand = getItemAmount("Stand Arrow")

        if lucky > 0 then

            useArrow("Lucky Arrow")

        elseif stand > 0 then

            useArrow("Stand Arrow")

        else

            warn("No arrows waiting 10s")

            task.wait(10)

            if getItemAmount("Stand Arrow") <= 0
            and getItemAmount("Lucky Arrow") <= 0 then

                serverHop()
                break

            end

        end

        task.wait(2)

        summonStand()

        task.wait(1)

        local current = getStand()

        print("Current Stand:",current)

        if current == "Whitesnake" then

            warn("WHITESNAKE FOUND")
            break

        end

    end

end
