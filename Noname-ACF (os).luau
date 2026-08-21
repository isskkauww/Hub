-- Variables & Service
if not game:IsLoaded() then game.Loaded:Wait() end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerChar = LocalPlayer.Character
local playerHum = playerChar and playerChar:FindFirstChildOfClass("Humanoid")
local playerHRP = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
local Event = ReplicatedStorage.Remotes.GradeRollRE
local TraitEvent = ReplicatedStorage.Remotes.TraitRollRE
local IsGradeRunning = false
local IsTraitRunning = false
local LocalPlot = workspace.MAP.Plots[tostring(LocalPlayer.PlotNumber.Value)]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

-- Icon Module
local IconsLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/Main-v2.lua"))()

local function GetAsset(IconName)
	if not IconsLib or type(IconName) ~= "string" or IconName == "" then
		return nil
	end

	local ok, result = pcall(IconsLib.GetIcon, IconName)
	if not ok or result == nil then
		return nil
	end

	if type(result) == "string" then
		return {
			Url = result,
			IconName = IconName,
			ImageRectSize = Vector2.zero,
			ImageRectOffset = Vector2.zero,
		}
	end

	if type(result) == "table" and result[1] and result[2] then
		local info = result[2]
		return {
			Url = tostring(result[1]),
			IconName = IconName,
			ImageRectSize = info.ImageRectSize or Vector2.zero,
			ImageRectOffset = info.ImageRectPosition or Vector2.zero,
		}
	end
end

Library:SetIconModule({ Icons = {}, GetAsset = GetAsset })

-- Loading Screen
local Loading = Library:CreateLoading({
	Title = "Noname | ACF",
	Icon = "lucide:atom",
	TotalSteps = 12,
})

Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("Hello " .. LocalPlayer.Name .. "!")
Loading.Sidebar:AddLabel("Plot: " .. tostring(LocalPlayer.PlotNumber.Value))

task.spawn(function()
	Loading:SetCurrentStep(1)
	Loading:SetMessage("Initializing Environment...")
	task.wait(0.25)

	Loading:SetCurrentStep(2)
	Loading:SetMessage("Loading UI Library...")
	task.wait(0.25)

	Loading:SetCurrentStep(3)
	Loading:SetMessage("Loading Icon Pack...")
	task.wait(0.25)

	Loading:SetCurrentStep(4)
	Loading:SetMessage("Establishing Remote Connections...")
	task.wait(0.25)

	Loading:SetCurrentStep(5)
	Loading:SetMessage("Caching Inventory...")
	task.wait(0.3)

	Loading:SetCurrentStep(6)
	Loading:SetMessage("Indexing Cards...")
	task.wait(0.3)

	Loading:SetCurrentStep(7)
	Loading:SetMessage("Preparing Grade Roller...")
	task.wait(0.3)

	Loading:SetCurrentStep(8)
	Loading:SetMessage("Preparing Trait Roller...")
	task.wait(0.3)

	Loading:SetCurrentStep(9)
	Loading:SetMessage("Preparing Pack Spawner...")
	task.wait(0.3)

	Loading:SetCurrentStep(10)
	Loading:SetMessage("Building Interface...")
	task.wait(0.3)

	Loading:SetCurrentStep(11)
	Loading:SetMessage("Finalizing...")
	task.wait(0.3)

	Loading:SetCurrentStep(12)
	Loading:SetMessage("Ready!")
	Loading:Continue() -- Destroys the loader and opens the main window
end)

-- Connection Manager
local NnBind = (function()
	local NnConn = {}
	local NnPrCnt = 0
	local function NnPrune(name)
		local conn = NnConn[name]
		if conn == nil then return false end
		local IsLive
		if type(conn) == "table" and type(conn.connected) == "boolean" then IsLive = conn.connected
		else
			local ok, res = pcall(function() return conn.Connected end)
			IsLive = ok and res == true
		end
		if not IsLive then NnConn[name] = nil end
		return IsLive
	end
	local NnBind = {}
	NnBind.Connect = function(conn, name)
		if not conn or not name then return conn end
		NnBind.Disconnect(name)
		NnConn[name] = conn
		NnPrCnt += 1
		if NnPrCnt % 128 == 0 then for key in pairs(NnConn) do NnPrune(key) end end
		return conn
	end
	NnBind.Disconnect = function(name)
		if not name then return end
		local conn = NnConn[name]
		if conn then pcall(function() if type(conn.Disconnect) == "function" then conn:Disconnect() end end) end
		NnConn[name] = nil
	end
	NnBind.IsConnected = function(name)
		if not name then return false end
		return NnPrune(name)
	end
	return NnBind
end)()

-- Goodsignal
local Signal = (function()
	local freeRunnerThread = nil

	local function acquireRunnerThreadAndCallEventHandler(fn, ...)
		local acquiredRunnerThread = freeRunnerThread
		freeRunnerThread = nil
		fn(...)
		freeRunnerThread = acquiredRunnerThread
	end

	local function runEventHandlerInFreeThread()
		while true do acquireRunnerThreadAndCallEventHandler(coroutine.yield()) end
	end

	local Connection = {}
	Connection.__index = Connection

	function Connection:Disconnect()
		self.connected = false
		if self.signal.handlerListHead == self then
			self.signal.handlerListHead = self.next
		else
			local prev = self.signal.handlerListHead
			while prev and prev.next ~= self do prev = prev.next end
			if prev then prev.next = self.next end
		end
	end

	local Signal = {}
	Signal.__index = Signal

	function Signal.new()
		return setmetatable({ handlerListHead = false }, Signal)
	end

	function Signal:Connect(fn)
		local connection = setmetatable({ connected = true, signal = self, fn = fn, next = self.handlerListHead }, Connection)
		self.handlerListHead = connection
		return connection
	end

	function Signal:DisconnectAll()
		local item = self.handlerListHead
		while item do item.connected = false; item = item.next end
		self.handlerListHead = false
	end

	function Signal:Fire(...)
		local item = self.handlerListHead
		while item do
			if item.connected then
				if not freeRunnerThread then
					freeRunnerThread = coroutine.create(runEventHandlerInFreeThread)
					coroutine.resume(freeRunnerThread)
				end
				task.spawn(freeRunnerThread, item.fn, ...)
			end
			item = item.next
		end
	end

	function Signal:Wait()
		local waitingCoroutine = coroutine.running()
		local cn; cn = self:Connect(function(...) cn:Disconnect(); task.spawn(waitingCoroutine, ...) end)
		return coroutine.yield()
	end

	function Signal:Once(fn)
		local cn; cn = self:Connect(function(...) if cn.connected then cn:Disconnect() end; fn(...) end)
		return cn
	end

	return Signal
end)()

-- Cache
local Card = {}
local CardInstances = {}

local CardImages = {}
for _, child in ipairs(ReplicatedStorage.Models.Cards:GetChildren()) do
    CardImages[child.Name] = child.Image
end

local function AddCard(item)
    if item:IsA("Tool") then
        local displayName = item.Name
        local count = 1
        while CardInstances[displayName] do
            count += 1
            displayName = item.Name .. " (" .. count .. ")"
        end
        CardInstances[displayName] = item
        table.insert(Card, displayName)
        if Library.Options.CardToRoll then
            Library.Options.CardToRoll:SetValues(Card)
        end
        if Library.Options.TraitCardToRoll then
            Library.Options.TraitCardToRoll:SetValues(Card)
        end
        local image = CardImages[item.Name]
        if image and image ~= "" then
            if Library.Options.CardToRoll then
                Library.Options.CardToRoll:AddValueImages({ [displayName] = image })
            end
            if Library.Options.TraitCardToRoll then
                Library.Options.TraitCardToRoll:AddValueImages({ [displayName] = image })
            end
        end
    end
end

local function RemoveCard(item)
    if item:IsA("Tool") then
        local displayName
        for k, v in pairs(CardInstances) do
            if v == item then
                displayName = k
                break
            end
        end
        if displayName then
            CardInstances[displayName] = nil
            local index = table.find(Card, displayName)
            if index then
                table.remove(Card, index)
                if Library.Options.CardToRoll then
                    Library.Options.CardToRoll:SetValues(Card)
                end
                if Library.Options.TraitCardToRoll then
                    Library.Options.TraitCardToRoll:SetValues(Card)
                end
            end
        end
    end
end

local Backpack = LocalPlayer:WaitForChild("Backpack")
NnBind.Connect(Backpack.ChildAdded:Connect(AddCard))
NnBind.Connect(Backpack.ChildRemoved:Connect(RemoveCard))
for _, item in ipairs(Backpack:GetChildren()) do
    AddCard(item)
end

local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
NnBind.Connect(Character.ChildAdded:Connect(AddCard))
NnBind.Connect(Character.ChildRemoved:Connect(RemoveCard))
for _, item in ipairs(Character:GetChildren()) do
    AddCard(item)
end

local CharacterAdded = Signal.new()
NnBind.Connect(LocalPlayer.CharacterAdded:Connect(function(char)
    CharacterAdded:Fire(char)
end))

local CharacterCached = Signal.new()
NnBind.Connect(CharacterAdded:Connect(function(char)
	playerChar = char
	playerHum = char:WaitForChild("Humanoid")
	playerHRP = char:WaitForChild("HumanoidRootPart")
	CharacterCached:Fire()
end))

-- Ui Setup
local Window = Library:CreateWindow({
    Title = "Noname | ACF",
    Icon = "lucide:atom",
})

local Tabs = {
    Home = Window:AddTab("Main", "lucide:house"),
    Roller = Window:AddTab("Roller", "lucide:dices"),
}

-- Misc
local MiscGroupbox = Tabs.Home:AddLeftGroupbox("Misc", "lucide:settings-2")

local Vim = nil
pcall(function() Vim = game:GetService("VirtualInputManager") end)

local afkMode = nil

local function antiafk(mode)
    afkMode = mode
    if mode ~= nil then
        Library:Notify({
            Title = "Anti-AFK",
            Description = "Enabled (" .. tostring(mode) .. ")",
            Icon = "lucide:mouse-pointer-click",
            Time = 4,
        })
    end
    task.spawn(function()
        while afkMode do
            task.wait(60)
            if Vim then
                if afkMode == "Mobile" then
                    pcall(function() Vim:SendTouchEvent(998, 0, 100, 100) end)
                    task.wait(0.1)
                    pcall(function() Vim:SendTouchEvent(998, 2, 100, 100) end)
                else
                    pcall(function() Vim:SendKeyEvent(true, Enum.KeyCode.Space, false, game) end)
                    task.wait(0.1)
                    pcall(function() Vim:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
                end
            else
                if playerHum then
                    playerHum:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end
    end)
end

local AntiAFKToggle = MiscGroupbox:AddToggle("AntiAFK", {
    Text = "Anti-AFK",
    Tooltip = "Prevents getting kicked for idling.",
    Default = false,
    Callback = function(v)
        if v then
            local AntiAFKDialog
            AntiAFKDialog = Window:AddDialog("AntiAFKModeDialog", {
                Title = "Anti-AFK Mode",
                Description = "Choose which method to use to prevent being kicked for idling.",
                Icon = "lucide:radar",
                AutoDismiss = true,
                OutsideClickDismiss = false,
                FooterButtons = {
                    Mobile = {
                        Title = "Mobile",
                        Variant = "Secondary",
                        Order = 1,
                        Callback = function()
                            antiafk("Mobile")
                        end,
                    },
                    PC = {
                        Title = "PC",
                        Variant = "Primary",
                        Order = 2,
                        Callback = function()
                            antiafk("PC")
                        end,
                    },
                },
            })
        else
            antiafk(nil)
        end
    end,
})

-- Movement
local MovementGroupbox = Tabs.Home:AddRightGroupbox("Movement", "lucide:footprints")

local WalkspeedTextbox = MovementGroupbox:AddInput("WalkspeedValue", {
    Text = "Walkspeed",
    Default = "",
    Numeric = true,
    Placeholder = "16",
})

local WalkspeedActive = false

local ApplyWalkspeedToggle = MovementGroupbox:AddToggle("ApplyWalkspeed", {
    Text = "Apply Walkspeed",
    Default = false,
    Callback = function(state)
        if state then
            local value = Library.Options.WalkspeedValue.Value
            if not value or value == "" then
                Library:Notify({
                    Title = "Movement",
                    Description = "Set the Walkspeed Value First",
                    Icon = "solar:danger-triangle-bold",
                    Time = 4,
                })
                Library.Toggles.ApplyWalkspeed:SetValue(false)
                return
            end

            WalkspeedActive = true
            if playerHum then
                playerHum.WalkSpeed = tonumber(value)
            end
            NnBind.Disconnect("WalkspeedForce")
            if playerHum then
                NnBind.Connect(playerHum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                    if WalkspeedActive and playerHum then
                        playerHum.WalkSpeed = tonumber(Library.Options.WalkspeedValue.Value)
                    end
                end), "WalkspeedForce")
            end
        else
            WalkspeedActive = false
            NnBind.Disconnect("WalkspeedForce")
            if playerHum then
                playerHum.Health = 0
            end
        end
    end,
})

WalkspeedTextbox:OnChanged(function(value)
    if WalkspeedActive and playerHum and value ~= "" then
        playerHum.WalkSpeed = tonumber(value)
    end
end)

MovementGroupbox:AddDivider()

local JumpPowerTextbox = MovementGroupbox:AddInput("JumpPowerValue", {
    Text = "JumpPower",
    Default = "",
    Numeric = true,
    Placeholder = "50",
})

local JumpPowerActive = false

local ApplyJumpPowerToggle = MovementGroupbox:AddToggle("ApplyJumpPower", {
    Text = "Apply JumpPower",
    Default = false,
    Callback = function(state)
        if state then
            local value = Library.Options.JumpPowerValue.Value
            if not value or value == "" then
                Library:Notify({
                    Title = "Movement",
                    Description = "Set the JumpPower Value First",
                    Icon = "solar:danger-triangle-bold",
                    Time = 4,
                })
                Library.Toggles.ApplyJumpPower:SetValue(false)
                return
            end

            JumpPowerActive = true
            if playerHum then
                playerHum.JumpPower = tonumber(value)
            end
            NnBind.Disconnect("JumpPowerForce")
            if playerHum then
                NnBind.Connect(playerHum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                    if JumpPowerActive and playerHum then
                        playerHum.JumpPower = tonumber(Library.Options.JumpPowerValue.Value)
                    end
                end), "JumpPowerForce")
            end
        else
            JumpPowerActive = false
            NnBind.Disconnect("JumpPowerForce")
            if playerHum then
                playerHum.Health = 0
            end
        end
    end,
})

JumpPowerTextbox:OnChanged(function(value)
    if JumpPowerActive and playerHum and value ~= "" then
        playerHum.JumpPower = tonumber(value)
    end
end)

NnBind.Connect(CharacterCached:Connect(function()
    if WalkspeedActive then
        local value = Library.Options.WalkspeedValue.Value
        if playerHum and value and value ~= "" then
            playerHum.WalkSpeed = tonumber(value)
        end
        NnBind.Disconnect("WalkspeedForce")
        if playerHum then
            NnBind.Connect(playerHum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
                if WalkspeedActive and playerHum then
                    playerHum.WalkSpeed = tonumber(Library.Options.WalkspeedValue.Value)
                end
            end), "WalkspeedForce")
        end
    end
    if JumpPowerActive then
        local value = Library.Options.JumpPowerValue.Value
        if playerHum and value and value ~= "" then
            playerHum.JumpPower = tonumber(value)
        end
        NnBind.Disconnect("JumpPowerForce")
        if playerHum then
            NnBind.Connect(playerHum:GetPropertyChangedSignal("JumpPower"):Connect(function()
                if JumpPowerActive and playerHum then
                    playerHum.JumpPower = tonumber(Library.Options.JumpPowerValue.Value)
                end
            end), "JumpPowerForce")
        end
    end
end), "Movement_CharacterCached")

-- Grade Roller
local MainGroupbox = Tabs.Roller:AddLeftGroupbox("Grade Roller", "gravity:medal")
local StatsGroupbox = Tabs.Roller:AddLeftGroupbox("Grade Roller Stats", "gravity:chart-column")
StatsGroupbox:AddLabel("Latest Rolled Card:", true)
local GradeRollerStatsLabels = {}

local function DisableRollGrade()
    IsGradeRunning = false
    NnBind.Disconnect("GradeRoller_Result")
    for _, label in pairs(GradeRollerStatsLabels) do
        label:Destroy()
    end
    table.clear(GradeRollerStatsLabels)
end

local function RollGrade(TargetGrade, Tools)
    IsGradeRunning = true

    local toolOrder = {}
    for ToolName in pairs(Tools) do
        table.insert(toolOrder, ToolName)
    end

    GradeRollerStatsLabels[toolOrder[1]] = StatsGroupbox:AddLabel(toolOrder[1] .. ": Rolling...", true)
    for i = 2, #toolOrder do
        GradeRollerStatsLabels[toolOrder[i]] = StatsGroupbox:AddLabel(toolOrder[i] .. ": Waiting (" .. (i - 1) .. ")", true)
    end

    local currentIndex = 1

    NnBind.Connect(Event.OnClientEvent:Connect(function(responseType, data)
        if responseType ~= "RollResult" then return end

        local displayName
        if data and data.Tool and typeof(data.Tool) == "Instance" then
            for k, v in pairs(CardInstances) do
                if v == data.Tool then
                    displayName = k
                    break
                end
            end
        end
        if not displayName then return end

        if data and data.Grade then
            if GradeRollerStatsLabels[displayName] then
                GradeRollerStatsLabels[displayName]:SetText(displayName .. " - Grade: " .. tostring(data.Grade))
            end
        end

        if data and data.Grade and TargetGrade[data.Grade] then
            Tools[displayName] = nil

            if GradeRollerStatsLabels[displayName] then
                GradeRollerStatsLabels[displayName]:Destroy()
                GradeRollerStatsLabels[displayName] = nil
            end

            if Library.Options.CardToRoll then
                local currentSelected = Library.Options.CardToRoll.Value
                if currentSelected and type(currentSelected) == "table" then
                    currentSelected[displayName] = nil
                    Library.Options.CardToRoll:SetValue(currentSelected)
                end
            end

            Library:Notify({
                Title = "Grade Roller",
                Description = "Target Grade Rolled! " .. tostring(data.Grade) .. " - " .. displayName,
                Icon = "solar:cup-star-bold",
                Time = 5,
            })

            currentIndex += 1
            for i = currentIndex, #toolOrder do
                local name = toolOrder[i]
                if GradeRollerStatsLabels[name] then
                    if i == currentIndex then
                        GradeRollerStatsLabels[name]:SetText(name .. ": Rolling...")
                    else
                        GradeRollerStatsLabels[name]:SetText(name .. ": Waiting (" .. (i - currentIndex) .. ")")
                    end
                end
            end

            if next(Tools) == nil then
                if Library.Toggles.AutoRollGrade then
                    Library.Toggles.AutoRollGrade:SetValue(false)
                else
                    DisableRollGrade()
                end
            end
        end
    end), "GradeRoller_Result")

    while IsGradeRunning do
        if currentIndex > #toolOrder or next(Tools) == nil then
            task.wait(0.5)
        else
            local ToolName = toolOrder[currentIndex]
            if ToolName and Tools[ToolName] then
                local ToolInstance = CardInstances[ToolName]
                if ToolInstance and ToolInstance.Parent then
                    Event:FireServer("RollGrade", {
                        Tool = ToolInstance,
                        Currency = "cash"
                    })
                end
            end
            task.wait(0.05)
        end
    end

    NnBind.Disconnect("GradeRoller_Result")
end

local TargetGradeDropdown = MainGroupbox:AddDropdown("TargetGrade", {
    Text = "Target Grade",
    Values = { "F", "E", "D", "C", "B", "A", "S", "SS", "SR", "UR", "LR" },
    Multi = true,
    AllowNull = true,
})

local CardToRollDropdown = MainGroupbox:AddDropdown("CardToRoll", {
    Text = "Select Card To Roll",
    Values = Card,
    Multi = true,
    AllowNull = true,
})

local AutoRollToggle = MainGroupbox:AddToggle("AutoRollGrade", {
    Text = "Auto Roll Grade",
    Default = false,
    Callback = function(state)
        if state then
            local Tools = {}
            for k, v in pairs(Library.Options.CardToRoll.Value) do
                Tools[k] = v
            end

            if next(Tools) == nil then
                Library:Notify({
                    Title = "Grade Roller",
                    Description = "Select At Least One Card",
                    Icon = "solar:danger-triangle-bold",
                    Time = 5,
                })
                Library.Toggles.AutoRollGrade:SetValue(false)
                return
            end

            local Grades = Library.Options.TargetGrade.Value
            task.spawn(RollGrade, Grades, Tools)
        else
            DisableRollGrade()
        end
    end,
})

-- Trait Roller
local TraitData = {
    Order = {
        "Fortune I", "Vigor I", "Strength I",
        "Fortune II", "Vigor II", "Strength II",
        "Fortune III", "Vigor III", "Strength III",
        "Assassin", "Berserk", "Tank", "Rich", "Emperor", "Phoenix", "Almighty", "Sovereign",
    },
    Image = {
        ["Fortune I"] = "rbxassetid://136015994897366",
        ["Vigor I"] = "rbxassetid://100143482508141",
        ["Strength I"] = "rbxassetid://78765578312593",
        ["Fortune II"] = "rbxassetid://136015994897366",
        ["Vigor II"] = "rbxassetid://100143482508141",
        ["Strength II"] = "rbxassetid://78765578312593",
        ["Fortune III"] = "rbxassetid://136015994897366",
        ["Vigor III"] = "rbxassetid://100143482508141",
        ["Strength III"] = "rbxassetid://78765578312593",
        ["Assassin"] = "rbxassetid://76224080356785",
        ["Berserk"] = "rbxassetid://98350751918534",
        ["Tank"] = "rbxassetid://90649910911616",
        ["Rich"] = "rbxassetid://111462637218344",
        ["Emperor"] = "rbxassetid://98698751977663",
        ["Phoenix"] = "rbxassetid://102280959845400",
        ["Almighty"] = "rbxassetid://115429293221611",
        ["Sovereign"] = "rbxassetid://92476090315392",
    },
}

local TraitsGroupbox = Tabs.Roller:AddRightGroupbox("Traits Roller", "solar:magic-stick-3-bold")
local TraitsStatsGroupbox = Tabs.Roller:AddRightGroupbox("Traits Roller Stats", "craft:check-square-02-stroke")
TraitsStatsGroupbox:AddLabel("Latest Rolled Card:", true)
local TraitRollerStatsLabels = {}

local function DisableRollTrait()
    IsTraitRunning = false
    NnBind.Disconnect("TraitRoller_Result")
    for _, label in pairs(TraitRollerStatsLabels) do
        label:Destroy()
    end
    table.clear(TraitRollerStatsLabels)
end

local function RollTrait(TargetTrait, Tools)
    IsTraitRunning = true

    local toolOrder = {}
    for ToolName in pairs(Tools) do
        table.insert(toolOrder, ToolName)
    end

    TraitRollerStatsLabels[toolOrder[1]] = TraitsStatsGroupbox:AddLabel(toolOrder[1] .. ": Rolling...", true)
    for i = 2, #toolOrder do
        TraitRollerStatsLabels[toolOrder[i]] = TraitsStatsGroupbox:AddLabel(toolOrder[i] .. ": Waiting (" .. (i - 1) .. ")", true)
    end

    local currentIndex = 1

    NnBind.Connect(TraitEvent.OnClientEvent:Connect(function(responseType, data)
        if responseType ~= "RollResult" then return end

        local displayName
        if data and data.Tool and typeof(data.Tool) == "Instance" then
            for k, v in pairs(CardInstances) do
                if v == data.Tool then
                    displayName = k
                    break
                end
            end
        end
        if not displayName then return end

        if data and data.Trait then
            if TraitRollerStatsLabels[displayName] then
                TraitRollerStatsLabels[displayName]:SetText(displayName .. " - Trait: " .. tostring(data.Trait))
            end
        end

        if data and data.Trait and TargetTrait[data.Trait] then
            Tools[displayName] = nil

            if TraitRollerStatsLabels[displayName] then
                TraitRollerStatsLabels[displayName]:Destroy()
                TraitRollerStatsLabels[displayName] = nil
            end

            if Library.Options.TraitCardToRoll then
                local currentSelected = Library.Options.TraitCardToRoll.Value
                if currentSelected and type(currentSelected) == "table" then
                    currentSelected[displayName] = nil
                    Library.Options.TraitCardToRoll:SetValue(currentSelected)
                end
            end

            Library:Notify({
                Title = "Trait Roller",
                Description = "Target Trait Rolled! " .. tostring(data.Trait) .. " - " .. displayName,
                Icon = "gravity:magic-wand",
                Time = 5,
            })

            currentIndex += 1
            for i = currentIndex, #toolOrder do
                local name = toolOrder[i]
                if TraitRollerStatsLabels[name] then
                    if i == currentIndex then
                        TraitRollerStatsLabels[name]:SetText(name .. ": Rolling...")
                    else
                        TraitRollerStatsLabels[name]:SetText(name .. ": Waiting (" .. (i - currentIndex) .. ")")
                    end
                end
            end

            if next(Tools) == nil then
                if Library.Toggles.AutoRollTrait then
                    Library.Toggles.AutoRollTrait:SetValue(false)
                else
                    DisableRollTrait()
                end
            end
        end
    end), "TraitRoller_Result")

    while IsTraitRunning do
        if currentIndex > #toolOrder or next(Tools) == nil then
            task.wait(0.5)
        else
            local ToolName = toolOrder[currentIndex]
            if ToolName and Tools[ToolName] then
                local ToolInstance = CardInstances[ToolName]
                if ToolInstance and ToolInstance.Parent then
                    TraitEvent:FireServer("RollTrait", {
                        Tool = ToolInstance,
                    })
                end
            end
            task.wait(0.05)
        end
    end

    NnBind.Disconnect("TraitRoller_Result")
end

local TargetTraitDropdown = TraitsGroupbox:AddDropdown("TargetTrait", {
    Text = "Target Trait",
    Values = TraitData.Order,
    Multi = true,
    AllowNull = true,
    ValueImages = TraitData.Image,
})

local TraitCardToRollDropdown = TraitsGroupbox:AddDropdown("TraitCardToRoll", {
    Text = "Select Card To Roll",
    Values = Card,
    Multi = true,
    AllowNull = true,
})

local AutoRollTraitToggle = TraitsGroupbox:AddToggle("AutoRollTrait", {
    Text = "Auto Roll Trait",
    Default = false,
    Callback = function(state)
        if state then
            local Tools = {}
            for k, v in pairs(Library.Options.TraitCardToRoll.Value) do
                Tools[k] = v
            end

            if next(Tools) == nil then
                Library:Notify({
                    Title = "Trait Roller",
                    Description = "Select At Least One Tool",
                    Icon = "solar:danger-triangle-bold",
                    Time = 5,
                })
                Library.Toggles.AutoRollTrait:SetValue(false)
                return
            end

            local Traits = Library.Options.TargetTrait.Value
            task.spawn(RollTrait, Traits, Tools)
        else
            DisableRollTrait()
        end
    end,
})

-- Pack Spawner
local SpawnPackGroupbox = Tabs.Roller:AddLeftGroupbox("Pack Spawner", "craft:box-package-02-stroke")
local SpawnPackStatsGroupbox = Tabs.Roller:AddRightGroupbox("Pack Spawner Stats", "geist:bar-chart")

local SpawnPackIdLabel = SpawnPackStatsGroupbox:AddLabel("Pack: -", true)
local SpawnPackRarityLabel = SpawnPackStatsGroupbox:AddLabel("Rarity: -", true)
local SpawnPackMutationLabel = SpawnPackStatsGroupbox:AddLabel("Mutation: -", true)
local SpawnPackPriceLabel = SpawnPackStatsGroupbox:AddLabel("Price: -", true)
local SpawnPackStatusLabel = SpawnPackStatsGroupbox:AddLabel("Status: Idle", true)

local IsSpawnPackRunning = false

local PackRollData = {
    Mutations = {{Name="Normal",Best=1},{Name="Golden",Best=2},{Name="Diamond",Best=3},{Name="Venomous",Best=4},{Name="Rainbow",Best=5},{Name="Sakura",Best=6},{Name="Candy",Best=7},{Name="Blessed",Best=8},{Name="Radioactive",Best=9},{Name="Glitch",Best=10},{Name="Starfallen",Best=11},{Name="Admin",Best=12},{Name="Unknow",Best=13}},
    Rarity = {{Rarity="Common",Best=1},{Rarity="Uncommon",Best=2},{Rarity="Rare",Best=3},{Rarity="Epic",Best=4},{Rarity="Legendary",Best=5},{Rarity="Mythic",Best=6},{Rarity="Secret",Best=7},{Rarity="Divine",Best=8},{Rarity="Transcendent",Best=9},{Rarity="Shadow",Best=10},{Rarity="Emperor",Best=11},{Rarity="Demon",Best=12},{Rarity="Manga",Best=13},{Rarity="Celestial",Best=14},{Rarity="Heavenly",Best=15},{Rarity="Corrupted",Best=16},{Rarity="Striker",Best=17},{Rarity="Sacred",Best=18},{Rarity="Paradox",Best=19},{Rarity="Founder",Best=20},{Rarity="Evolved",Best=21},{Rarity="Magic",Best=22},{Rarity="Oni",Best=23},{Rarity="Chaos",Best=24},{Rarity="Ruin",Best=25},{Rarity="Reborn",Best=26},{Rarity="Beast",Best=27},{Rarity="Nordic",Best=28},{Rarity="Hunter",Best=29},{Rarity="Soul",Best=30},{Rarity="Swordsman",Best=31},{Rarity="Gamer",Best=32},{Rarity="Revenge",Best=33},{Rarity="Chainsaw",Best=34},{Rarity="Eternity",Best=35},{Rarity="Academy",Best=36},{Rarity="Dynasty",Best=37},{Rarity="Grail",Best=38},{Rarity="Conquest",Best=39},{Rarity="Blaze",Best=40},{Rarity="Devour",Best=41},{Rarity="Raven",Best=42},{Rarity="Arcane",Best=43},{Rarity="Nightfall",Best=44},{Rarity="Smash",Best=45},{Rarity="Emblem",Best=46},{Rarity="Chrono",Best=47}}
}

local MutationRankByName = {}
local MutationNames = {"None"}
for _, m in ipairs(PackRollData.Mutations) do
    MutationRankByName[m.Name] = m.Best
    table.insert(MutationNames, m.Name)
end

local RarityRankByName = {}
local RarityNames = {"None"}
for _, r in ipairs(PackRollData.Rarity) do
    RarityRankByName[r.Rarity] = r.Best
    table.insert(RarityNames, r.Rarity)
end

local function DisableSpawnPack()
    IsSpawnPackRunning = false
    NnBind.Disconnect("SpawnPack_Result")
    SpawnPackStatusLabel:SetText("Status: Idle")
end

local function SpawnPackAndBuy()
    IsSpawnPackRunning = true
    local Plot_N0 = LocalPlot:WaitForChild("Plot_N0")
    local ButtonPart = Plot_N0:WaitForChild("ButtonPart")
    local ClickDetector = ButtonPart:WaitForChild("ClickDetector")
    local ConveyorEvent = ReplicatedStorage.Remotes.ConveyorRE
    local ConveyorModels = Plot_N0:WaitForChild("LocalConveyorModels")
    local function NextSpawn()
        if not IsSpawnPackRunning then return end
        task.wait(1.5)
        SpawnPackStatusLabel:SetText("Status: Spawning...")
        fireclickdetector(ClickDetector)
    end

    local IsHandlingSpawn = false

    NnBind.Connect(ConveyorEvent.OnClientEvent:Connect(function(responseType, data)
        if not IsSpawnPackRunning then return end
        if responseType ~= "SpawnAndMoveToB" then return end
        if typeof(data) ~= "table" then return end
        if IsHandlingSpawn then return end
        IsHandlingSpawn = true

        local PackId = data.PackId
        local Rarity = data.Rarity
        local Mutation = data.Mutation
        local Price = data.Price
        SpawnPackIdLabel:SetText("Pack: " .. tostring(PackId))
        SpawnPackRarityLabel:SetText("Rarity: " .. tostring(Rarity))
        SpawnPackMutationLabel:SetText("Mutation: " .. tostring(Mutation))
        SpawnPackPriceLabel:SetText("Price: " .. tostring(Price))
        local MinMutationName = Library.Options.MinMutation.Value
        local MutationValid = true
        if MinMutationName and MinMutationName ~= "None" then
            local minRank = MutationRankByName[MinMutationName]
            local curRank = Mutation and MutationRankByName[Mutation]
            MutationValid = (minRank ~= nil) and (curRank ~= nil) and (curRank >= minRank)
        end

        local MinRarityName = Library.Options.MinRarity.Value
        local RarityValid = true
        if MinRarityName and MinRarityName ~= "None" then
            local minRank = RarityRankByName[MinRarityName]
            local curRank = Rarity and RarityRankByName[Rarity]
            RarityValid = (minRank ~= nil) and (curRank ~= nil) and (curRank >= minRank)
        end

        if not (MutationValid and RarityValid) then
            SpawnPackStatusLabel:SetText("Status: Skipped (Filter)")
            IsHandlingSpawn = false
            NextSpawn()
            return
        end

        if Library.Toggles.OnlyNotifyIfFound and Library.Toggles.OnlyNotifyIfFound.Value then
            SpawnPackStatusLabel:SetText("Status: Found!")
            Library:Notify({
                Title = "Pack Spawner",
                Description = tostring(PackId) .. " Found! Price: " .. tostring(Price),
                Icon = "lucide:sparkles",
                Time = 5,
            })
            IsHandlingSpawn = false
            if Library.Toggles.AutoSpawnPack then
                Library.Toggles.AutoSpawnPack:SetValue(false)
            else
                DisableSpawnPack()
            end
            return
        end

        local Cash = LocalPlayer.CashValue.Value
        if Cash < (Price or 0) then
            if Library.Toggles.SkipIfNotEnoughMoney.Value then
                SpawnPackStatusLabel:SetText("Status: Skipped (No Money)")
                IsHandlingSpawn = false
                NextSpawn()
                return
            else
                SpawnPackStatusLabel:SetText("Status: Stopped (No Money)")
                Library:Notify({
                    Title = "Pack Spawner",
                    Description = "Not Enough Money, Stopping Auto Spawn Pack",
                    Icon = "solar:danger-triangle-bold",
                    Time = 5,
                })
                IsHandlingSpawn = false
                if Library.Toggles.AutoSpawnPack then
                    Library.Toggles.AutoSpawnPack:SetValue(false)
                else
                    DisableSpawnPack()
                end
                return
            end
        end

        SpawnPackStatusLabel:SetText("Status: Buying...")
        local PackModel = ConveyorModels:WaitForChild(tostring(PackId))
        if not IsSpawnPackRunning then
            IsHandlingSpawn = false
            return
        end

        local MainPart = PackModel:WaitForChild("Main", 3)
        local Prompt = MainPart and MainPart:WaitForChild("ProximityPrompt", 3)

        if Prompt then
            task.wait(1.5)
            fireproximityprompt(Prompt)
            Library:Notify({
                Title = "Pack Spawner",
                Description = tostring(PackId) .. " Buyed! price: " .. tostring(Price),
                Icon = "lucide:shopping-cart",
                Time = 4,
            })
        end

        task.wait(1)
        IsHandlingSpawn = false
        NextSpawn()
    end), "SpawnPack_Result")

    fireclickdetector(ClickDetector)
end

local MinMutationDropdown = SpawnPackGroupbox:AddDropdown("MinMutation", {
    Text = "Min Mutation",
    Values = MutationNames,
    Default = 1,
    Multi = false,
})

local MinRarityDropdown = SpawnPackGroupbox:AddDropdown("MinRarity", {
    Text = "Min Rarity",
    Values = RarityNames,
    Default = 1,
    Multi = false,
})

local SkipIfNotEnoughMoneyToggle = SpawnPackGroupbox:AddToggle("SkipIfNotEnoughMoney", {
    Text = "Skip If Not Have Enough Money",
    Default = false,
})

local OnlyNotifyIfFoundToggle = SpawnPackGroupbox:AddToggle("OnlyNotifyIfFound", {
    Text = "Only Notify If Found",
    Default = false,
})

local AutoSpawnPackToggle = SpawnPackGroupbox:AddToggle("AutoSpawnPack", {
    Text = "Auto Spawn Pack And Buy",
    Default = false,
    Callback = function(state)
        if state then
            task.spawn(SpawnPackAndBuy)
        else
            DisableSpawnPack()
        end
    end,
})

