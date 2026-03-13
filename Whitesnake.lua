-- [[ 1. รอโหลดพื้นฐาน ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" -- ต้องมี https:// นำหน้า
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

-- [[ 2. ระบบจัดการไฟล์ ID Webhook (กันน้ำตก) ]]
local function saveMsgId(id) if writefile then pcall(function() writefile(FILE_NAME, id) end) end end
local function loadMsgId() if isfile and isfile(FILE_NAME) then local success, content = pcall(function() return readfile(FILE_NAME) end) return success and content or nil end return nil end
last_msg_id = loadMsgId()

-- [[ 3. ฟังก์ชันดึงค่าไอเทมในตัว ]]
local function getAmount(itemName)
    local amount = 0
    pcall(function()
        local inv = player.PlayerGui:FindFirstChild("Inventory")
        if inv then
            local item = inv.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild(itemName)
            if item then
                amount = tonumber(item.Holder.Holder.Number.Text:match("%d+")) or 0
            end
        end
    end)
    return amount
end

-- [[ 4. ฟังก์ชันวาร์ปเก็บไอเทมทั่วแมพ (Fast Teleport & Collect) ]]
local function teleportToItems()
    local itemFound = false
    for _, item in pairs(workspace:GetChildren()) do
        if item.Name == "Stand Arrow" or item.Name == "Lucky Arrow" then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root and (item:FindFirstChild("Handle") or item:IsA("BasePart")) then
                itemFound = true
                local targetPart = item:FindFirstChild("Handle") or item
                print("✨ วาร์ปไปเก็บ: " .. item.Name)
                
                -- วาร์ปไปที่ตำแหน่งไอเทมทันที
                root.CFrame = targetPart.CFrame
                task.wait(0.3) -- รอระบบฟิสิกส์เล็กน้อย
                
                -- กดเก็บผ่าน ProximityPrompt
                local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then 
                    fireproximityprompt(prompt) 
                end
                task.wait(0.5)
            end
        end
    end
    return itemFound
end

-- [[ 5. ระบบ Webhook Update ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    local data = {
        ["embeds"] = {{
            ["author"] = {["name"] = "Account: ||" .. player.Name .. "||", ["icon_url"] = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"},
            ["title"] = "✨ Whitesnake Monitor - Teleport Mode",
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

-- [[ 6. ระบบ Server Hop ]]
local function hopServer()
    local gameId = game.PlaceId
    local servers = {}
    local cursor = ""
    repeat
        local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. gameId .. "/servers/Public?sortOrder=Asc&limit=100&cursor=" .. cursor)) end)
        if success and result and result.data then
            for _, s in ipairs(result.data) do if s.playing < s.maxPlayers and s.id ~= game.JobId then table.insert(servers, s.id) end end
            cursor = result.nextPageCursor or ""
        else break end
    until cursor == "" or #servers >= 30
    if #servers > 0 then TeleportService:TeleportToPlaceInstance(gameId, servers[math.random(1, #servers)], player) end
end

-- [[ 7. Main Loop ทุก 3 วินาที ]]
while task.wait(3) do
    local currentStand = "None"
    pcall(function() currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None" end)
    
    updateWebhook(currentStand, (currentStand == "Whitesnake") and "SUCCESS" or "ROLLING")
    if currentStand == "Whitesnake" then break end

    -- 1. วาร์ปเก็บของในแมพก่อน
    local foundAny = teleportToItems()
    
    -- 2. เช็คของในกระเป๋าเพื่อทำการสุ่ม
    local arrows = getAmount("Stand Arrow")
    if arrows > 0 then
        rollCount = rollCount + 1
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(7)
        pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
        task.wait(2)
    elseif not foundAny then
        -- 3. ถ้าหาในแมพก็ไม่เจอ ในตัวก็ไม่มี ถึงจะ Hop
        print("No items in map or inventory. Hopping...")
        hopServer()
        break
    end
end
