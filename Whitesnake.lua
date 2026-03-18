-- [[ 1. CONFIGURATION ]]
local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-"

local USER_LIST = {
    [""] = { "Gold Experience", "Whitesnake" },
    [""] = { "XE", "YEID" },
}

-- [[ 2. SETUP & DATA ]]
repeat task.wait() until game:IsLoaded()
repeat task.wait() until game.Players.LocalPlayer.Character

local player = game.Players.LocalPlayer
local ROLL_FILE = "TotalRolls_" .. player.UserId .. ".txt"
local MSG_FILE = "WebhookID_" .. player.UserId .. ".txt"

local rollCount = isfile(ROLL_FILE) and tonumber(readfile(ROLL_FILE)) or 0
local last_msg_id = isfile(MSG_FILE) and readfile(MSG_FILE) or nil

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- [[ 3. WEBHOOK SYSTEM ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL:find("https://") then return end
    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    
    local data = {
        ["embeds"] = {{
            ["title"] = "✨ Gacha Monitor Status",
            ["description"] = "Account: ||" .. player.Name .. "||",
            ["color"] = (status == "SUCCESS") and 65280 or 16744448,
            ["fields"] = {
                {["name"] = "🧬 Current Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "🎯 Targets", ["value"] = "**" .. table.concat(targets, ", ") .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rerolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ FOUND!" or "🔄 Searching...", ["inline"] = false}
            },
            ["footer"] = { ["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X") }
        }}
    }

    local requestFunc = (syn and syn.request) or (http_request) or (request)
    local payload = HttpService:JSONEncode(data)

    if not last_msg_id then
        local res = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = payload})
        if res.Success then
            last_msg_id = HttpService:JSONDecode(res.Body).id
            writefile(MSG_FILE, last_msg_id)
        end
    else
        requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = payload})
    end
end

-- [[ 4. INFINITE SERVER HOP (แก้ไขจุดที่ค้าง) ]]
local function hopServer()
    print("🔄 เริ่มต้นการหาเซิร์ฟเวอร์ใหม่...")
    
    while task.wait() do -- วนลูปใหญ่เพื่อให้หาใหม่ได้เรื่อยๆ ถ้ายังไม่สำเร็จ
        local cursor = nil
        local currentJobId = game.JobId

        repeat
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
            if cursor then url = url .. "&cursor=" .. cursor end

            local success, result = pcall(function()
                return HttpService:JSONDecode(game:HttpGet(url))
            end)

            if success and result and result.data then
                for _, server in ipairs(result.data) do
                    -- เช็คเซิร์ฟเวอร์ที่คนไม่เต็ม และไม่ใช่เซิร์ฟเวอร์เดิม
                    if server.playing < server.maxPlayers and server.id ~= currentJobId then
                        print("🚀 พยายามวาร์ปไปเซิร์ฟเวอร์:", server.id)
                        local tele_success, _ = pcall(function()
                            TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, player)
                        end)
                        task.wait(2) -- ดีเลย์กันรัว
                        if tele_success then return end -- ถ้าสำเร็จให้หยุดลูป
                    end
                end
                cursor = result.nextPageCursor
            else
                print("⚠️ API Error หรือหาไม่เจอ รอ 5 วิ...")
                task.wait(5)
            end
        until not cursor
        
        print("❌ วนหาจนจบหน้าสุดท้ายแล้วยังไม่เจอ... กำลังเริ่มหาใหม่จากหน้าแรกใน 5 วินาที")
        task.wait(5) -- รอสักพักก่อนเริ่มหาหน้าแรกใหม่ เพื่อลดการติด Rate Limit
    end
end

-- [[ 5. MAIN LOGIC ]]
print("🎬 ระบบเริ่มทำงาน...")

-- Summon จนกว่าจะได้ค่า Stand
local currentStand = "None"
repeat
    print("⏳ พยายามเรียกแสตนด์เพื่อเช็คค่าปัจจุบัน...")
    pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
    task.wait(4)
    currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
until currentStand ~= "None"

print("✅ ยืนยันแสตนด์ปัจจุบันคือ: " .. currentStand)

while task.wait(3) do
    currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
    local targets = USER_LIST[player.Name] or { "Whitesnake" }
    
    local found = false
    for _, t in pairs(targets) do if currentStand == t then found = true break end end
    
    updateWebhook(currentStand, found and "SUCCESS" or "ROLLING")
    if found then print("🎉 ภารกิจสำเร็จ!") break end

    -- ฟังก์ชันเก็บของ
    for _, item in ipairs(workspace:GetDescendants()) do
        if (item.Name == "Stand Arrow" or item.Name == "Lucky Arrow") and item:FindFirstChildOfClass("ProximityPrompt") then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                root.CFrame = item:IsA("BasePart") and item.CFrame or item.Parent.CFrame
                task.wait(0.3)
                fireproximityprompt(item:FindFirstChildOfClass("ProximityPrompt"))
                task.wait(0.5)
            end
        end
    end

    local arrow = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")
    local amount = arrow and tonumber(arrow.Holder.Holder.Number.Text:match("%d+")) or 0
    
    if amount > 0 then
        rollCount = rollCount + 1
        writefile(ROLL_FILE, tostring(rollCount))
        print("🎲 รอบที่: " .. rollCount .. " | Stand: " .. currentStand)
        
        ReplicatedStorage.requests.character.use_item:FireServer("Stand Arrow")
        task.wait(8)
        
        repeat
            pcall(function() player.Character.client_character_controller.SummonStand:FireServer() end)
            task.wait(4)
            currentStand = workspace.Live[player.Name]:GetAttribute("SummonedStand") or "None"
        until currentStand ~= "None"
    else
        hopServer() -- จะวนหาไปเรื่อยๆ จนกว่าจะวาร์ปออกสำเร็จ
        break
    end
end
