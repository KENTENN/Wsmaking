repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

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

-- live
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

    char:WaitForChild("client_character_controller")
    :WaitForChild("SummonStand")
    :FireServer()

end

-- get stand
local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- roll arrow
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- check arrow amount
local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- find nearest arrow
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

-- PUBLIC SERVER HOP
local function serverHop()

    local servers = {}

    local req = game:HttpGet(
        "https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100"
    )

    local data = HttpService:JSONDecode(req)

    for _,server in pairs(data.data) do

        if server.playing < server.maxPlayers
        and server.id ~= currentJob then

            table.insert(servers,server.id)

        end

    end

    if #servers > 0 then

        local target = servers[math.random(1,#servers)]

        warn("Server hopping...")

        TeleportService:TeleportToPlaceInstance(
            placeId,
            target,
            player
        )

    end

end


-- เช็คตั้งแต่เข้าเซิร์ฟ
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
