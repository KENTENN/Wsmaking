repeat task.wait() until game:IsLoaded()

-- [[ ตั้งค่า WEBHOOK ตรงนี้ ]] --
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local last_msg_id = nil 

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local placeId = game.PlaceId
local jobId = game.JobId

-- [[ Path Settings ]] --
local holder = player.PlayerGui:WaitForChild("Inventory"):WaitForChild("CanvasGroup"):WaitForChild("backpack_frame"):WaitForChild("enlarging_frame"):WaitForChild("holder")
local live = workspace:WaitForChild("Live")
local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")

-- [[ ฟังก์ชันเสริม ]] --

local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

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

-- ฟังก์ชันดึงจำนวนไอเทมแบบปลอดภัย (ป้องกัน nil)
local function getItemAmount(itemName)
    local slot = holder:FindFirstChild(itemName)
    if slot then
        local success, result = pcall(function()
            local text = slot.Holder.Holder.Number.Text
            return text:match("%d+") or "0"
        end)
        return success and result or "0"
    end
    return "0"
end

-- [[ ฟังก์ชัน Webhook แบบ Update ข้อความเดิม ]] --
local function sendWebhookUpdate(standName, status)
    local arrowCount = getItemAmount("Stand Arrow")
    local luckyCount = getItemAmount("Lucky Arrow")
    
    local data = {
        ["embeds"] = {{
            ["title"] = "✨ Stand Gacha Live Monitor",
            ["description"] = "กำลังอัปเดตสถานะการฟาร์มแบบ Real-time",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "👤 Player", ["value"] = "||" .. player.Name .. "||", ["inline"] = true},
                {["name"] = "🧬 Current Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Stand Arrows: **" .. arrowCount .. "**\nLucky Arrows: **" .. luckyCount .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ **FOUND WHITESNAKE!**" or "🔄 **Rolling...**", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. jobId .. " | Last Update: " .. os.date("%X")},
            ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
        }}
    }

    local jsonData = HttpService:JSONEncode(data)
    local requestFunc = (syn and syn.request) or (http_request) or (request)
    
    if not last_msg_id then
        local response = requestFunc({
            Url = WEBHOOK_URL .. "?wait=true",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
        if response and response.Success then
            local decoded = HttpService:JSONDecode(response.Body)
            last_msg_id = decoded.id
        end
    else
        requestFunc({
            Url = WEBHOOK_URL .. "/messages/" .. last_msg_id,
            Method = "PATCH",
            Headers = {["Content-Type"] = "application/json"},
            Body = jsonData
        })
    end
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
        root.CFrame = arrow.CFrame + Vector3.new(0, 3, 0)
        task.wait(0.5)
        local prompt = arrow:FindFirstChildWhichIsA("ProximityPrompt", true)
        if prompt then fireproximityprompt(prompt) end
        return true
    end
    return false
end

local function serverHop()
    warn("Arrows/Items ran out. Hopping to new server...")
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
        end
        task.wait(1)
    end
end

-- [[ Main Logic ]] --

print("--- [ Full Script Started ] ---")
task.wait(5)

-- เช็คตอนเริ่ม
if isWhitesnake() then
    sendWebhookUpdate(getStand(), "SUCCESS")
    return
end

while task.wait(1) do
    -- 1. เช็คเป้าหมายก่อนทุกครั้ง
    if isWhitesnake() then
        sendWebhookUpdate(getStand(), "SUCCESS")
        warn("FOUND WHITESNAKE!")
        break
    end

    -- 2. หาในแมพก่อน
    local arrowInMap = findArrow()
    if arrowInMap then
        print("Action: Found Arrow in Map, Collecting...")
        collectArrow()
        task.wait(2)
    else
        -- 3. ถ้าในแมพไม่มี เช็คในตัว
        local arrowAmt = tonumber(getItemAmount("Stand Arrow")) or 0
        if arrowAmt > 0 then
            print("Action: Using Arrow from Inventory (Left: " .. arrowAmt .. ")")
            useItem:FireServer("Stand Arrow")
            
            task.wait(8) -- เวลากดใช้
            
            -- เรียก Stand
            local char = player.Character or player.CharacterAdded:Wait()
            local controller = char:FindFirstChild("client_character_controller")
            if controller and controller:FindFirstChild("SummonStand") then
                controller.SummonStand:FireServer()
            end
            
            task.wait(2)
            local res = getStand()
            print("Result: " .. res)
            
            -- อัปเดต Discord (Edit ข้อความเดิม)
            if isWhitesnake() then
                sendWebhookUpdate(res, "SUCCESS")
                break
            else
                sendWebhookUpdate(res, "ROLLING")
            end
        else
            -- 4. ไม่มีของเลยจริงๆ
            task.wait(2)
            if not findArrow() then
                serverHop()
                break
            end
        end
    end
end
