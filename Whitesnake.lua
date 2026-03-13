repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

task.wait(5)

-- inventory
local holder = player.PlayerGui
:WaitForChild("Inventory")
:WaitForChild("CanvasGroup")
:WaitForChild("backpack_frame")
:WaitForChild("enlarging_frame")
:WaitForChild("holder")

local live = workspace:WaitForChild("Live")

local useItem = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- root
local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- current stand
local function getStand()

    local char = live:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

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

-- arrow count
local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- use arrow
local function useArrow()
    useItem:FireServer("Stand Arrow")
end

-- find arrow in map
local function findArrow()

    for _,v in pairs(workspace:GetChildren()) do

        if v:FindFirstChild("Stand Arrow") then
            return v["Stand Arrow"]
        end

    end

end

-- collect arrow
local function collectArrow()

    local arrow = findArrow()

    if arrow then

        local root = getRoot()

        root.CFrame = arrow.CFrame + Vector3.new(0,3,0)

        task.wait(0.4)

        local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt",true)

        if prompt then
            fireproximityprompt(prompt)
        end

        return true
    end

    return false
end

-- server hop
local function serverHop()

    warn("Server Hop")

    task.wait(10)

    local cursor = ""

    for i=1,5 do

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
                and server.id ~= jobId then

                    TeleportService:TeleportToPlaceInstance(
                        placeId,
                        server.id,
                        player
                    )

                    return
                end

            end

            cursor = data.nextPageCursor
            if not cursor then break end

        end

    end

end

------------------------------------------------

-- 1️⃣ เช็ค Whitesnake ตอนเข้าเกม

if getStand() == "Whitesnake" then
    warn("Already Whitesnake")
    return
end

------------------------------------------------

while task.wait(0.6) do

    -- 2️⃣ หา Arrow ในแมพ
    local collected = collectArrow()

    if not collected then

        local arrows = getArrowAmount()

        -- 3️⃣ ถ้ามี Arrow → สุ่ม
        if arrows > 0 then

            useArrow()

            task.wait(1)

            summonStand()

            -- ดีเลย์สุ่ม
            task.wait(8)

            local stand = getStand()

            print("Stand:",stand)

            if stand == "Whitesnake" then
                warn("WHITESNAKE FOUND")
                break
            end

        else

            -- 4️⃣ Arrow หมด → ลองหาในแมพอีกครั้ง
            task.wait(3)

            if not findArrow() then
                serverHop()
                break
            end

        end

    end

end
