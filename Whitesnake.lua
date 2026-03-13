repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

print("--- [ Script Started ] ---")
task.wait(5) 

-- Path Settings
local holder = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("CanvasGroup"):WaitForChild("backpack_frame"):WaitForChild("enlarging_frame"):WaitForChild("holder")
local live = workspace:WaitForChild("Live")
local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")

-- [ Functions ] --

local function getStand()
    local char = live:FindFirstChild(player.Name)
    return char and char:GetAttribute("SummonedStand") or "None"
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

local function serverHop()
    warn("!!! Status: Arrows ran out. Preparing to Server Hop...")
    task.wait(2)
    local cursor = ""
    while true do
        local success, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..placeId.."/servers/Public?sortOrder=Asc&limit=100&cursor="..cursor))
        end)
        if success and data then
            for _, server in pairs(data.data) do
                if server.playing < server.maxPlayers and server.id ~= jobId then
                    print("Found new server: " .. server.id)
                    TeleportService:TeleportToPlaceInstance(placeId, server.id, player)
                    return
                end
            end
            cursor = data.nextPageCursor
            if not cursor then break end
        end
        task.wait(0.5)
    end
end

--------------------------------------------------
-- [ Main Logic ] --
--------------------------------------------------

-- 1. เช็คตอนเริ่มเกม
print("Status: Checking current stand...")
if isWhitesnake() then 
    warn("Found Whitesnake! Stopping script.")
    return 
end
print("Current Stand: " .. getStand() .. " | Status: Searching for Arrows...")

while task.wait(1) do
    -- เช็ค Whitesnake ทุกต้นรอบ
    if isWhitesnake() then 
        warn("Success: Whitesnake Obtained!")
        break 
    end

    -- 2. เช็คในแมพ
    local arrowInMap = findArrow()
    if arrowInMap then
        print("Action: Found Arrow in world! Teleporting to collect...")
        local char = player.Character or player.CharacterAdded:Wait()
        local root = char:WaitForChild("HumanoidRootPart")
        root.CFrame = arrowInMap.CFrame + Vector3.new(0, 3, 0)
        
        task.wait(0.5)
        local prompt = arrowInMap:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then 
            fireproximityprompt(prompt)
            print("Status: Collected arrow from map.")
        end
        task.wait(1.5)
        
    else
        -- 3. เช็คในกระเป๋า
        local arrowsInInv = getArrowAmount()
        if arrowsInInv > 0 then
            print("Action: No arrows in map. Using Arrow from inventory (Remaining: " .. arrowsInInv .. ")")
            useItem:FireServer("Stand Arrow")
            
            print("Status: Waiting 8 seconds for animation...")
            task.wait(8)
            
            print("Action: Summoning Stand to check result...")
            local char = player.Character or player.CharacterAdded:Wait()
            local controller = char:FindFirstChild("client_character_controller")
            if controller and controller:FindFirstChild("SummonStand") then
                controller.SummonStand:FireServer()
            end
            
            task.wait(2)
            print("Result: Current Stand is " .. getStand())
            
        else
            -- 4. ไม่มีของเลย
            print("Status: No arrows in world or inventory.")
            serverHop()
            break
        end
    end
end
