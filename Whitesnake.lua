-- [[ 1. ตั้งค่าเป้าหมายจาก getgenv ]]
local rawTarget = getgenv().TargetStand or "Whitesnake"
local targets = {}
if type(rawTarget) == "table" then targets = rawTarget else targets = {rawTarget} end

print("🔍 เป้าหมายที่ต้องการ: " .. table.concat(targets, ", "))

-- ฟังก์ชันสำหรับเช็คว่าสแตนด์ปัจจุบันตรงกับเป้าหมายหรือไม่
local function isTargetMet(currentStand)
    for _, name in pairs(targets) do
        if currentStand == name then return true end
    end
    return false
end

-- [[ 2. Setup & Wait for Load ]]
print("⏳ กำลังรอให้เกมและตัวละครโหลด...")
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character
print("✅ เกมโหลดเสร็จสิ้น!")

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
local function saveData(file, data)
    if writefile then pcall(function() writefile(file, tostring(data)) end) end
end

local function loadData(file)
    if isfile and isfile(file) then
        local success, content = pcall(function() return readfile(file) end)
        return success and content or nil
    end
    return nil
end

print("💾 กำลังโหลดสถิติเดิม...")
last_msg_id = loadData(FILE_NAME)
rollCount = tonumber(loadData(ROLL_FILE)) or 0
print("📊 สถิติล่าสุด: สุ่มไปแล้ว " .. rollCount .. " รอบ")

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
    
    print("📡 กำลังสแกนหาไอเทมใน Workspace...")
    for _, item in pairs(descendants) do
        if item and item.Parent and (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") then
            print("✨ พบ " .. item.Name .. " ใน " .. item.Parent.Name) --
            local success = pcall(function()
                local prompt = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
                if prompt then
                    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        print("🚀 กำลังวาร์ปไปเก็บไอเทม...")
                        local targetPos = item:IsA("BasePart") and item.CFrame or (item.Parent:IsA("BasePart") and item.Parent.CFrame)
                        if targetPos then
                            itemFound = true
                            root.CFrame = targetPos
                            task.wait(0.3)
                            fireproximityprompt(prompt)
                            print("✅ เก็บไอเทมสำเร็จ!")
                            task.wait(0.5)
                        end
                    end
                end
            end)
            if not success then print("⚠️ เกิดข้อผิดพลาดในการเก็บไอเทม") end
        end
    end
    if not itemFound then print("❌ ไม่พบไอเทมในแมพ") end
    return itemFound
end

-- [[ 6. Main Loop ]]
print("🎬 เริ่มการทำงานหลัก...")
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    print("🧬 สแตนด์ปัจจุบันของคุณคือ: " .. currentStand)

    local success = isTargetMet(currentStand)
    
    -- ตรวจสอบเงื่อนไขหยุด
    if success then 
        print("🎉 ภารกิจสำเร็จ! พบ " .. currentStand .. " แล้ว")
        saveData(ROLL_FILE, rollCount)
        break 
    end

    -- 1. วาร์ปเก็บของ
    teleportToItems()
    
    -- 2. สุ่มของในตัว
    local arrows = getAmount("Stand Arrow")
    print("🏹 จำนวนลูกธนูในกระเป๋า: " .. arrows)

    if arrows > 0 then
        rollCount = rollCount + 1
        print("🎲 เริ่มการสุ่มรอบที่: " .. rollCount)
        saveData(ROLL_FILE, rollCount)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        print("⏳ รอแอนิเมชัน 8 วินาที...") --
        task.wait(8)
        
        print("⚡ เรียกสแตนด์ออกมมาเช็ค...")
        pcall(function() 
            local ctrl = player.Character:FindFirstChild("client_character_controller")
            if ctrl then ctrl.SummonStand:FireServer() end
        end)
        task.wait(2)
    else
        -- 3. ถ้าไม่มีของให้ย้ายเซิร์ฟ
        print("🔄 ของหมดแล้ว! เตรียมตัวย้ายเซิร์ฟเวอร์...") --
        -- (ฟังก์ชัน hopServer เหมือนเดิม)
        saveData(ROLL_FILE, rollCount)
        -- เรียกใช้ hopServer() ตรงนี้
        break
    end
end
