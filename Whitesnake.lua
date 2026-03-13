repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- รอโฟลเดอร์สำคัญ
local inventory = player.PlayerGui:WaitForChild("Inventory")
local canvas = inventory:WaitForChild("CanvasGroup")
local backpack = canvas:WaitForChild("backpack_frame")
local enlarge = backpack:WaitForChild("enlarging_frame")
local holder = enlarge:WaitForChild("holder")

local liveFolder = workspace:WaitForChild("Live")

-- Remote
local useArrow = ReplicatedStorage
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

-- หา HumanoidRootPart
local function getRoot()
    local char = player.Character or player.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart")
end

-- เรียก Stand
local function summonStand()

    local char = player.Character or player.CharacterAdded:Wait()

    char:WaitForChild("client_character_controller")
    :WaitForChild("SummonStand")
    :FireServer()

end

-- อ่าน Stand
local function getStand()

    local char = liveFolder:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- ใช้ Stand Arrow
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- เช็คจำนวน Arrow
local function getArrowAmount()

    local slot = holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        return tonumber(text:match("%d+")) or 0
    end

    return 0
end

-- Server Hop
local function serverHop()

    warn("Server hopping...")
    TeleportService:Teleport(game.PlaceId)

end


while task.wait(2) do

    local amount = getArrowAmount()

    -- Arrow หมด
    if amount <= 0 then

        warn("Arrow empty, waiting 10 seconds before hop")

        task.wait(10)

        -- เช็คอีกครั้งกันบัค GUI
        if getArrowAmount() <= 0 then
            serverHop()
            break
        end

    end

    -- ใช้ Arrow
    rollStand()

    task.wait(2)

    -- เรียก Stand
    summonStand()

    task.wait(1)

    local stand = getStand()

    print("Current Stand:", stand)

    if stand == "Whitesnake" then

        warn("GOT WHITESNAKE")
        break

    end

end
