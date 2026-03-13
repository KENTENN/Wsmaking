-- [[ 1. ตั้งค่าพื้นฐานและรอโหลด ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local player = game.Players.LocalPlayer
-- แยกไฟล์ตาม UserId เพื่อให้เปิดหลายจอได้ไม่มีปัญหา
local FILE_NAME = "Gacha_ID_" .. player.UserId .. ".txt"
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"

local last_msg_id = nil
local rollCount = 0 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- [[ 2. ระบบบันทึกข้อมูลข้ามเซิร์ฟเวอร์ ]]
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

-- โหลดข้อมูลเดิม (ถ้ามี)
last_msg_id = loadData(FILE_NAME)
rollCount = tonumber(loadData(ROLL_FILE)) or 0

-- [[ 3. ฟังก์ชันดึงค่า Inventory (เช็คแบบกันบัค) ]]
local function getAmount(itemName)
    local amount = 0
    pcall(function()
        local playerGui = player:FindFirstChild("PlayerGui")
        local inv = playerGui and playerGui:FindFirstChild("Inventory")
        if inv then
            local holder = inv.CanvasGroup.backpack_frame.enlarging_frame.holder
            local item = holder:FindFirstChild(itemName)
            if item and item:FindFirstChild("Holder") then
                local text = item.Holder.Holder.Number.Text
                amount = tonumber(text:match("%d+")) or 0
            end
        end
    end)
    return amount
end

-- [[ 4. ฟังก์ชันวาร์ปเก็บของ (แก้บัค Deep Search + Nil Check) ]]
local function teleportToItems()
    local itemFound = false
    -- ดึง Descendants ทั้งหมดมาเช็ค (รวม Model ซ้อน Model)
    local allObjects = workspace:GetDescendants()
    
    for _, item in pairs(allObjects) do
        -- เช็คความปลอดภัยก่อนเข้าถึง Property เพื่อแก้บัค Nil
        if item and (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") then
            local success = pcall(function()
                if not item.Parent then return end -- ป้องกันวัตถุกำลังถูกลบ
                
                local prompt = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
                
                if prompt then
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if root then
                        -- ดึงพิกัดที่แม่นยำที่สุด
                        local targetPos = item:IsA("BasePart") and item.CFrame or (item.Parent:IsA("BasePart") and item.Parent.CFrame)
                        
                        if targetPos then
                            itemFound = true
                            root.CFrame = targetPos
                            task.wait(0.25)
                            fireproximityprompt(prompt)
                            task.wait(0.5)
                        end
                    end
                end
            end)
            if not success then continue end
        end
    end
    return itemFound
end

-- [[ 5. Discord Webhook Update ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Persistent Edition",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rerolls (Lifetime)", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Arrows In Inv", ["value"] = "**" .. getAmount("Stand Arrow") .. "**", ["inline"] = false},
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
        }}
    }

    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        local jsonData = HttpService:JSONEncode(data)
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if resp.Success then 
                last_msg_id = HttpService:JSONDecode(resp.Body).id 
                saveData(FILE_NAME, last_msg_id) 
            end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 6. ระบบ Server Hop ]]
local function hopServer()
    saveData(ROLL_FILE, rollCount) -- บันทึกสถิติก่อนย้ายเซิร์ฟ
    local servers = {}
    local cursor = ""
    repeat
        local success, result = pcall(function() 
            return HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s", game.PlaceId, cursor))) 
        end)
        if success and result and result.data then
            for _, s in ipairs(result.data) do 
                if s.playing < s.maxPlayers and s.id ~= game.JobId then 
                    table.insert(servers, s.id) 
                end 
            end
            cursor = result.nextPageCursor or ""
        else break end
    until cursor == "" or #servers >= 30
    
    if #servers > 0 then 
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player) 
    end
end

-- [[ 7. ลูปการทำงานหลัก (ตาม Flow ของคุณ) ]]
while task.wait(3) do
    local currentStand = "None"
    pcall(function() 
        currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" 
    end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    
    -- จบการทำงานเมื่อพบเป้าหมาย
    if currentStand == "Whitesnake" then 
        saveData(ROLL_FILE, rollCount)
        print("Whitesnake Found!")
        break 
    end

    -- 1. วาร์ปเก็บของในแมพ
    local foundInMap = teleportToItems()
    
    -- 2. สุ่มของในตัว
    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        saveData(ROLL_FILE, rollCount) -- บันทึกจำนวนทุกครั้งที่สุ่มสำเร็จ
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8) -- รอแอนิเมชันตาม Flowchart
        
        pcall(function() 
            local ctrl = player.Character:FindFirstChild("client_character_controller")
            if ctrl then ctrl.SummonStand:FireServer() end
        end)
        task.wait(2)
    elseif not foundInMap then
        -- 3. ถ้าไม่มีของทั้งในแมพและในตัว -> ย้ายเซิร์ฟ
        hopServer()
        break
    end
end
