--!strict
-- Server-authoritative, cosmetic-only commerce and daily allowance.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(script.Parent.PlayerData)
local Telemetry = require(script.Parent.Telemetry)

local MonetizationService = {}
local lastAction: { [Player]: number } = {}

local function allowed(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.35 then return false end
	lastAction[player] = now
	return true
end

local function syncAndSave(player: Player)
	PlayerData.sync(player)
	task.spawn(function() PlayerData.save(player) end)
end

function MonetizationService.refreshSupporterEntitlement(player: Player)
	local passId = MonetizationConfig.SUPPORTER_PASS_ID
	player:SetAttribute("SupporterChecked", false)
	if passId <= 0 then
		player:SetAttribute("SupporterChecked", true)
		return
	end
	task.spawn(function()
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
		end)
		if ok and owns and PlayerData.grantCosmetic(player, MonetizationConfig.SupporterCosmetic.id) then
			PlayerData.sync(player)
		end
		if player.Parent then player:SetAttribute("SupporterChecked", true) end
	end)
end

function MonetizationService.start()
	local configuredOffers = MonetizationConfig.configuredOfferCount()
	if configuredOffers == 0 then
		warn("[Monetization] No paid offers configured; free War Bond earning and cosmetics remain available")
	else
		print(`[Monetization] {configuredOffers} paid offer(s) configured; receipt processing enabled`)
	end

	Remotes.ClaimDailyBonds.OnServerEvent:Connect(function(player)
		if not allowed(player) then return end
		if MonetizationConfig.SUPPORTER_PASS_ID > 0 and player:GetAttribute("SupporterChecked") ~= true then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, MonetizationConfig.SUPPORTER_PASS_ID)
			end)
			if not ok then return end
			if owns then PlayerData.grantCosmetic(player, MonetizationConfig.SupporterCosmetic.id) end
			player:SetAttribute("SupporterChecked", true)
		end
		local claimed, amount = PlayerData.claimDailyBonds(player)
		if claimed then
			Telemetry.event(player, "daily_bonds_claimed", amount)
			syncAndSave(player)
		end
	end)

	Remotes.BuyCosmetic.OnServerEvent:Connect(function(player, cosmeticId)
		if not allowed(player) or typeof(cosmeticId) ~= "string" or #cosmeticId > 64 then return end
		if PlayerData.buyCosmetic(player, cosmeticId) then
			Telemetry.event(player, "cosmetic_unlocked", 1, { cosmeticId = cosmeticId })
			syncAndSave(player)
		end
	end)

	Remotes.EquipCosmetic.OnServerEvent:Connect(function(player, cosmeticId)
		if not allowed(player) or typeof(cosmeticId) ~= "string" or #cosmeticId > 64 then return end
		if PlayerData.equipCosmetic(player, cosmeticId) then syncAndSave(player) end
	end)

	Remotes.PromptProduct.OnServerEvent:Connect(function(player, productKey)
		if not allowed(player) or typeof(productKey) ~= "string" or #productKey > 64 then return end
		local product = MonetizationConfig.productByKey(productKey)
		if product and product.productId > 0 then
			MarketplaceService:PromptProductPurchase(player, product.productId)
		end
	end)

	Remotes.PromptSupporterPass.OnServerEvent:Connect(function(player)
		if allowed(player) and MonetizationConfig.SUPPORTER_PASS_ID > 0 then
			MarketplaceService:PromptGamePassPurchase(player, MonetizationConfig.SUPPORTER_PASS_ID)
		end
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if purchased and passId == MonetizationConfig.SUPPORTER_PASS_ID then
			PlayerData.grantCosmetic(player, MonetizationConfig.SupporterCosmetic.id)
			player:SetAttribute("SupporterChecked", true)
			syncAndSave(player)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local product = MonetizationConfig.productByRobloxId(receiptInfo.ProductId)
		if not product then
			warn(`[Monetization] Unknown product ID {receiptInfo.ProductId}; receipt left pending`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
		if PlayerData.grantProductReceipt(player, tostring(receiptInfo.PurchaseId), product.amount) then
			PlayerData.sync(player)
			Telemetry.event(player, "war_bonds_purchased", product.amount, { productKey = product.id })
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	Players.PlayerRemoving:Connect(function(player) lastAction[player] = nil end)
end

return MonetizationService
