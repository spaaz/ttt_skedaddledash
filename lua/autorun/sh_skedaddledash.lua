if TTT2 then return end

if SERVER then
	AddCSLuaFile()
end

CreateConVar("ttt_skedaddledash_cooldown", "90", bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "Cooldown duration in seconds for Skedaddledash ability.", 10, 300)
CreateConVar("ttt_skedaddledash_traitor", 1, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "If traitors can buy the skedaddledash", 0, 1)
CreateConVar("ttt_skedaddledash_detective", 1, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "If detectives can buy the skedaddledash", 0, 1)

local function RegisterSkedaddledashEquipment()
	EQUIP_SKEDADDLEDASH = EQUIP_SKEDADDLEDASH or ( GenerateNewEquipmentID and GenerateNewEquipmentID() ) or 131072
	local itemData = {
		id = EQUIP_SKEDADDLEDASH,
		type = "item_active",
		name = "Skedaddledash",
		desc = "Double-tap SPRINT to teleport to safety,\nleaving all of your items behind in the\nprocess.\n\nHas a cooldown",
		material = "vgui/ttt/icon_skedaddledash.png",
		loadout = false,
		hud = true
	}
	
	if GetConVar("ttt_skedaddledash_traitor"):GetBool() then
		table.insert(EquipmentItems[ROLE_TRAITOR], itemData)
	end
	if GetConVar("ttt_skedaddledash_detective"):GetBool() then
		table.insert(EquipmentItems[ROLE_DETECTIVE], itemData)
	end
	
end

hook.Add("Initialize", "RegisterSkedaddledashSharedInit", RegisterSkedaddledashEquipment)

