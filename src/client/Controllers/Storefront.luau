--!strict
-- Transparent cosmetic storefront. Prices are shown by Roblox's own prompt;
-- this UI never invents urgency, randomized rewards, or combat benefits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Storefront = {}
local FONT = Enum.Font.GothamBold
local GOLD = Color3.fromRGB(240, 200, 80)

local function corner(parent: Instance, radius: number)
	local item = Instance.new("UICorner")
	item.CornerRadius = UDim.new(0, radius)
	item.Parent = parent
end

local function text(parent: Instance, value: string, position: UDim2, size: UDim2, z: number): TextLabel
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Position = position
	item.Size = size
	item.Font = FONT
	item.Text = value
	item.TextColor3 = Color3.fromRGB(230, 230, 238)
	item.TextScaled = true
	item.ZIndex = z
	item.Parent = parent
	return item
end

local function button(parent: Instance, value: string, position: UDim2, size: UDim2, color: Color3, z: number, callback: () -> ()): TextButton
	local item = Instance.new("TextButton")
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = position
	item.Size = size
	item.BackgroundColor3 = color
	item.BorderSizePixel = 0
	item.Font = FONT
	item.Text = value
	item.TextColor3 = Color3.new(1, 1, 1)
	item.TextScaled = true
	item.ZIndex = z
	item.Parent = parent
	corner(item, 8)
	item.Activated:Connect(callback)
	return item
end

function Storefront.attach(menuRoot: Frame): () -> ()
	local profile: any = {
		warBonds = 0,
		ownedCosmetics = {},
		equippedTitle = "",
		equippedTheme = "",
		lastDailyBondDay = -1,
		lastDailyBattleDay = -1,
		lastDailyWinDay = -1,
	}

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(0.58, 0, 0.76, 0)
	panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 60
	panel.Parent = menuRoot.Parent
	corner(panel, 14)
	local outline = Instance.new("UIStroke")
	outline.Color = GOLD
	outline.Transparency = 0.35
	outline.Parent = panel

	text(panel, "COMMANDER ARMORY", UDim2.fromScale(0.12, 0.035), UDim2.fromScale(0.76, 0.08), 61).TextColor3 = GOLD
	local balance = text(panel, "WAR BONDS: 0", UDim2.fromScale(0.08, 0.12), UDim2.fromScale(0.42, 0.055), 61)
	balance.TextXAlignment = Enum.TextXAlignment.Left
	local equipped = text(panel, "LOADOUT: DEFAULT", UDim2.fromScale(0.5, 0.12), UDim2.fromScale(0.42, 0.055), 61)
	equipped.TextXAlignment = Enum.TextXAlignment.Right

	local daily = button(panel, "CLAIM DAILY SUPPLY", UDim2.fromScale(0.27, 0.22), UDim2.fromScale(0.36, 0.075), Color3.fromRGB(55, 125, 75), 62, function()
		if profile.lastDailyBondDay ~= math.floor(os.time() / 86400) then Remotes.ClaimDailyBonds:FireServer() end
	end)
	local dailyInfo = text(panel, "", UDim2.fromScale(0.08, 0.26), UDim2.fromScale(0.84, 0.065), 61)
	dailyInfo.TextColor3 = Color3.fromRGB(170, 180, 190)
	dailyInfo.TextWrapped = true

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromScale(0.07, 0.33)
	list.Size = UDim2.fromScale(0.86, 0.39)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ZIndex = 61
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local armoryButton: TextButton
	local refresh: () -> ()
	refresh = function()
		local collectionTotal = #MonetizationConfig.Cosmetics + #MonetizationConfig.EarnedCosmetics
		local collectionOwned = 0
		for _, cosmetic in MonetizationConfig.Cosmetics do
			if table.find(profile.ownedCosmetics or {}, cosmetic.id) then collectionOwned += 1 end
		end
		for _, cosmetic in MonetizationConfig.EarnedCosmetics do
			if table.find(profile.ownedCosmetics or {}, cosmetic.id) then collectionOwned += 1 end
		end
		balance.Text = `BONDS: {profile.warBonds or 0}  •  COLLECTION {collectionOwned}/{collectionTotal}`
		local title = MonetizationConfig.cosmeticById(profile.equippedTitle or "")
		local theme = MonetizationConfig.themeById(profile.equippedTheme or "")
		local titleName = title and string.upper(title.name) or "NONE"
		local themeName = theme and string.upper(theme.name) or "BLUE"
		equipped.Text = `TITLE: {titleName}  •  SIGNAL: {themeName}`
		local utcDay = math.floor(os.time() / 86400)
		local claimed = profile.lastDailyBondDay == utcDay
		local supporter = table.find(profile.ownedCosmetics or {}, MonetizationConfig.SupporterCosmetic.id) ~= nil
		local claimAmount = MonetizationConfig.DAILY_WAR_BONDS + (supporter and MonetizationConfig.SUPPORTER_DAILY_BONUS or 0)
		local supporterText = supporter and ` + {MonetizationConfig.SUPPORTER_DAILY_BONUS} supporter bonus` or ""
		daily.Text = claimed and "DAILY SUPPLY CLAIMED" or `CLAIM +{claimAmount}`
		daily.BackgroundColor3 = claimed and Color3.fromRGB(55, 60, 65) or Color3.fromRGB(55, 125, 75)
		daily.Active = not claimed
		armoryButton.Text = claimed and "ARMORY" or "ARMORY • SUPPLY READY"
		local battleDone = profile.lastDailyBattleDay == utcDay
		local winDone = profile.lastDailyWinDay == utcDay
		local supplyStatus = claimed and "DONE" or `+{claimAmount}`
		local battleStatus = battleDone and "DONE" or `+{MonetizationConfig.DAILY_BATTLE_BONDS}`
		local winStatus = winDone and "DONE" or `+{MonetizationConfig.DAILY_WIN_BONDS}`
		dailyInfo.Text = `ORDERS  •  Supply: {supplyStatus}  •  Battle: {battleStatus}  •  Victory: {winStatus}  •  Resets 00:00 UTC{supporterText}`
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then child:Destroy() end
		end
		local shownCosmetics: { any } = {}
		for _, cosmetic in MonetizationConfig.Cosmetics do table.insert(shownCosmetics, cosmetic) end
		for _, earned in MonetizationConfig.EarnedCosmetics do table.insert(shownCosmetics, earned) end
		local supporterOwned = table.find(profile.ownedCosmetics or {}, MonetizationConfig.SupporterCosmetic.id) ~= nil
		if MonetizationConfig.SUPPORTER_PASS_ID > 0 or supporterOwned then
			table.insert(shownCosmetics, MonetizationConfig.SupporterCosmetic)
		end
		for index, cosmetic in shownCosmetics do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 52)
			row.BackgroundColor3 = Color3.fromRGB(31, 31, 40)
			row.BorderSizePixel = 0
			row.LayoutOrder = index
			row.ZIndex = 62
			row.Parent = list
			corner(row, 7)
			local kindLabel = cosmetic.kind == "theme" and "ARMY SIGNAL" or "TITLE"
			local displayName = cosmetic.id == MonetizationConfig.SupporterCosmetic.id
				and `{kindLabel}  •  {cosmetic.name}  •  +{MonetizationConfig.SUPPORTER_DAILY_BONUS} daily`
				or `{kindLabel}  •  {cosmetic.name}`
			local name = text(row, displayName, UDim2.fromScale(0.04, 0.12), UDim2.fromScale(0.5, 0.76), 63)
			name.TextXAlignment = Enum.TextXAlignment.Left
			local owned = table.find(profile.ownedCosmetics or {}, cosmetic.id) ~= nil
			local selected = if cosmetic.kind == "theme" then profile.equippedTheme == cosmetic.id else profile.equippedTitle == cosmetic.id
			local supporter = cosmetic.id == MonetizationConfig.SupporterCosmetic.id
			local earned = cosmetic.unlockLevel ~= nil
			local configured = MonetizationConfig.SUPPORTER_PASS_ID > 0
			local canAfford = cosmetic.cost == nil or (profile.warBonds or 0) >= cosmetic.cost
			local action = selected and "EQUIPPED" or (owned and "EQUIP" or (earned and `LEVEL {cosmetic.unlockLevel}`
				or (supporter and "VIEW PASS" or (canAfford and `UNLOCK  {cosmetic.cost}` or `NEED {cosmetic.cost - (profile.warBonds or 0)}`))))
			local color = selected and Color3.fromRGB(55, 95, 65) or (owned and Color3.fromRGB(65, 105, 150) or Color3.fromRGB(145, 105, 35))
			if not canAfford and not earned and not supporter then color = Color3.fromRGB(75, 55, 55) end
			if cosmetic.kind == "theme" and cosmetic.color then
				color = selected and cosmetic.color:Lerp(Color3.new(0, 0, 0), 0.35) or cosmetic.color:Lerp(Color3.new(0, 0, 0), 0.5)
			end
			local actionButton = button(row, action, UDim2.fromScale(0.78, 0.5), UDim2.fromScale(0.36, 0.68), color, 63, function()
				if selected then return end
				if owned then
					Remotes.EquipCosmetic:FireServer(cosmetic.id)
				elseif earned then
					return
				elseif supporter then
					if configured then Remotes.PromptSupporterPass:FireServer() end
				elseif canAfford then
					Remotes.BuyCosmetic:FireServer(cosmetic.id)
				end
			end)
			actionButton.Active = not selected and (owned or supporter or (not earned and canAfford))
		end
		list.CanvasSize = UDim2.fromOffset(0, #shownCosmetics * 59)
	end

	local enabledProducts: { any } = {}
	for _, product in MonetizationConfig.Products do
		if product.productId > 0 then table.insert(enabledProducts, product) end
	end
	local storeHeading = text(panel, #enabledProducts > 0 and "OPTIONAL COSMETIC SUPPORT" or "EARN WAR BONDS THROUGH DAILY ORDERS", UDim2.fromScale(0.08, 0.75), UDim2.fromScale(0.84, 0.045), 61)
	storeHeading.TextColor3 = GOLD
	for index, product in enabledProducts do
		local x = (index - 0.5) / #enabledProducts
		button(panel, product.name, UDim2.fromScale(x, 0.825), UDim2.fromScale(math.min(0.26, 0.82 / #enabledProducts), 0.06), Color3.fromRGB(85, 65, 130), 62, function()
			Remotes.PromptProduct:FireServer(product.id)
		end)
	end
	local commerceNote = #enabledProducts > 0
		and "Cosmetics only. No paid unit stats, gold, XP, or matchmaking advantage."
		or "Complete a battle and earn your first victory each day. Missing a day never removes progress."
	text(panel, commerceNote, UDim2.fromScale(0.08, 0.865), UDim2.fromScale(0.84, 0.035), 61).TextColor3 = Color3.fromRGB(170, 180, 190)

	button(panel, "CLOSE", UDim2.fromScale(0.5, 0.94), UDim2.fromScale(0.22, 0.065), Color3.fromRGB(65, 65, 75), 62, function()
		panel.Visible = false
	end)

	local function open()
		panel.Visible = true
		refresh()
	end
	armoryButton = button(menuRoot, "ARMORY", UDim2.fromScale(0.09, 0.60), UDim2.new(0.13, 0, 0.055, 0), Color3.fromRGB(105, 75, 145), 4, open)

	Remotes.ProfileSync.OnClientEvent:Connect(function(newProfile)
		if typeof(newProfile) == "table" then
			profile = newProfile
			refresh()
		end
	end)
	refresh()
	return open
end

return Storefront
