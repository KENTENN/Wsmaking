-- [[ 1. ระบบรอโหลดเกมและตั้งค่าพื้นฐาน ]]
repeat task.wait() until game:IsLoaded()

local WEBHOOK_URL = "https://discord.com/api/webhooks/1479380422713409577/fTqx3VvsvwIQTked1qTNEoLQ_HVbaETnRjyEaVlrR0891T-NaMZJCel9zC3XBejPxJ9-" 
local FILE_NAME = "Gacha_ID_" .. game.Players.LocalPlayer.UserId .. ".txt"

local rollCount = 0 
local last_msg_id = nil

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

-- [[ 2. ระบบจัดการไฟล์ ID เพื่อป้องกันข้อความซ้ำ (น้ำตก) ]]
local function saveMsgId(id)
    if writefile then pcall(function() writefile(FILE_NAME, id) end) end
end

local function loadMsgId()
    if isfile and isfile(FILE_NAME) then
        local success, content = pcall(function() return readfile(FILE_NAME) end)
        return success and content or nil
    end
    return nil
end

last_msg_id = loadMsgId()

-- [[ 3. ฟังก์ชันดึงข้อมูลแบบปลอดภัย (Anti-Nil) ]]
local function getAmount(itemName)
    local success, result = pcall(function()
        local holder = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder
        local item = holder:FindFirstChild(itemName)
        return item.Holder.Holder.Number.Text
    end)
    return success and result or "0x"
end

local function getStand()
    local char = workspace.Live:FindFirstChild(player.Name)
    local val = char and char:GetAttribute("SummonedStand")
    return (val and val ~= "") and val or "None"
end

-- [[ 4. ระบบ Webhook Update (Admin Only + Icon + Live Stats) ]]
local function updateWebhook(standName, status)
    if not WEBHOOK_URL or not WEBHOOK_URL:find("http") then return end

    local headshotUrl = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. player.UserId .. "&width=150&height=150&format=png"
    
    local data = {
        ["embeds"] = {{
            ["author"] = {
                ["name"] = "Account: ||" .. player.Name .. "||", -- แอดมินดูได้เท่านั้น
                ["icon_url"] = headshotUrl -- ไอคอนหน้าตัวละคร
            },
            ["title"] = "✨ Whitesnake Gacha Monitor",
            ["color"] = (status == "SUCCESS") and 0x00ff00 or 0xff8c00,
            ["fields"] = {
                {["name"] = "🧬 Stand", ["value"] = "**" .. standName .. "**", ["inline"] = true},
                {["name"] = "📊 Total Rolls", ["value"] = "**" .. rollCount .. "**", ["inline"] = true},
                {["name"] = "🏹 Inventory", ["value"] = "Arrows: **" .. getAmount("Stand Arrow") .. "** | Lucky: **" .. getAmount("Lucky Arrow") .. "**", ["inline"] = false},
                {["name"] = "🚩 Status", ["value"] = (status == "SUCCESS") and "✅ **FOUND!**" or "🔄 **Rolling...**", ["inline"] = true}
            },
            ["footer"] = {["text"] = "Server: " .. game.JobId:sub(1,8) .. " | " .. os.date("%X")},
        }}
    }

    local jsonData = HttpService:JSONEncode(data)
    local requestFunc = (syn and syn.request) or (http_request) or (request)

    pcall(function()
        if not last_msg_id then
            local resp = requestFunc({Url = WEBHOOK_URL .. "?wait=true", Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
            if resp.Success then
                last_msg_id = HttpService:JSONDecode(resp.Body).id
                saveMsgId(last_msg_id)
            end
        else
            requestFunc({Url = WEBHOOK_URL .. "/messages/" .. last_msg_id, Method = "PATCH", Headers = {["Content-Type"] = "application/json"}, Body = jsonData})
        end
    end)
end

-- [[ 5. ฟังก์ชันการสุ่มอัตโนมัติ ]]
local function autoRoll()
    local useItem = ReplicatedStorage:WaitForChild("requests"):WaitForChild("character"):WaitForChild("use_item")
    local arrowStr = getAmount("Stand Arrow")
    local arrowAmt = tonumber(arrowStr:match("%d+")) or 0

    if arrowAmt > 0 then
        rollCount = rollCount + 1
        useItem:FireServer("Stand Arrow")
        task.wait(7) -- รออนิเมชั่นใช้ไอเทม
        
        -- เรียก Stand ออกมาเพื่อเช็คตัวล่าสุด
        local char = player.Character or player.CharacterAdded:Wait()
        local controller = char:FindFirstChild("client_character_controller")
        if controller and controller:FindFirstChild("SummonStand") then
            controller.SummonStand:FireServer()
        end
        task.wait(2)
    end
end

-- [[ 6. Main Execution Loop ทุก 3 วินาที ]]
print("Whitesnake Bot with Live Stats Started!")

while true do
    local currentStand = getStand()
    local isWS = (currentStand == "Whitesnake")

    -- อัปเดตข้อมูลไปยัง Discord
    updateWebhook(currentStand, isWS and "SUCCESS" or "ROLLING")

    -- ถ้าเจอเป้าหมายแล้วให้หยุด
    if isWS then 
        print("🎉 FOUND WHITESNAKE!")
        break 
    end

    -- ถ้ายังไม่เจอ ให้ทำการสุ่ม
    autoRoll()
    
    task.wait(3) -- หน่วงเวลา 3 วินาทีตามที่ต้องการ
end
