repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local player = Players.LocalPlayer

local useArrow = game:GetService("ReplicatedStorage")
:WaitForChild("requests")
:WaitForChild("character")
:WaitForChild("use_item")

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

-- อ่านชื่อ Stand
local function getStand()

    local live = workspace:WaitForChild("Live")

    local char = live:FindFirstChild(player.Name)

    if char then
        return char:GetAttribute("SummonedStand")
    end

end

-- ใช้ Stand Arrow
local function rollStand()

    local args = {"Stand Arrow"}
    useArrow:FireServer(unpack(args))

end

-- server hop
local function serverHop()

    TeleportService:Teleport(game.PlaceId)

end

while task.wait(2) do

    local amount = 0

    local slot = player.PlayerGui.Inventory.CanvasGroup.backpack_frame.enlarging_frame.holder:FindFirstChild("Stand Arrow")

    if slot then
        local text = slot.Holder.Holder.Number.Text
        amount = tonumber(text:match("%d+")) or 0
    end

    if amount <= 0 then
        warn("No Arrow -> Server Hop")
        serverHop()
        break
    end

    -- ใช้ Arrow
    rollStand()

    task.wait(2)

    -- เรียก Stand
    summonStand()

    task.wait(1)

    local stand = getStand()

    print("Stand:",stand)

    if stand == "Whitesnake" then

        warn("GOT WHITESNAKE")
        break

    end

end
