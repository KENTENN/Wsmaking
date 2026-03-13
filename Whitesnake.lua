-- [[ 1. Setup & Wait for Load ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- [[ 2. Webhook ID Management ]]
local function saveMsgId(id) if writefile then pcall(function() writefile(FILE_NAME, id) end) end end
local function loadMsgId() if isfile and isfile(FILE_NAME) then local success, content = pcall(function() return readfile(FILE_NAME) end) return success and content or nil end return nil end
last_msg_id = loadMsgId()

-- [[ 3. Inventory Check (แก้บัคดึงค่าไม่ได้) ]]
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

-- [[ 4. Teleport & Collect (เจาะจง Workspace Model ตามภาพ) ]]
local function teleportToItems()
    local itemFound = false
    -- ใช้ GetDescendants เพื่อหาใน Model
    local allObjects = workspace:GetDescendants()
    
    for _, item in pairs(allObjects) do
        -- แก้บัค Index Nil โดยการเช็ค item.Parent ก่อนเสมอ
        if item and item.Parent and (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") then
            local success, err = pcall(function()
                local prompt = item:FindFirstChildOfClass("ProximityPrompt") or item.Parent:FindFirstChildOfClass("ProximityPrompt")
                
                if prompt then
                    local char = player.Character
                    local root = char and char:FindFirstChild("HumanoidRootPart")
                    
                    if root then
                        -- ดึงตำแหน่ง CFrame จากตัววัตถุหรือ Parent ของมัน
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

-- [[ 5. Discord Webhook Update ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Final Edition",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
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
            if resp.Success then last_msg_id = HttpService:JSONDecode(resp.Body).id saveMsgId(last_msg_id) end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 6. Server Hop (ฟังก์ชันที่คุณส่งมาตอนแรก) ]]
local function hopServer()
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

-- [[ 7. Main Execution Loop (ตาม Flowchart เป๊ะๆ) ]]
while task.wait(3) do
    -- เช็ค Stand ปัจจุบัน
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    
    -- ถ้ามี Whitesnake -> หยุด
    if currentStand == "Whitesnake" then 
        print("🎉 พบ Whitesnake แล้ว! หยุดการทำงาน")
        break 
    end

    -- 1. หา Arrow ในแมพ (วาร์ปเก็บ)
    local foundInMap = teleportToItems()
    
    -- 2. เช็ค Arrow ในตัว
    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8) -- รอ 8 วิ ตาม Flowchart
        pcall(function() 
            if player.Character:FindFirstChild("client_character_controller") then
                player.Character.client_character_controller.SummonStand:FireServer() 
            end
        end)
        task.wait(2)
    elseif not foundInMap then
        -- 3. ถ้าไม่มีทั้งในแมพและในตัว -> Hop
        print("ไม่พบไอเทมเพิ่ม ย้ายเซิร์ฟเวอร์...")
        hopServer()
        break
    end
end
