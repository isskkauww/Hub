--[[ Services & Variables ]]--
if not game:IsLoaded() then game.Loaded:Wait() end
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local playerHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
local RunService = game:GetService("RunService")
local LocalPlot = workspace.MAP.Plots[tostring(LocalPlayer.PlotNumber.Value)]

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/Library.lua"))()

--[[ Addons ]]--
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/addons/SaveManager.lua"))()
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/deividcomsono/Obsidian/refs/heads/main/addons/ThemeManager.lua"))()

--[[ Icon Module ]]--
local IconsLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/Main-v2.lua"))()

-- Adapts whatever shape IconsLib returns into the {Url, ImageRectSize, ImageRectOffset} format the Library's icon module expects
local function GetAsset(IconName)
	if not IconsLib or type(IconName) ~= "string" or IconName == "" then
		return nil
	end

	local ok, result = pcall(IconsLib.GetIcon, IconName)
	if not ok or result == nil then
		return nil
	end

	-- plain image asset, no sprite sheet rect involved
	if type(result) == "string" then
		return {
			Url = result,
			IconName = IconName,
			ImageRectSize = Vector2.zero,
			ImageRectOffset = Vector2.zero,
		}
	end

	-- sprite sheet icon: result[1] is the sheet asset, result[2] carries the rect info
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

--[[ Loading Screen ]]--
local Loading = Library:CreateLoading({
	Title = "Noname | ACF",
	Icon = "lucide:atom",
	TotalSteps = 12,
})

Loading:ShowSidebarPage(true)
Loading.Sidebar:AddLabel("Hello " .. LocalPlayer.Name .. "!")
Loading.Sidebar:AddLabel("Plot: " .. tostring(LocalPlayer.PlotNumber.Value))

-- fake progress steps for visual feedback while the addons/icons above finish loading
task.spawn(function()
	Loading:SetCurrentStep(1)
	Loading:SetMessage("Initializing Environment...")
	task.wait(0.1)
	Loading:SetCurrentStep(2)
	Loading:SetMessage("Loading UI Library...")
	task.wait(0.1)
	Loading:SetCurrentStep(3)
	Loading:SetMessage("Loading Addons...")
	task.wait(0.1)
	Loading:SetCurrentStep(4)
	Loading:SetMessage("Loading Icon Pack...")
	task.wait(0.1)
	Loading:SetCurrentStep(5)
	Loading:SetMessage("Establishing Remote Connections...")
	task.wait(0.1)
	Loading:SetCurrentStep(6)
	Loading:SetMessage("Initializing Connection Manager...")
	task.wait(0.1)
	Loading:SetCurrentStep(7)
	Loading:SetMessage("Building Interface...")
	task.wait(0.1)
	Loading:SetCurrentStep(8)
	Loading:SetMessage("Preparing Pack Spawner...")
	task.wait(0.1)
	Loading:SetCurrentStep(9)
	Loading:SetMessage("Preparing Misc Tools...")
	task.wait(0.1)
	Loading:SetCurrentStep(10)
	Loading:SetMessage("Loading Settings...")
	task.wait(0.1)
	Loading:SetCurrentStep(11)
	Loading:SetMessage("Finalizing...")
	task.wait(0.15)
	Loading:SetCurrentStep(12)
	Loading:SetMessage("Ready!")
	task.wait(0.3)
	Loading:Continue() -- Destroys the loader and opens the main window
end)

--[[ Connection Manager ]]--
local Bind = loadstring(game:HttpGet("https://raw.githubusercontent.com/isskkauww/Modules/refs/heads/main/Connection%20Manager.luau"))()

Bind:Connect(LocalPlayer.CharacterAdded, function(char) playerHum = char:WaitForChild("Humanoid") end)

--[[ UI Setup ]]--
local Window = Library:CreateWindow({
    Title = "Noname | ACF",
    Icon = "lucide:atom",
    Footer = "By Isskkauw",
    Font = Enum.Font.GothamMedium,
    AlwaysOnTop = true,

    Animations = {
        ToggleWindow = true,
        TabSwitch = true,
        Groupbox = true,
        Dropdown = true,
        KeyPicker = true
    },
    TabTransitionTime = 0.22,
    TabSwipeOffset = 26,
    TabSwipeFrom = "top",
})

-- remove the Lock button on mobile
if Library.IsMobile then
    for _, Elem in Library.DraggableElements do
        if Elem:IsA("TextButton") and Elem.Text == "Lock" then
            Elem:Destroy()
        end
    end
end

local Tabs = {
    Home = Window:AddTab("Main", "lucide:house"),
    Settings = Window:AddTab("Settings", "lucide:settings"),
}

--[[ Pack Spawner ]]--
local SpawnPackGroupbox = Tabs.Home:AddLeftGroupbox("Pack Spawner", "craft:box-package-02-stroke")
local SpawnPackStatsGroupbox = Tabs.Home:AddRightGroupbox("Pack Spawner Stats", "geist:bar-chart")

local SpawnPackIdLabel = SpawnPackStatsGroupbox:AddLabel("Pack: -", true)
local SpawnPackRarityLabel = SpawnPackStatsGroupbox:AddLabel("Rarity: -", true)
local SpawnPackMutationLabel = SpawnPackStatsGroupbox:AddLabel("Mutation: -", true)
local SpawnPackPriceLabel = SpawnPackStatsGroupbox:AddLabel("Price: -", true)
local SpawnPackStatusLabel = SpawnPackStatsGroupbox:AddLabel("Status: Idle", true)

local IsSpawnPackRunning = false
local CurrentSpawnThread = nil

-- static roll tables; each entry's Best value is its rank, used below to build the min-rarity/min-mutation filters
local PackRollData = {
    Mutations = {{Name="Normal",Best=1},{Name="Golden",Best=2},{Name="Diamond",Best=3},{Name="Venomous",Best=4},{Name="Rainbow",Best=5},{Name="Sakura",Best=6},{Name="Candy",Best=7},{Name="Blessed",Best=8},{Name="Radioactive",Best=9},{Name="Glitch",Best=10},{Name="Starfallen",Best=11},{Name="Admin",Best=12},{Name="Nullstar",Best=13},{Name="Unknow",Best=14}},
    Rarity = {{Rarity="Common",Best=1},{Rarity="Uncommon",Best=2},{Rarity="Rare",Best=3},{Rarity="Epic",Best=4},{Rarity="Legendary",Best=5},{Rarity="Mythic",Best=6},{Rarity="Secret",Best=7},{Rarity="Divine",Best=8},{Rarity="Transcendent",Best=9},{Rarity="Shadow",Best=10},{Rarity="Emperor",Best=11},{Rarity="Demon",Best=12},{Rarity="Manga",Best=13},{Rarity="Celestial",Best=14},{Rarity="Heavenly",Best=15},{Rarity="Corrupted",Best=16},{Rarity="Striker",Best=17},{Rarity="Sacred",Best=18},{Rarity="Paradox",Best=19},{Rarity="Founder",Best=20},{Rarity="Evolved",Best=21},{Rarity="Magic",Best=22},{Rarity="Oni",Best=23},{Rarity="Chaos",Best=24},{Rarity="Ruin",Best=25},{Rarity="Reborn",Best=26},{Rarity="Beast",Best=27},{Rarity="Nordic",Best=28},{Rarity="Hunter",Best=29},{Rarity="Soul",Best=30},{Rarity="Swordsman",Best=31},{Rarity="Gamer",Best=32},{Rarity="Revenge",Best=33},{Rarity="Chainsaw",Best=34},{Rarity="Eternity",Best=35},{Rarity="Academy",Best=36},{Rarity="Dynasty",Best=37},{Rarity="Grail",Best=38},{Rarity="Conquest",Best=39},{Rarity="Blaze",Best=40},{Rarity="Devour",Best=41},{Rarity="Raven",Best=42},{Rarity="Arcane",Best=43},{Rarity="Nightfall",Best=44},{Rarity="Smash",Best=45},{Rarity="Emblem",Best=46},{Rarity="Chrono",Best=47},{Rarity="Dunk",Best=48},{Rarity="Blossom",Best=49},{Rarity="Zenith",Best=50},{Rarity="Assassin",Best=51},{Rarity="Power",Best=52},{Rarity="Rebellion",Best=53}}
}

local MutationRankByName = {}
local MutationNames = {"Any"}
for _, m in ipairs(PackRollData.Mutations) do
    MutationRankByName[m.Name] = m.Best
    table.insert(MutationNames, m.Name)
end

local RarityRankByName = {}
local RarityNames = {"Any"}
for _, r in ipairs(PackRollData.Rarity) do
    RarityRankByName[r.Rarity] = r.Best
    table.insert(RarityNames, r.Rarity)
end

local PackSpawnRules = {} -- [RuleId] = {Rarity = RarityName, Mutation = MutationName}
local NextRuleId = 1

local function DisableSpawnPack()
    IsSpawnPackRunning = false
    Bind:Disconnect("SpawnPack_Result")
    Bind:Disconnect("SpawnPack_WaitCash")
    if CurrentSpawnThread then
        task.cancel(CurrentSpawnThread)
        CurrentSpawnThread = nil
    end
    SpawnPackStatusLabel:SetText("Status: Idle")
end

-- fires the plot's spawn button repeatedly, then buys whatever pack lands on the conveyor if it matches a rule
local function SpawnPackAndBuy()
    IsSpawnPackRunning = true
    local Plot_N0 = LocalPlot:WaitForChild("Plot_N0")
    local ButtonPart = Plot_N0:WaitForChild("ButtonPart")
    local ClickDetector = ButtonPart:WaitForChild("ClickDetector")
    local ConveyorEvent = ReplicatedStorage.Remotes.ConveyorRE
    local ConveyorModels = Plot_N0:WaitForChild("LocalConveyorModels")

    local IsHandlingSpawn = false
    local IsWaitingCash = false

    local function NextSpawn()
        if not IsSpawnPackRunning then return end
        SpawnPackStatusLabel:SetText("Status: Spawning...")
        for i = 1, 30 do
            if not IsSpawnPackRunning then break end
            if IsHandlingSpawn then break end -- A pack purchase is still being processed; stop spawning more packs.
            fireclickdetector(ClickDetector)
            task.wait(0.1)
        end
    end

    -- waits for the pack's model + prompt to exist, then holds the proximity prompt until it's claimed
    local function BuyPack(PackId, Price)
        SpawnPackStatusLabel:SetText("Status: Buying...")
        local PackModel = ConveyorModels:WaitForChild(tostring(PackId))
        if not IsSpawnPackRunning then
            IsHandlingSpawn = false
            return
        end

        local MainPart = PackModel:WaitForChild("Main", 3)
        local Prompt = MainPart and MainPart:WaitForChild("ProximityPrompt", 3)

        if Prompt then
            for i = 1,20 do
                if not IsSpawnPackRunning then break end
                fireproximityprompt(Prompt)
                task.wait(0.1)
            end
            if IsSpawnPackRunning then
                Library:Notify({
                    Title = "Pack Spawner",
                    Description = tostring(PackId) .. " Buyed! price: " .. tostring(Price),
                    Icon = "lucide:shopping-cart",
                    Time = 4,
                })
            end
        end

        task.wait(1)
        IsHandlingSpawn = false
        NextSpawn()
    end

    -- server reports what just landed on the conveyor; decide whether to buy it based on the active rules
    Bind:Connect(ConveyorEvent.OnClientEvent, function(responseType, data)
        if not IsSpawnPackRunning then return end
        if responseType ~= "SpawnAndMoveToB" then return end
        if typeof(data) ~= "table" then return end

        -- a new pack arrived while we were waiting on cash for a previous one; drop that wait and re-evaluate this one instead
        if IsWaitingCash then
            Bind:Disconnect("SpawnPack_WaitCash")
            IsWaitingCash = false
            IsHandlingSpawn = false
        end

        if IsHandlingSpawn then return end
        IsHandlingSpawn = true

        CurrentSpawnThread = task.spawn(function()
            local PackId = data.PackId
            local Rarity = data.Rarity
            local Mutation = data.Mutation
            local Price = data.Price
            SpawnPackIdLabel:SetText("Pack: " .. tostring(PackId))
            SpawnPackRarityLabel:SetText("Rarity: " .. tostring(Rarity))
            SpawnPackMutationLabel:SetText("Mutation: " .. tostring(Mutation))
            SpawnPackPriceLabel:SetText("Price: " .. tostring(Price))
            -- a rule matches when this pack's rarity and mutation each meet or exceed that rule's minimum rank
            local RuleMatched = false
            for _, rule in pairs(PackSpawnRules) do
                local RarityOk = true
                local MutationOk = true

                if rule.Rarity and rule.Rarity ~= "Any" then
                    local minRank = RarityRankByName[rule.Rarity]
                    local curRank = Rarity and RarityRankByName[Rarity]
                    RarityOk = (minRank ~= nil) and (curRank ~= nil) and (curRank >= minRank)
                end

                if rule.Mutation and rule.Mutation ~= "Any" then
                    local minRank = MutationRankByName[rule.Mutation]
                    local curRank = Mutation and MutationRankByName[Mutation]
                    MutationOk = (minRank ~= nil) and (curRank ~= nil) and (curRank >= minRank)
                end

                if RarityOk and MutationOk then
                    RuleMatched = true
                    break
                end
            end

            if not RuleMatched then
                SpawnPackStatusLabel:SetText("Status: Skipped (Filter)")
                IsHandlingSpawn = false
                NextSpawn()
                return
            end

            -- notify-only mode: report the find and stop instead of buying it automatically
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
                if Library.Toggles.BuyPackWhenHaveEnoughMoney and Library.Toggles.BuyPackWhenHaveEnoughMoney.Value then
                    SpawnPackStatusLabel:SetText("Status: Waiting Money...")
                    Library:Notify({
                        Title = "Pack Spawner",
                        Description = tostring(PackId) .. " Found! Waiting Until You Have Enough Money, Price: " .. tostring(Price),
                        Icon = "lucide:wallet",
                        Time = 5,
                    })

                    IsWaitingCash = true
                    -- small buffer above the exact price to avoid stalling on rounding/precision in CashValue
                    local RequiredCash = Price * 1.0005
                    Bind:Connect(LocalPlayer.CashValue:GetPropertyChangedSignal("Value"), function()
                        if not IsSpawnPackRunning then
                            Bind:Disconnect("SpawnPack_WaitCash")
                            IsWaitingCash = false
                            return
                        end
                        if LocalPlayer.CashValue.Value >= RequiredCash then
                            Bind:Disconnect("SpawnPack_WaitCash")
                            IsWaitingCash = false
                            BuyPack(PackId, Price)
                        end
                    end, "SpawnPack_WaitCash")
                    return
                elseif Library.Toggles.SkipIfNotEnoughMoney.Value then
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

            BuyPack(PackId, Price)
        end)
    end, "SpawnPack_Result")

    fireclickdetector(ClickDetector) -- Spawn a Random Pack
end

local MinRarityDropdown = SpawnPackGroupbox:AddDropdown("MinRarity", {
    Text = "Min Rarity",
    Values = RarityNames,
    Default = 1,
    Multi = false,
})

local MinMutationDropdown = SpawnPackGroupbox:AddDropdown("MinMutation", {
    Text = "Min Mutation",
    Values = MutationNames,
    Default = 1,
    Multi = false,
})

local function FormatRuleLabel(rule)
    return "R: " .. rule.Rarity .. " / M: " .. rule.Mutation
end

local function BuildPackRuleValues()
    local values = {}
    for id = 1, NextRuleId - 1 do
        local rule = PackSpawnRules[id]
        if rule then
            table.insert(values, id .. ": " .. FormatRuleLabel(rule))
        end
    end
    return values
end

-- re-numbers rules from 1 after a deletion, so ids stay contiguous for BuildPackRuleValues
local function ReindexPackSpawnRules()
    local ordered = {}
    for id = 1, NextRuleId - 1 do
        local rule = PackSpawnRules[id]
        if rule then
            table.insert(ordered, rule)
        end
    end

    PackSpawnRules = {}
    for i, rule in ipairs(ordered) do
        PackSpawnRules[i] = rule
    end
    NextRuleId = #ordered + 1
end

SpawnPackGroupbox:AddButton({
    Text = "Set Rule",
    Func = function()
        local rarity = Library.Options.MinRarity.Value
        local mutation = Library.Options.MinMutation.Value

        PackSpawnRules[NextRuleId] = {Rarity = rarity, Mutation = mutation}
        NextRuleId = NextRuleId + 1

        Library.Options.PackRule:SetValues(BuildPackRuleValues())
    end,
})

local PackRuleDropdown = SpawnPackGroupbox:AddDropdown("PackRule", {
    Text = "Rule",
    Values = BuildPackRuleValues(),
    Multi = true,
    AllowNull = true,
    Searchable = true,
})

SpawnPackGroupbox:AddButton({
    Text = "Delete Rule",
    Func = function()
        local selected = Library.Options.PackRule.Value

        if not selected or next(selected) == nil then
            Library:Notify({
                Title = "Pack Spawner",
                Description = "No rule selected in Rule dropdown.",
                Icon = "solar:danger-triangle-bold",
                Time = 4,
            })
            return
        end

        for label in pairs(selected) do
            local idStr = tostring(label):match("^(%d+):")
            if idStr then
                PackSpawnRules[tonumber(idStr)] = nil
            end
        end

        ReindexPackSpawnRules()

        Library.Options.PackRule:SetValues(BuildPackRuleValues())
    end,
})

-- SkipIfNotEnoughMoney and BuyPackWhenHaveEnoughMoney are mutually exclusive, each turns the other off
local SkipIfNotEnoughMoneyToggle = SpawnPackGroupbox:AddToggle("SkipIfNotEnoughMoney", {
    Text = "Skip If Not Have Enough Money",
    Default = false,
    Callback = function(state)
        if state and Library.Toggles.BuyPackWhenHaveEnoughMoney and Library.Toggles.BuyPackWhenHaveEnoughMoney.Value then
            Library.Toggles.BuyPackWhenHaveEnoughMoney:SetValue(false)
        end
    end,
})

local BuyPackWhenHaveEnoughMoneyToggle = SpawnPackGroupbox:AddToggle("BuyPackWhenHaveEnoughMoney", {
    Text = "Buy When Have Enough Money",
    Default = false,
    Callback = function(state)
        if state then
            if Library.Toggles.SkipIfNotEnoughMoney and Library.Toggles.SkipIfNotEnoughMoney.Value then
                Library.Toggles.SkipIfNotEnoughMoney:SetValue(false)
            end
        else
            Bind:Disconnect("SpawnPack_WaitCash")
        end
    end,
})

local OnlyNotifyIfFoundToggle = SpawnPackGroupbox:AddToggle("OnlyNotifyIfFound", {
    Text = "Only Notify If Found",
    Default = false,
})

local AutoSpawnPackToggle = SpawnPackGroupbox:AddToggle("AutoSpawnPack", {
    Text = "Start Spawning Packs",
    Default = false,
    Callback = function(state)
        if state then
            if next(PackSpawnRules) == nil then
                Library:Notify({
                    Title = "Pack Spawner",
                    Description = "Make a Rule First",
                    Icon = "solar:danger-triangle-bold",
                    Time = 4,
                })
                if Library.Toggles.AutoSpawnPack then
                    Library.Toggles.AutoSpawnPack:SetValue(false)
                end
                return
            end
            task.spawn(SpawnPackAndBuy)
        else
            DisableSpawnPack()
        end
    end,
})

--[[ Misc ]]--
local MiscGroupbox = Tabs.Home:AddLeftGroupbox("Misc", "lucide:settings-2")

local Vim = nil
pcall(function() Vim = game:GetService("VirtualInputManager") end)

local afkMode = nil

-- VirtualInputManager is used when available (real tap/keypress); otherwise fall back to forcing a jump state
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

local NoRenderToggle = MiscGroupbox:AddToggle("NoRender", {
    Text = "No Render",
    Tooltip = "Disables 3D rendering to boost FPS.",
    Default = false,
    Callback = function(v)
        pcall(function()
            RunService:Set3dRenderingEnabled(not v)
        end)
    end,
})

local UnloadButton = MiscGroupbox:AddButton({
    Text = "Unload",
    Tooltip = "Stops all active features and completely unloads the script UI.",
    Risky = true,
    DoubleClick = true,
    Func = function()
        local UnloadDialog
        UnloadDialog = Window:AddDialog("UnloadConfirmDialog", {
            Title = "Unload Script",
            Description = "This will stop all active features and permanently remove the UI. Continue?",
            Icon = "lucide:power",
            AutoDismiss = true,
            OutsideClickDismiss = true,
            FooterButtons = {
                Cancel = {
                    Title = "Cancel",
                    Variant = "Secondary",
                    Order = 1,
                    Callback = function() end,
                },
                Confirm = {
                    Title = "Unload",
                    Variant = "Primary",
                    Order = 2,
                    Callback = function()
                        -- turn off anything with a running thread/connection first, so nothing keeps running after the UI is gone
                        local activeToggles = {
                            "AntiAFK",
                            "NoRender",
                            "AutoSpawnPack",
                        }

                        for _, toggleName in ipairs(activeToggles) do
                            local toggle = Library.Toggles[toggleName]
                            if toggle and toggle.Value then
                                toggle:SetValue(false)
                            end
                        end

                        Library:Unload()
                    end,
                },
            },
        })
    end,
})

--[[ Settings ]]--
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetFolder("Noname-ACF")
SaveManager:BuildConfigSection(Tabs.Settings)

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("Noname-ACF")
ThemeManager:ApplyToTab(Tabs.Settings)

SaveManager:LoadAutoloadConfig()

