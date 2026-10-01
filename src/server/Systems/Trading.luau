-- Same-server, same-slot equipment exchanges; both players review and confirm.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Logic = require(ReplicatedStorage.Shared.EquipmentTrade)
local Classes = require(ReplicatedStorage.Shared.Classes)
local Slots = require(ReplicatedStorage.Shared.EquipmentSlots)
local PlayerData = require(script.Parent.PlayerData)
local Journal = require(script.Parent.TradeJournal)
local Shop = require(script.Parent.Shop)
local Remotes = require(script.Parent.Remotes)
local Trading = {}
local sessions = {}
local function close(session, message)
	PlayerData.setTradeLocked(session.A, false)
	PlayerData.setTradeLocked(session.B, false)
	sessions[session.A] = nil
	sessions[session.B] = nil
	for _, player in { session.A, session.B } do
		if player.Parent then
			Remotes.Notify:FireClient(player, message)
		end
	end
end
local function current(player)
	local s = sessions[player]
	if s and not s.Saving and os.time() >= s.Expires then
		close(s, "Trade expired.")
		return nil
	end
	return s
end
local function validItem(player, slot, id)
	if typeof(slot) ~= "string" or typeof(id) ~= "string" then
		return nil
	end
	local def = Slots.Definitions[slot]
	local profile = PlayerData.get(player)
	if not def or not profile or not Classes.gear(profile.Character.Class, def.Kind, id) then
		return nil
	end
	return Logic.item(profile, slot, id)
end
local function view(s, player)
	return {
		Id = s.Id,
		Partner = (if player == s.A then s.B else s.A).DisplayName,
		Slot = s.Left.Slot,
		Left = s.Left,
		Right = s.Right,
		Initiator = player == s.A,
		OwnConfirmed = s.Confirmed[player] == true,
		PartnerConfirmed = s.Confirmed[if player == s.A then s.B else s.A] == true,
		Expires = s.Expires,
		Revision = s.Revision,
		Saving = s.Saving == true,
	}
end
function Trading.start()
	Shop.register("TradeState", function(player)
		local s = current(player)
		return Shop.reply(true, "", { Trade = if s then view(s, player) else nil })
	end)
	Shop.register("TradeOffer", function(player, targetId, slot, id)
		local item = validItem(player, slot, id)
		local target = if typeof(targetId) == "number"
				and targetId == targetId
				and targetId > 0
				and targetId < math.huge
				and targetId == math.floor(targetId)
			then Players:GetPlayerByUserId(targetId)
			else nil
		if not target or target == player or not item or not PlayerData.get(target) then
			return Shop.reply(false, "Select a player and equipment you own.")
		end
		if not PlayerData.canTrade(player) or not PlayerData.canTrade(target) then
			return Shop.reply(
				false,
				"Trading requires connected data storage for both players. Rejoin when saving is available."
			)
		end
		if PlayerData.get(player).Character.Class ~= PlayerData.get(target).Character.Class then
			return Shop.reply(false, "Trade equipment with an explorer of the same class.")
		end
		if current(player) or current(target) then
			return Shop.reply(false, "One player already has a pending trade.")
		end
		local s = {
			Id = HttpService:GenerateGUID(false),
			A = player,
			B = target,
			Left = item,
			Revision = 1,
			Confirmed = {},
			Expires = os.time() + 120,
		}
		sessions[player] = s
		sessions[target] = s
		Remotes.Notify:FireClient(target, player.DisplayName .. " offered equipment. Open Trade [T] to review.")
		return Shop.reply(
			true,
			"Offer sent. Your partner chooses an item from the same slot.",
			{ Trade = view(s, player) }
		)
	end)
	Shop.register("TradeCounter", function(player, sessionId, id)
		local s = current(player)
		if not s or s.Saving or s.Id ~= sessionId or s.B ~= player then
			return Shop.reply(false, "No matching incoming offer.")
		end
		local item = validItem(player, s.Left.Slot, id)
		if not item then
			return Shop.reply(false, "You do not own that item.")
		end
		s.Revision += 1
		s.Right = item
		s.Confirmed = {}
		return Shop.reply(true, "Counteroffer set. Both players must confirm.", { Trade = view(s, player) })
	end)
	Shop.register("TradeConfirm", function(player, sessionId, revision)
		local s = current(player)
		if not s or s.Saving or s.Id ~= sessionId or s.Revision ~= revision or not s.Right then
			return Shop.reply(false, "Wait for both items to be selected.")
		end
		s.Confirmed[player] = true
		if not (s.Confirmed[s.A] and s.Confirmed[s.B]) then
			return Shop.reply(true, "Confirmed. Waiting for your partner.", { Trade = view(s, player) })
		end
		local a, b = PlayerData.get(s.A), PlayerData.get(s.B)
		if not a or not b then
			close(s, "Trade cancelled: a player left.")
			return Shop.reply(false, "Trade cancelled.")
		end
		s.Saving = true
		PlayerData.setTradeLocked(s.A, true)
		PlayerData.setTradeLocked(s.B, true)
		local persisted, reason = Journal.commit(
			s.Id,
			s.A.UserId,
			s.B.UserId,
			s.Left,
			s.Right,
			a.Character[s.Left.Slot] == s.Left.Id,
			b.Character[s.Right.Slot] == s.Right.Id,
			function()
				if not s.A.Parent or not s.B.Parent then
					return false
				end
				-- Revalidate using copies; the journal preparation itself must not mutate live profiles.
				local leftNow = Logic.item(a, s.Left.Slot, s.Left.Id)
				local rightNow = Logic.item(b, s.Right.Slot, s.Right.Id)
				return Logic.matches(leftNow, s.Left)
					and Logic.matches(rightNow, s.Right)
					and Logic.validate(a, b, s.Left, s.Right)
			end
		)
		if not persisted then
			if reason == "uncertain" then
				for _, p in { s.A, s.B } do
					PlayerData.suspendSaving(p)
					if p.Parent then
						p:Kick("Trade save could not be confirmed. Rejoin to recover the exchange safely.")
					end
				end
			end
			close(s, "Trade was not completed. Rejoin if data storage is unavailable.")
			return Shop.reply(false, "Trade save unavailable; no further exchanges are allowed until recovery.")
		end
		-- After commit, recovery owns the final result even if a participant left.
		local ok, message = Logic.exchange(a, b, s.Left, s.Right)
		if ok then
			Journal.mark(a, s.Id)
			Journal.mark(b, s.Id)
		end
		if ok then
			for _, p in { s.A, s.B } do
				if not PlayerData.get(p) then
					continue
				end
				PlayerData.sync(p)
				local profile = PlayerData.get(p)
				PlayerData.equipGear(p, Slots.Definitions[s.Left.Slot].Kind, profile.Character[s.Left.Slot])
				PlayerData.milestone(p, "Traded")
				task.spawn(PlayerData.save, p)
			end
		end
		close(s, message)
		return Shop.reply(ok, message)
	end)
	Shop.register("TradeCancel", function(player, sessionId)
		local s = current(player)
		if s and not s.Saving and s.Id == sessionId then
			close(s, "Trade cancelled.")
		end
		return Shop.reply(true, "Trade closed.")
	end)
	Players.PlayerRemoving:Connect(function(player)
		local s = sessions[player]
		if s and not s.Saving then
			close(s, "Trade cancelled: a player left.")
		end
	end)
end
return Trading
