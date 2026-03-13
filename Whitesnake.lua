-- [[ 1. Setup & Wait for Load ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local player = game.Players.LocalPlayer
local FILE_NAME = "Gacha_ID_" .. player.UserId .. ".txt"
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt" -- ไฟล์เก็บจำนวน Roll แยกตาม Account

local last_msg_id = nil
local rollCount = 0 

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

-- [[ 2. ระบบจัดการข้อมูล (Persistence Logic) ]]
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

-- โหลดข้อมูลเดิมที่บันทึกไว้
last_msg_id = loadData(FILE_NAME)
rollCount = tonumber(loadData(ROLL_FILE)) or 0

-- [[ 3. Inventory Check (ดึงเฉพาะตัวเลข) ]]
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

-- [[ 4. Teleport & Collect (Recursive Search ใน Model) ]]
local function teleportToItems()
    local itemFound = false
    local descendants = workspace:GetDescendants()
    
    for _, item in pairs(descendants) do
        -- Safety Check เพื่อกันบัค index nil
        if item and item.Parent and (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") then
            pcall(function()
                local prompt = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
                
                if prompt then
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if root then
                        local targetPos = item:IsA("BasePart") and item.CFrame or (item.Parent:IsA("BasePart") and item.Parent.CFrame)
                        if targetPos then
                            itemFound = true
                            print("✨ วาร์ปไปเก็บ: " .. item.Name)
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

-- [[ 5. Discord Webhook Update (Live & Persistent) ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Global Counter",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls (Lifetime)", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Arrows: **" .. getAmount("Stand Arrow") .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Searching/Rolling...", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
        }}
    }

    pcall(function()
        local requestFunc = (syn and syn.request) or (http_request) or (request)
        local jsonData = HttpService:JSONEncode(data)
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if resp.Success then last_msg_id = HttpService:JSONDecode(resp.Body).id saveData(FILE_NAME, last_msg_id) end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 6. Server Hop ]]
local function hopServer()
    print("Saving data and hopping...")
    saveData(ROLL_FILE, rollCount) -- บันทึกค่าก่อนย้ายเซิร์ฟ
    
    local servers = {}
    local cursor = ""
    repeat
        local success, result = pcall(function() 
            return HttpService:JSONDecode(game:HttpGet(string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s", game.PlaceId, cursor))) 
        end)
        if success and result and result.data then
            for _, s in ipairs(result.data) do if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end end
            cursor = result.nextPageCursor or ""
        else break end
    until cursor == "" or #servers >= 30
    if #servers > 0 then TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], player) end
end

-- [[ 7. Main Execution Loop (Flowchart Optimization) ]]
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    
    if currentStand == "Whitesnake" then 
        saveData(ROLL_FILE, rollCount) -- บันทึกสถิติสุดท้าย
        break 
    end

    -- 1. เก็บของในแมพ
    local foundInMap = teleportToItems()
    
    -- 2. สุ่มของในตัว
    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        saveData(ROLL_FILE, rollCount) -- บันทึกจำนวนทุกครั้งที่สุ่ม
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8) -- รอตาม Flow
        
        pcall(function() 
            if player.Character:FindFirstChild("client_character_controller") then
                player.Character.client_character_controller.SummonStand:FireServer() 
            end
        end)
        task.wait(2)
    elseif not foundInMap then
        -- 3. ถ้าไม่มีของให้ Hop
        hopServer()
        break
    end
end
