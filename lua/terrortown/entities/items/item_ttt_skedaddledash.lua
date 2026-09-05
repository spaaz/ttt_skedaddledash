-- The TTT2 version
if SERVER then
    AddCSLuaFile()
    resource.AddFile("materials/vgui/ttt/icon_skedaddledash.png")
end

--ITEM.hud = Material("vgui/ttt/hud_skedaddledash.png")

ITEM.EquipMenuData = {
    type = "item_active",
    name = "Skedaddledash",
    desc = "Double-tap SPRINT to teleport to safety,\nleaving all of your items behind in the\nprocess.\n\nHas a cooldown",
}

ITEM.credits = 1
ITEM.material = "vgui/ttt/icon_skedaddledash.png"

function ITEM:InitSetup()
    self.CanBuy = {}

    local cvarTraitor = GetConVar("ttt_skedaddledash_traitor")
    if cvarTraitor and cvarTraitor:GetBool() then
        self.CanBuy[ROLE_TRAITOR] = true
    end

    local cvarDetective = GetConVar("ttt_skedaddledash_detective")
    if cvarDetective and cvarDetective:GetBool() then
        self.CanBuy[ROLE_DETECTIVE] = true
    end
end

if SERVER then
    function ITEM:Bought(ply)
        local curPos = ply:GetPos()
        
        ply:SetNWBool("HasSkedaddledash", true)
        ply:ChatPrint("SKEDADDLEDASH:\nDouble-tap sprint to teleport to safety, leaving all items behind.")
        
        local cvarSound = GetConVar("ttt_skedaddledash_buy_sound")
        if cvarSound and cvarSound:GetBool() then
            sound.Play("skedadledash.buy", curPos, 80, 100, 1.0)
        end
    end
end

if CLIENT then
	hook.Add("HUDPaint", "SkedaddledashHUDTTT2", function()
		ply = ply or LocalPlayer()
		if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

		local hasPassive = ply:GetNWBool("HasSkedaddledash", false)
		if not hasPassive then return end

		local nextUse = ply:GetNWFloat("SkedaddledashNextUse", 0)
		local remaining = math.max(0, math.ceil(nextUse - CurTime()))

		local x = ScrW() - 140
		local y = ScrH() - 70

		surface.SetDrawColor(35, 55, 76, 255)
		surface.DrawRect(x, y, 118, 40)

		draw.SimpleText("SKEDADDLEDASH", "Trebuchet18", x + 10, y + 5, Color(255, 255, 255))

		if remaining > 0 then
			draw.SimpleText(remaining .. "s", "Trebuchet18", x + 10, y + 20, Color(255, 100, 100))
		else
			draw.SimpleText("READY", "Trebuchet18", x + 10, y + 20, Color(255, 255, 255))
		end
	end)
end
