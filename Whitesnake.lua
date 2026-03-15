-- [[ 1. ตั้งค่าเป้าหมาย ]]
local rawTarget = getgenv().TargetStand or "Whitesnake"
local targets = {}
if type(rawTarget) == "table" then targets = rawTarget else targets = {rawTarget} end

print("🎯 เป้าหมายที่ต้องการ: " .. table.concat(targets, ", "))

local function isTargetMet(currentStand)
    for _, name in pairs(targets) do if currentStand == name then return true end end
    return false
end

-- [[ 2. Setup ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local player = game.Players.LocalPlayer
local FILE_NAME = "Gacha_ID_" .. player.UserId .. ".txt"
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"

local last_msg_id = nil
local rollCount = 0 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- [[ 3. Data Persistence ]]
local function saveData(file, data) if writefile then pcall(function() writefile(file, tostring(data)) end) end end
local function loadData(file) if isfile and isfile(file) then local success, content = pcall(function() return readfile(file) end) return success and content or nil end return nil end

last_msg_id = loadData(FILE_NAME)
rollCount = tonumber(loadData(ROLL_FILE)) or 0
print("📊 สถิติเดิม: สุ่มไปแล้ว " .. rollCount .. " รอบ")

-- [[ 4. Inventory Check ]]
local function getAmount(itemName)
    local amount = 0
    pcall(function()
        local inv = player.PlayerGui:FindFirstChild("Inventory")
        if inv then
            local item = inv.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild(itemName)
            if item and item:FindFirstChild("Holder") then
                amount = tonumber(item.Holder.Holder.Number.Text:match("%d+")) or 0
            end
        end
    end)
    return amount
end

-- [[ 5. Teleport & Collect (มุดเก็บของใน Model) ]]
local function teleportToItems()
    local itemFound = false
    local descendants = workspace:GetDescendants() --
    
    for _, item in pairs(descendants) do
        if item and item.Parent and (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") then
            print("✨ พบ " .. item.Name .. " กำลังไปเก็บ...") --
            pcall(function()
                local prompt = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local targetPos = item:IsA("BasePart") and item.CFrame or (item.Parent:IsA("BasePart") and item.Parent.CFrame)
                        if targetPos then
                            itemFound = true
                            root.CFrame = targetPos
                            task.wait(0.3)
                            fireproximityprompt(prompt)
                            task.wait(0.5)
                        end
                    end
                end
            end)
        end
    end
    return itemFound
end

-- [[ 6. New Robust Server Hop (แก้ปัญหายืนนิ่ง) ]]
local function hopServer()
    print("🔄 กำลังค้นหาเซิร์ฟเวอร์ใหม่...")
    saveData(ROLL_FILE, rollCount)
    
    local function fetchServers(cursor)
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet(url)) end)
        return success and result or nil
    end

    while true do -- วนลูปจนกว่าจะวาร์ปออกไปได้
        local data = fetchServers()
        if data and data.data then
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then
                    print("🚀 เจอเซิร์ฟเวอร์แล้ว! กำลังวาร์ปไป: " .. server.id)
                    local success, err = pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                    end)
                    task.wait(3) -- รอช่วงวาร์ป ถ้าไม่ไปให้หาต่อ
                end
            end
        end
        print("⚠️ ไม่เจอเซิร์ฟเวอร์ที่เหมาะสม รีไตรใน 5 วินาที...")
        task.wait(5)
    end
end

-- [[ 7. Main Loop ]]
print("🎬 เริ่มการทำงาน...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 Stand ปัจจุบัน: " .. currentStand)

    if isTargetMet(currentStand) then 
        print("🎉 สำเร็จ! ได้ตัวที่ต้องการแล้ว")
        saveData(ROLL_FILE, rollCount)
        break 
    end

    -- 1. เก็บของ
    teleportToItems()
    
    -- 2. สุ่ม
    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        print("🎲 สุ่มรอบที่: " .. rollCount)
        saveData(ROLL_FILE, rollCount)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8) --
        pcall(function() 
            local ctrl = player.Character:FindFirstChild("client_character_controller")
            if ctrl then ctrl.SummonStand:FireServer() end
        end)
        task.wait(2)
    else
        -- 3. ถ้าของหมด ให้เรียก hopServer และไม่รันโค้ดต่อในเซิร์ฟเดิม
        print("❌ ของหมด! ทำการย้ายเซิร์ฟเวอร์...") --
        hopServer()
        return -- ป้องกันการรัน Loop ต่อขณะรอวาร์ป
    end
end
