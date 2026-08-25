--[[
    MM2 SPAWNER GUI -- ScreenGui build (rounded, animated border, native drag)
    Premium knives & guns | purple SPAWN button | RightShift or circle to toggle
    Loads after the mesh system -- expects game services available.
]]

local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local RS               = game:GetService("ReplicatedStorage")

-- cleanup previous instance
if _G._MM2GuiClean then pcall(_G._MM2GuiClean) end

print("[MM2 Spawner] GUI script starting...")

-- =========================================================
--  GAME DATA  (timeouts so a wrong path fails loudly)
-- =========================================================
local dbOk, WeaponDB = pcall(function()
    return require(RS:WaitForChild("Database", 10):WaitForChild("Sync", 10)).Weapons
end)
if not dbOk or type(WeaponDB) ~= "table" then
    warn("[MM2 Spawner] Could not load WeaponDB (ReplicatedStorage.Database.Sync.Weapons): " .. tostring(WeaponDB))
    return
end

local pdOk, ProfileData = pcall(function()
    return require(RS:WaitForChild("Modules", 10):WaitForChild("ProfileData", 10))
end)
if not pdOk or type(ProfileData) ~= "table" then
    warn("[MM2 Spawner] Could not load ProfileData (ReplicatedStorage.Modules.ProfileData): " .. tostring(ProfileData))
    return
end

local InvDataChanged = select(2, pcall(function()
    return RS:WaitForChild("Remotes", 10):WaitForChild("Inventory", 10):WaitForChild("InventoryDataChanged", 10)
end))
if not InvDataChanged then
    warn("[MM2 Spawner] InventoryDataChanged remote not found -- spawns won't refresh inventory.")
end

-- =========================================================
--  WEAPONS  (premium knives & guns only)
-- =========================================================
local PREMIUM_RARITIES = {
    Evo = true, Ancient = true, Vintage = true,
    Chroma = true, Godly = true, Legendary = true,
}

local rarityColors = {
    Godly     = Color3.fromRGB(255, 50, 50),
    Ancient   = Color3.fromRGB(255, 200, 50),
    Vintage   = Color3.fromRGB(100, 180, 255),
    Chroma    = Color3.fromRGB(150, 100, 255),
    Evo       = Color3.fromRGB(50, 255, 150),
    Legendary = Color3.fromRGB(200, 100, 255),
}

-- Rarest -> least. Lower number = rarer = higher in the list.
local rarityRank = {
    Vintage = 1, Ancient = 2, Chroma = 3, Evo = 4, Godly = 5, Legendary = 6,
}

local weapons = {}
for name, data in pairs(WeaponDB) do
    if type(name) == "string" and type(data) == "table" then
        local rarity = data.Rarity or "Common"
        local wType  = data.Type or "Knife"
        if PREMIUM_RARITIES[rarity] and (wType == "Knife" or wType == "Gun") then
            weapons[#weapons + 1] = { name = name, rarity = rarity, type = wType }
        end
    end
end
table.sort(weapons, function(a, b)
    local ra, rb = rarityRank[a.rarity] or 99, rarityRank[b.rarity] or 99
    if ra ~= rb then return ra < rb end   -- rarest first
    return a.name < b.name                -- then alphabetical within a rarity
end)

-- spawn: MUST match the mesh system exactly -- write a COUNT to
-- ProfileData.Weapons.Owned and fire the refresh event.
local function spawnWeapon(weaponName, amount)
    amount = amount or 1
    local owned = ProfileData.Weapons.Owned
    owned[weaponName] = (owned[weaponName] or 0) + amount
    if InvDataChanged then
        pcall(function() InvDataChanged:Fire("Weapons", weaponName, owned[weaponName]) end)
    end
    print("[MM2 Spawner] Spawned:", weaponName)
end

-- =========================================================
--  BUILD GUI
-- =========================================================
local conns = {}   -- disconnected on cleanup
local function track(c) conns[#conns + 1] = c; return c end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MM2SpawnerGUI"
ScreenGui.IgnoreGuiInset = false
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() ScreenGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not ScreenGui.Parent then
    ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
end

-- cleanup handle
_G._MM2GuiClean = function()
    for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
    pcall(function() ScreenGui:Destroy() end)
end

-- ---- floating toggle circle -------------------------------------------------
local CircleToggle = Instance.new("TextButton")
CircleToggle.Size = UDim2.new(0, 38, 0, 38)
CircleToggle.Position = UDim2.new(0, 16, 0.5, -19)
CircleToggle.BackgroundColor3 = Color3.fromRGB(35, 30, 55)
CircleToggle.BorderSizePixel = 0
CircleToggle.Text = ""
CircleToggle.AutoButtonColor = false
CircleToggle.ZIndex = 100
CircleToggle.Parent = ScreenGui
Instance.new("UICorner", CircleToggle).CornerRadius = UDim.new(1, 0)

local CircleStroke = Instance.new("UIStroke", CircleToggle)
CircleStroke.Thickness = 1.5
CircleStroke.Color = Color3.fromRGB(90, 70, 160)
CircleStroke.Transparency = 0.3

local CircleIcon = Instance.new("TextLabel", CircleToggle)
CircleIcon.Size = UDim2.new(1, 0, 1, 0)
CircleIcon.BackgroundTransparency = 1
CircleIcon.Text = "MM2"
CircleIcon.Font = Enum.Font.GothamBold
CircleIcon.TextSize = 11
CircleIcon.TextColor3 = Color3.fromRGB(180, 160, 255)
CircleIcon.ZIndex = 101

-- ---- main frame -------------------------------------------------------------
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ZIndex = 1
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Thickness = 2

local BorderGradient = Instance.new("UIGradient", MainStroke)
BorderGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0,   Color3.fromRGB(0,   210, 80)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 50,  210)),
    ColorSequenceKeypoint.new(1,   Color3.fromRGB(0,   210, 80)),
}

-- animated border (rotate + breathe) and circle hue
local borderBreath, borderDir = 0, 1
track(RunService.Heartbeat:Connect(function(dt)
    BorderGradient.Rotation = (BorderGradient.Rotation + dt * 40) % 360
    borderBreath = borderBreath + dt * borderDir * 0.7
    if borderBreath >= 1 then borderBreath, borderDir = 1, -1
    elseif borderBreath <= 0 then borderBreath, borderDir = 0, 1 end
    MainStroke.Transparency = borderBreath * 0.45
    CircleStroke.Color = Color3.fromHSV((tick() * 0.1) % 1, 0.5, 0.7)
end))

-- ---- title bar --------------------------------------------------------------
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.ZIndex = 2
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local TitleCover = Instance.new("Frame", TitleBar)
TitleCover.Size = UDim2.new(1, 0, 0, 12)
TitleCover.Position = UDim2.new(0, 0, 1, -12)
TitleCover.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
TitleCover.BorderSizePixel = 0
TitleCover.ZIndex = 2

local Title = Instance.new("TextLabel", TitleBar)
Title.Text = "MM2 SPAWNER"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 12
Title.TextColor3 = Color3.fromRGB(180, 160, 255)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 12, 0, 0)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 3

local function makeTitleBtn(text, xOff, textSize)
    local b = Instance.new("TextButton", TitleBar)
    b.Size = UDim2.new(0, 20, 0, 20)
    b.Position = UDim2.new(1, xOff, 0.5, -10)
    b.Text = text
    b.Font = Enum.Font.GothamBold
    b.TextSize = textSize or 12
    b.TextColor3 = Color3.fromRGB(180, 180, 200)
    b.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
    b.BorderSizePixel = 0
    b.AutoButtonColor = false
    b.ZIndex = 5
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 5)
    local isClose = text == "X"
    track(b.MouseEnter:Connect(function()
        local c = isClose and Color3.fromRGB(180, 60, 60) or Color3.fromRGB(50, 50, 68)
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = c}):Play()
    end))
    track(b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(35, 35, 48)}):Play()
    end))
    return b
end

local MinBtn   = makeTitleBtn("-", -46, 14)
local CloseBtn = makeTitleBtn("X", -24, 11)

local guiVisible = true
local function setVisible(v)
    guiVisible = v
    MainFrame.Visible = v
    CircleToggle.BackgroundColor3 = v and Color3.fromRGB(35, 30, 55) or Color3.fromRGB(55, 45, 80)
end
track(CloseBtn.MouseButton1Click:Connect(function() setVisible(false) end))
track(MinBtn.MouseButton1Click:Connect(function() setVisible(false) end))

-- ---- search box -------------------------------------------------------------
local SearchBox = Instance.new("TextBox", MainFrame)
SearchBox.Size = UDim2.new(1, -16, 0, 30)
SearchBox.Position = UDim2.new(0, 8, 0, 42)
SearchBox.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
SearchBox.BorderSizePixel = 0
SearchBox.PlaceholderText = "Search weapons..."
SearchBox.PlaceholderColor3 = Color3.fromRGB(120, 100, 160)
SearchBox.Text = ""
SearchBox.Font = Enum.Font.Gotham
SearchBox.TextSize = 12
SearchBox.TextColor3 = Color3.fromRGB(180, 160, 255)
SearchBox.TextXAlignment = Enum.TextXAlignment.Left
SearchBox.ClearTextOnFocus = false
SearchBox.ZIndex = 3
Instance.new("UICorner", SearchBox).CornerRadius = UDim.new(0, 6)
local sbStroke = Instance.new("UIStroke", SearchBox)
sbStroke.Thickness = 1; sbStroke.Color = Color3.fromRGB(140, 50, 210); sbStroke.Transparency = 0.3
local sbPad = Instance.new("UIPadding", SearchBox)
sbPad.PaddingLeft = UDim.new(0, 8); sbPad.PaddingRight = UDim.new(0, 8)

-- ---- filters ----------------------------------------------------------------
local filterType, filterRarity = "All", "All"

-- dropdown builder: a button that opens a menu of items below it.
-- onPick(value) fires when an item is chosen. Opening one closes the others.
local dropdownClosers = {}
local function makeDropdown(label, xScale, xOff, width, items, onPick)
    local btn = Instance.new("TextButton", MainFrame)
    btn.Size = UDim2.new(0, width, 0, 30)
    btn.Position = UDim2.new(xScale, xOff, 0, 80)
    btn.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
    btn.BorderSizePixel = 0
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.ZIndex = 3
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    local st = Instance.new("UIStroke", btn)
    st.Thickness = 1; st.Color = Color3.fromRGB(42, 46, 58); st.Transparency = 0.2

    local lbl = Instance.new("TextLabel", btn)
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 8, 0, 0)
    lbl.Text = label
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextColor3 = Color3.fromRGB(110, 115, 135)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex = 4

    local val = Instance.new("TextLabel", btn)
    val.BackgroundTransparency = 1
    val.Size = UDim2.new(0.5, -22, 1, 0)
    val.Position = UDim2.new(0.5, 0, 0, 0)
    val.Text = "All"
    val.Font = Enum.Font.GothamBold
    val.TextSize = 11
    val.TextColor3 = Color3.fromRGB(0, 210, 80)
    val.TextXAlignment = Enum.TextXAlignment.Right
    val.ZIndex = 4

    local arrow = Instance.new("TextLabel", btn)
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -18, 0, 0)
    arrow.Text = "v"
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 10
    arrow.TextColor3 = Color3.fromRGB(110, 115, 135)
    arrow.ZIndex = 4

    -- menu (absolute, high ZIndex so it floats over the list)
    local menu = Instance.new("Frame", MainFrame)
    menu.Position = UDim2.new(xScale, xOff, 0, 112)
    menu.Size = UDim2.new(0, width, 0, #items * 24 + 4)
    menu.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
    menu.BorderSizePixel = 0
    menu.Visible = false
    menu.ZIndex = 50
    Instance.new("UICorner", menu).CornerRadius = UDim.new(0, 6)
    local mst = Instance.new("UIStroke", menu)
    mst.Thickness = 1; mst.Color = Color3.fromRGB(0, 180, 70); mst.Transparency = 0.2

    for i, item in ipairs(items) do
        local it = Instance.new("TextButton", menu)
        it.Size = UDim2.new(1, -6, 0, 22)
        it.Position = UDim2.new(0, 3, 0, 2 + (i - 1) * 24)
        it.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
        it.BackgroundTransparency = 1
        it.BorderSizePixel = 0
        it.Text = item
        it.Font = Enum.Font.Gotham
        it.TextSize = 11
        it.TextColor3 = Color3.fromRGB(200, 200, 220)
        it.TextXAlignment = Enum.TextXAlignment.Left
        it.AutoButtonColor = false
        it.ZIndex = 51
        Instance.new("UICorner", it).CornerRadius = UDim.new(0, 4)
        local ip = Instance.new("UIPadding", it); ip.PaddingLeft = UDim.new(0, 8)
        track(it.MouseEnter:Connect(function() it.BackgroundTransparency = 0.3 end))
        track(it.MouseLeave:Connect(function() it.BackgroundTransparency = 1 end))
        track(it.MouseButton1Click:Connect(function()
            val.Text = item
            menu.Visible = false
            arrow.Text = "v"
            onPick(item)
        end))
    end

    local function close() menu.Visible = false; arrow.Text = "v" end
    dropdownClosers[#dropdownClosers + 1] = close

    track(btn.MouseButton1Click:Connect(function()
        local opening = not menu.Visible
        for _, c in ipairs(dropdownClosers) do c() end   -- close all first
        menu.Visible = opening
        arrow.Text = opening and "^" or "v"
    end))

    return { close = close }
end

local innerW = 320 - 16          -- padding 8 each side
local ddW = (innerW - 6) / 2

-- ---- weapon list ------------------------------------------------------------
local Scroll = Instance.new("ScrollingFrame", MainFrame)
Scroll.Size = UDim2.new(1, -16, 0, 220)
Scroll.Position = UDim2.new(0, 8, 0, 118)
Scroll.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = Color3.fromRGB(0, 180, 70)
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ZIndex = 2
Instance.new("UICorner", Scroll).CornerRadius = UDim.new(0, 6)
local scStroke = Instance.new("UIStroke", Scroll)
scStroke.Thickness = 1; scStroke.Color = Color3.fromRGB(42, 46, 58); scStroke.Transparency = 0.3
local listLayout = Instance.new("UIListLayout", Scroll)
listLayout.Padding = UDim.new(0, 3)
local scPad = Instance.new("UIPadding", Scroll)
scPad.PaddingTop = UDim.new(0, 4); scPad.PaddingLeft = UDim.new(0, 4)
scPad.PaddingRight = UDim.new(0, 4); scPad.PaddingBottom = UDim.new(0, 4)

local selectedWeapon = nil
local rowButtons = {}

-- ---- status + spawn ---------------------------------------------------------
local StatusLbl = Instance.new("TextLabel", MainFrame)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Size = UDim2.new(1, -96, 0, 16)
StatusLbl.Position = UDim2.new(0, 8, 0, 342)
StatusLbl.Text = "No weapon selected"
StatusLbl.Font = Enum.Font.Gotham
StatusLbl.TextSize = 11
StatusLbl.TextColor3 = Color3.fromRGB(110, 115, 135)
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.TextTruncate = Enum.TextTruncate.AtEnd
StatusLbl.ZIndex = 3

local CountLbl = Instance.new("TextLabel", MainFrame)
CountLbl.BackgroundTransparency = 1
CountLbl.Size = UDim2.new(0, 80, 0, 16)
CountLbl.Position = UDim2.new(1, -88, 0, 342)
CountLbl.Text = "0/" .. #weapons
CountLbl.Font = Enum.Font.Gotham
CountLbl.TextSize = 11
CountLbl.TextColor3 = Color3.fromRGB(0, 150, 55)
CountLbl.TextXAlignment = Enum.TextXAlignment.Right
CountLbl.ZIndex = 3

local SpawnBtn = Instance.new("TextButton", MainFrame)
SpawnBtn.Size = UDim2.new(1, -16, 0, 34)
SpawnBtn.Position = UDim2.new(0, 8, 0, 362)
SpawnBtn.BackgroundColor3 = Color3.fromRGB(38, 24, 50)
SpawnBtn.BorderSizePixel = 0
SpawnBtn.Text = "SELECT A WEAPON"
SpawnBtn.Font = Enum.Font.GothamBold
SpawnBtn.TextSize = 13
SpawnBtn.TextColor3 = Color3.fromRGB(120, 115, 135)
SpawnBtn.AutoButtonColor = false
SpawnBtn.ZIndex = 3
Instance.new("UICorner", SpawnBtn).CornerRadius = UDim.new(0, 8)
local spStroke = Instance.new("UIStroke", SpawnBtn)
spStroke.Thickness = 1; spStroke.Color = Color3.fromRGB(90, 40, 150); spStroke.Transparency = 0.4

local function refreshSpawnBtn()
    if selectedWeapon then
        SpawnBtn.Text = "SPAWN"
        SpawnBtn.BackgroundColor3 = Color3.fromRGB(140, 50, 210)
        SpawnBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        spStroke.Transparency = 0.1
        StatusLbl.Text = "Selected: " .. selectedWeapon.name
        StatusLbl.TextColor3 = Color3.fromRGB(0, 210, 80)
    else
        SpawnBtn.Text = "SELECT A WEAPON"
        SpawnBtn.BackgroundColor3 = Color3.fromRGB(38, 24, 50)
        SpawnBtn.TextColor3 = Color3.fromRGB(120, 115, 135)
        spStroke.Transparency = 0.4
        StatusLbl.Text = "No weapon selected"
        StatusLbl.TextColor3 = Color3.fromRGB(110, 115, 135)
    end
end

track(SpawnBtn.MouseEnter:Connect(function()
    if selectedWeapon then
        TweenService:Create(SpawnBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(170, 70, 240)}):Play()
    end
end))
track(SpawnBtn.MouseLeave:Connect(function()
    if selectedWeapon then
        TweenService:Create(SpawnBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(140, 50, 210)}):Play()
    end
end))
track(SpawnBtn.MouseButton1Click:Connect(function()
    if selectedWeapon then
        spawnWeapon(selectedWeapon.name)
        StatusLbl.Text = "Spawned: " .. selectedWeapon.name
        StatusLbl.TextColor3 = Color3.fromRGB(0, 210, 80)
    end
end))

-- ---- watermark (animated rainbow branding) ---------------------------------
local ytLabel = "bloomscripts on youtube"
local ytChars = {}
local ytContainer = Instance.new("Frame", MainFrame)
ytContainer.Size = UDim2.new(1, 0, 0, 12)
ytContainer.Position = UDim2.new(0, 0, 1, -14)
ytContainer.BackgroundTransparency = 1
ytContainer.ZIndex = 3
local wl = Instance.new("UIListLayout", ytContainer)
wl.FillDirection = Enum.FillDirection.Horizontal
wl.HorizontalAlignment = Enum.HorizontalAlignment.Center
wl.SortOrder = Enum.SortOrder.LayoutOrder
for i = 1, #ytLabel do
    local ch = Instance.new("TextLabel", ytContainer)
    ch.Text = ytLabel:sub(i, i)
    ch.Font = Enum.Font.GothamBold
    ch.TextSize = 9
    ch.BackgroundTransparency = 1
    ch.Size = UDim2.new(0, ytLabel:sub(i, i) == " " and 3 or 6, 1, 0)
    ch.ZIndex = 3
    ch.LayoutOrder = i
    ytChars[#ytChars + 1] = ch
end
local ytHue = 0
track(RunService.Heartbeat:Connect(function(dt)
    ytHue = (ytHue + dt * 0.4) % 1
    for i, ch in ipairs(ytChars) do
        ch.TextColor3 = Color3.fromHSV((ytHue + (i - 1) / #ytChars) % 1, 0.7, 1)
    end
end))

-- =========================================================
--  LIST BUILD + FILTER
-- =========================================================
local function matches(w)
    local s = SearchBox.Text
    if s ~= "" and not w.name:lower():find(s:lower(), 1, true) then return false end
    if filterType ~= "All" and w.type ~= filterType then return false end
    if filterRarity ~= "All" and w.rarity ~= filterRarity then return false end
    return true
end

local function selectRow(row, weapon)
    selectedWeapon = weapon
    for _, r in ipairs(rowButtons) do
        r.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
        local st = r:FindFirstChildWhichIsA("UIStroke")
        if st then st.Color = Color3.fromRGB(42, 46, 58); st.Transparency = 0.3 end
    end
    row.BackgroundColor3 = Color3.fromRGB(32, 24, 50)
    local st = row:FindFirstChildWhichIsA("UIStroke")
    if st then st.Color = Color3.fromRGB(140, 80, 220); st.Transparency = 0 end
    refreshSpawnBtn()
end

local function rebuild()
    for _, r in ipairs(rowButtons) do r:Destroy() end
    rowButtons = {}
    selectedWeapon = nil
    refreshSpawnBtn()

    local shown = 0
    for _, w in ipairs(weapons) do
        if matches(w) then
            shown = shown + 1
            local row = Instance.new("TextButton", Scroll)
            row.Size = UDim2.new(1, 0, 0, 28)
            row.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
            row.BorderSizePixel = 0
            row.Text = ""
            row.AutoButtonColor = false
            row.ZIndex = 3
            row.LayoutOrder = shown
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)
            local rst = Instance.new("UIStroke", row)
            rst.Thickness = 1; rst.Color = Color3.fromRGB(42, 46, 58); rst.Transparency = 0.3

            local nLbl = Instance.new("TextLabel", row)
            nLbl.BackgroundTransparency = 1
            nLbl.Size = UDim2.new(1, -140, 1, 0)
            nLbl.Position = UDim2.new(0, 8, 0, 0)
            nLbl.Text = w.name
            nLbl.Font = Enum.Font.GothamBold
            nLbl.TextSize = 11
            nLbl.TextColor3 = Color3.fromRGB(225, 225, 235)
            nLbl.TextXAlignment = Enum.TextXAlignment.Left
            nLbl.TextTruncate = Enum.TextTruncate.AtEnd
            nLbl.ZIndex = 4

            local rLbl = Instance.new("TextLabel", row)
            rLbl.BackgroundTransparency = 1
            rLbl.Size = UDim2.new(0, 80, 1, 0)
            rLbl.Position = UDim2.new(1, -128, 0, 0)
            rLbl.Text = w.rarity
            rLbl.Font = Enum.Font.GothamBold
            rLbl.TextSize = 10
            rLbl.TextColor3 = rarityColors[w.rarity] or Color3.fromRGB(110, 115, 135)
            rLbl.TextXAlignment = Enum.TextXAlignment.Right
            rLbl.ZIndex = 4

            local tLbl = Instance.new("TextLabel", row)
            tLbl.BackgroundTransparency = 1
            tLbl.Size = UDim2.new(0, 40, 1, 0)
            tLbl.Position = UDim2.new(1, -44, 0, 0)
            tLbl.Text = w.type
            tLbl.Font = Enum.Font.Gotham
            tLbl.TextSize = 10
            tLbl.TextColor3 = Color3.fromRGB(110, 115, 135)
            tLbl.TextXAlignment = Enum.TextXAlignment.Right
            tLbl.ZIndex = 4

            track(row.MouseEnter:Connect(function()
                if selectedWeapon ~= w then row.BackgroundColor3 = Color3.fromRGB(30, 30, 42) end
            end))
            track(row.MouseLeave:Connect(function()
                if selectedWeapon ~= w then row.BackgroundColor3 = Color3.fromRGB(25, 25, 34) end
            end))
            local function pick() selectRow(row, w) end
            track(row.MouseButton1Click:Connect(pick))
            track(row.TouchTap:Connect(pick))
            rowButtons[#rowButtons + 1] = row
        end
    end

    CountLbl.Text = shown .. "/" .. #weapons
end

makeDropdown("Type", 0, 8, ddW, {"All", "Knife", "Gun"}, function(v)
    filterType = v; rebuild()
end)
makeDropdown("Rarity", 0, 8 + ddW + 6, ddW,
    {"All", "Vintage", "Ancient", "Chroma", "Evo", "Godly", "Legendary"}, function(v)
        filterRarity = v; rebuild()
    end)

track(SearchBox:GetPropertyChangedSignal("Text"):Connect(rebuild))

rebuild()

-- =========================================================
--  DRAG + TOGGLE
-- =========================================================
local function makeDraggable(handle, frame)
    local dragging, dragStart, startPos = false, nil, nil
    track(handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = frame.Position
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end
makeDraggable(TitleBar, MainFrame)
makeDraggable(CircleToggle, CircleToggle)

track(CircleToggle.MouseButton1Click:Connect(function() setVisible(not guiVisible) end))

track(UserInputService.InputBegan:Connect(function(input, gp)
    if not gp and input.KeyCode == Enum.KeyCode.RightShift then
        setVisible(not guiVisible)
    end
end))

print("[MM2 Spawner] GUI loaded! RightShift or the MM2 circle toggles it.")
print("[MM2 Spawner] Found " .. #weapons .. " premium weapons (Knives & Guns only)")
