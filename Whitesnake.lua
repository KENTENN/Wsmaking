repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local currentJob = game.JobId

task.wait(6)

-- inventory
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

-- stand folder
local liveFolder = workspace:WaitForChild("Live")

-- items
local itemsFolder = workspace:FindFirstChild("Items") or workspace

-- remote
local useArrow = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- root
local function getRoot()

    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")

end

-- summon stand
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

-- get stand
local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- roll stand
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- arrow amount
local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then

        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0

    end

    return 0

end

-- nearest arrow
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

-- collect arrow
local function collectArrow(arrow)

    local root = getRoot()

    root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

    task.wait(0.3)

    local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

    if prompt then
        fireproximityprompt(prompt)
    end

end

-- server hop
local function serverHop()

    warn("Server hopping...")

    task.wait(math.random(8,15))

    local cursor = ""
    local foundServer

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

                    foundServer = server.id
                    break

                end

            end

            if foundServer then break end

            cursor = data.nextPageCursor

            if not cursor then break end

        else

            warn("HTTP 429 blocked waiting 15s")
            task.wait(15)
            return serverHop()

        end

        task.wait(1)

    end

    if foundServer then

        TeleportService:TeleportToPlaceInstance(
            placeId,
            foundServer,
            player
        )

    else

        warn("Retry server hop")
        task.wait(5)
        serverHop()

    end

end


-- check stand on join
local startStand = getStand()

if startStand == "Whitesnake" then
    warn("Already Whitesnake")
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

        task.wait(8)

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
