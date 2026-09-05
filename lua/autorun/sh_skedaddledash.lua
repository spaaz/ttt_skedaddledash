if TTT2 then return end

if SERVER then
	AddCSLuaFile()
end

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

