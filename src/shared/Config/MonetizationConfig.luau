--!strict
-- Fair monetization catalog. Nothing sold here changes combat stats, gold,
-- matchmaking, unit caps, or unlocks. Product/pass IDs are configured after
-- the experience is published; zero keeps that offer safely disabled.

local MonetizationConfig = {}

MonetizationConfig.DAILY_WAR_BONDS = 10
MonetizationConfig.DAILY_BATTLE_BONDS = 5
MonetizationConfig.DAILY_WIN_BONDS = 5
MonetizationConfig.SUPPORTER_DAILY_BONUS = 5
MonetizationConfig.SUPPORTER_PASS_ID = 0

MonetizationConfig.Products = {
	{ id = "bonds_small", productId = 0, name = "100 War Bonds", amount = 100 },
	{ id = "bonds_medium", productId = 0, name = "280 War Bonds", amount = 280 },
	{ id = "bonds_large", productId = 0, name = "650 War Bonds", amount = 650 },
}

MonetizationConfig.Cosmetics = {
	{ id = "title_tactician", kind = "title", name = "The Tactician", cost = 60 },
	{ id = "title_vanguard", kind = "title", name = "Vanguard", cost = 120 },
	{ id = "title_timewalker", kind = "title", name = "Timewalker", cost = 240 },
	{ id = "theme_royal", kind = "theme", name = "Royal Signal", cost = 180, color = Color3.fromRGB(175, 105, 255) },
	{ id = "theme_solar", kind = "theme", name = "Solar Signal", cost = 300, color = Color3.fromRGB(255, 190, 55) },
	{ id = "theme_arc", kind = "theme", name = "Arc Signal", cost = 450, color = Color3.fromRGB(45, 225, 205) },
}

MonetizationConfig.EarnedCosmetics = {
	{ id = "title_recruit", kind = "title", name = "Recruit", unlockLevel = 2 },
	{ id = "title_skirmisher", kind = "title", name = "Skirmisher", unlockLevel = 5 },
	{ id = "title_veteran", kind = "title", name = "Veteran", unlockLevel = 10 },
	{ id = "title_strategist", kind = "title", name = "Strategist", unlockLevel = 15 },
	{ id = "title_commander", kind = "title", name = "Commander", unlockLevel = 20 },
	{ id = "title_warlord", kind = "title", name = "Warlord", unlockLevel = 30 },
	{ id = "title_agebreaker", kind = "title", name = "Agebreaker", unlockLevel = 40 },
	{ id = "title_eternal", kind = "title", name = "Eternal Commander", unlockLevel = 50 },
}

MonetizationConfig.SupporterCosmetic = {
	id = "title_patron",
	kind = "title",
	name = "Founding Patron",
	dailyBonus = MonetizationConfig.SUPPORTER_DAILY_BONUS,
}

function MonetizationConfig.themeById(id: string): any?
	local cosmetic = MonetizationConfig.cosmeticById(id)
	return cosmetic and cosmetic.kind == "theme" and cosmetic or nil
end

function MonetizationConfig.cosmeticById(id: string): any?
	for _, cosmetic in MonetizationConfig.Cosmetics do
		if cosmetic.id == id then return cosmetic end
	end
	for _, cosmetic in MonetizationConfig.EarnedCosmetics do
		if cosmetic.id == id then return cosmetic end
	end
	if id == MonetizationConfig.SupporterCosmetic.id then return MonetizationConfig.SupporterCosmetic end
	return nil
end

function MonetizationConfig.productByKey(key: string): any?
	for _, product in MonetizationConfig.Products do
		if product.id == key then return product end
	end
	return nil
end

function MonetizationConfig.productByRobloxId(productId: number): any?
	for _, product in MonetizationConfig.Products do
		if product.productId > 0 and product.productId == productId then return product end
	end
	return nil
end

function MonetizationConfig.configuredOfferCount(): number
	local count = MonetizationConfig.SUPPORTER_PASS_ID > 0 and 1 or 0
	for _, product in MonetizationConfig.Products do
		if product.productId > 0 then count += 1 end
	end
	return count
end

return MonetizationConfig
