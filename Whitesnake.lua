repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

task.wait(5) -- รอ UI โหลดชัวร์ๆ

-- รายการ Path ที่สำคัญ
local holder = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("CanvasGroup"):WaitForChild("backpack_frame"):WaitForChild("enlarging_frame"):WaitForChild("holder")
local live = workspace:WaitForChild("Live")
local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")

-- [ ฟังก์ชันเสริมต่างๆ ] --

local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

local function getStand()
    local char = live:FindFirstChild(player.Name)
    return char and char:GetAttribute("SummonedStand") or nil
end

local function summonStand()
    local char = player.Character or player.CharacterAdded:Wait()
    local controller = char:FindFirstChild("client_character_controller")
    if controller and controller:FindFirstChild("SummonStand") then
        controller.SummonStand:FireServer()
    end
end

local function getArrowAmount()
    local slot = holder:FindFirstChild("Stand Arrow")
    if slot then
        local success, result = pcall(function()
            return tonumber(slot.Holder.Holder.Number.Text:match("%d+")) or 0
        end)
        return success and result or 0
    end
    return 0
end

local function findArrow()
    for _,v in pairs(workspace:GetChildren()) do
        if v:FindFirstChild("Stand Arrow") then return v["Stand Arrow"] end
    end
    return nil
end

local function collectArrow()
    local arrow = findArrow()
    if arrow then
        local root = getRoot()
        root.CFrame = arrow.CFrame + Vector3.new(0,3,0)
        task.wait(0.4)
        local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then fireproximityprompt(prompt) end
        return true
    end
    return false
end

local function isWhitesnake()
    if getStand() == "Whitesnake" then return true end
    local char = live:FindFirstChild(player.Name)
    if char then
        for _, v in pairs(char:GetChildren()) do
            if v:IsA("Model") and v.Name == "Whitesnake" then return true end
        end
    end
    return false
end

local function serverHop()
    warn("Server Hopping...")
    local cursor = ""
    while true do
        local success, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100&cursor="..cursor))
        end)
        if success and data then
            for _, server in pairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= jobId then
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
                    return
                end
            end
            cursor = data.nextPageCursor
            if not cursor then break end
        else break end
        task.wait(1)
    end
end

--------------------------------------------------
-- [ เริ่มการทำงานหลัก (Main Logic) ] --
--------------------------------------------------

if isWhitesnake() then 
    warn("!!! FOUND WHITESNAKE - SCRIPT STOPPED !!!")
    return 
end

while task.wait(1) do
    -- 1. เช็ค Whitesnake ทุกต้นรอบ
    if isWhitesnake() then break end

    -- 2. หาและเก็บ Arrow ในแมพก่อนเสมอ
    if findArrow() then
        collectArrow()
        task.wait(1)
    else
        -- 3. ถ้าในแมพไม่มี เช็คในกระเป๋า
        local arrows = getArrowAmount()
        if arrows > 0 then
            useItem:FireServer("Stand Arrow")
            task.wait(8) -- เวลากดใช้
            
            -- พยายามเรียก Stand ออกมาเช็ค
            summonStand()
            task.wait(2)
            
            if isWhitesnake() then
                warn("WHITESNAKE FOUND!")
                break
            end
        else
            -- 4. ไม่มีทั้งในแมพและในตัว -> ย้ายเซิร์ฟ
            task.wait(2)
            if not findArrow() then
                serverHop()
                break
            end
        end
    end
end
