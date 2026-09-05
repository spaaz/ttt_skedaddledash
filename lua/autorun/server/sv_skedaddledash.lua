AddCSLuaFile()

-- Network String Registrations
util.AddNetworkString("SkedaddledashStartCast")
util.AddNetworkString("SkedaddledashRejectCast")
util.AddNetworkString("SkedaddledashPlaySkidSound")
util.AddNetworkString("SkedaddledashSmokePuff")

-- Force client download
resource.AddFile("sound/cartoon-sound-fx-funny-run.wav")
resource.AddFile("sound/cartoon-skid-stop-fx.wav")
resource.AddFile("sound/skedaddledash_buy.wav")

-- Sound Path Definitions
local SOUND_RUN = "cartoon-sound-fx-funny-run.wav"
local SOUND_SKID = "cartoon-skid-stop-fx.wav"
local SOUND_BUY = "skedaddledash_buy.wav"

sound.Add({
    name = "skedadledash.run",
    channel = CHAN_AUTO,
    volume = 1.0,
    level = 80,
    pitch = 100,
    sound = SOUND_RUN
})

sound.Add({
    name = "skedadledash.skid",
    channel = CHAN_AUTO,
    volume = 0.35,
    level = 80,
    pitch = 100,
    sound = SOUND_SKID
})

sound.Add({
    name = "skedadledash.buy",
    channel = CHAN_AUTO,
    volume = 1.0,
    level = 80,
    pitch = 100,
    sound = SOUND_BUY
})

local cv_cooldown = CreateConVar("ttt_skedaddledash_cooldown", "90", bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "Cooldown duration in seconds for Skedaddledash ability.", 10, 300)
CreateConVar("ttt_skedaddledash_buy_sound", 1, FCVAR_ARCHIVE, "If a sound plays when you buy the Skedaddledash", 0, 1)
CreateConVar("ttt_skedaddledash_traitor", 1, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "If traitors can buy the skedaddledash", 0, 1)
CreateConVar("ttt_skedaddledash_detective", 1, bit.bor(FCVAR_REPLICATED, FCVAR_ARCHIVE), "If detectives can buy the skedaddledash", 0, 1)

-- Grant passive state on buy
hook.Add("TTTOrderedEquipment", "SkedaddledashOnBuy", function(ply, equipID, isItem)
    if isItem and tonumber(equipID) == EQUIP_SKEDADDLEDASH then
		local curPos = ply:GetPos()
		ply:GiveEquipmentItem(EQUIP_SKEDADDLEDASH)
        ply:SetNWBool("HasSkedaddledash", true)
        ply:ChatPrint("SKEDADDLEDASH:\nDouble-tap sprint to teleport to safety, leaving all items behind.")
		
		if GetConVar("ttt_skedaddledash_buy_sound"):GetBool() then
			sound.Play("skedadledash.buy", curPos, 80, 100, 1.0)
		end
    end
end)

-- 1. Damage Immunity Hook
hook.Add("EntityTakeDamage", "SkedaddledashBarnacleCastImmunity", function(target, dmginfo)
    if IsValid(target) and target:IsPlayer() and target.SkedaddledashBarnacleGrace and target:IsEFlagSet(EFL_IS_BEING_LIFTED_BY_BARNACLE) then
        local dmgType = dmginfo:GetDamageType()
        
        -- Block Fall Damage, Crush Damage, and general Physics Collision Damage
        if dmginfo:IsFallDamage() or 
           dmgType == DMG_FALL or 
           dmgType == DMG_CRUSH or 
           dmgType == DMG_CLUB then
            dmginfo:ScaleDamage(0)
            dmginfo:SetDamage(0)
            return true
        end
    end
end)

concommand.Add("ttt_give_skedadledash", function(ply)
    if IsValid(ply) and (ply:IsAdmin() or ply:IsSuperAdmin()) then
        ply:SetNWBool("HasSkedaddledash", true)
        ply:ChatPrint("[SKEDADDLEDASH] Force-granted passive ability")
    end
end)

local function ClearSkedaddledashState(ply)
    if IsValid(ply) then
        ply:SetNWBool("HasSkedaddledash", false)
        ply:SetNWFloat("SkedaddledashNextUse", 0)
        ply:SetNWBool("SkedaddledashIsCasting", false)
        ply:SetNWBool("SkedaddledashIsLanding", false)
		
		if IsValid(ply.SkedaddledashSoundEnt) then
			ply.SkedaddledashSoundEnt:StopSound("skedadledash.run")
            ply.SkedaddledashSoundEnt:StopSound("cartoon-sound-fx-funny-run.wav")
			ply.SkedaddledashSoundEnt:Remove()
			ply.SkedaddledashSoundEnt = nil
		end
    end
end

hook.Add("DoPlayerDeath", "SkedaddledashDeathCleanup", function(ply)
	
	if ply:GetNWBool("SkedaddledashIsCasting", false) then
		ply:ChatPrint("You died before you could get away")
	end
	
    ClearSkedaddledashState(ply)
end)

hook.Add("TTTPrepareRound", "SkedaddledashRoundReset", function()
    for _, ply in ipairs(player.GetAll()) do
        ClearSkedaddledashState(ply)
    end
end)

hook.Add("TTTPlayerRoleChanged", "SkedaddledashRoleReset", function(ply, oldRole, newRole)
	if IsValid(ply) then
		ClearSkedaddledashState(ply)
	end
end)


-- Track when a player enters the trapped state
hook.Add("Think", "Skedaddledash_TrackPlayerTrapperTime", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply.PAPPlayerTrapperTrapped then
            if not ply.PAPPlayerTrapperStartTime then
                ply.PAPPlayerTrapperStartTime = CurTime()
            end
        else
            -- ONLY clear start time if we are NOT currently running a cleanse!
            if ply.PAPPlayerTrapperStartTime and not ply.PAPCleansing then
                ply.PAPPlayerTrapperStartTime = nil
            end
        end
    end
end)

local lastOwner = nil

-- Spatial Caching
local LowestSpawnZ = nil
local CachedSpawnPositions = {}
local function RecacheMapPositions()

	local minZ = math.huge
    CachedSpawnPositions = {}
	
	for _, ent in ipairs(ents.FindByClass("info_player_*")) do
		if IsValid(ent) then
			local pos = ent:GetPos()
			table.insert(CachedSpawnPositions, pos)
			
			if pos.Z < minZ then
				minZ = pos.Z
			end
		end
    end
	
	LowestSpawnZ = (minZ ~= math.huge) and minZ or -16384
	
	for _, ent in ipairs(ents.FindByClass("weapon_*")) do
		if IsValid(ent) then
			local pos = ent:GetPos()
			if pos.Z > (LowestSpawnZ - 600) then
				table.insert(CachedSpawnPositions, pos)
			end
		end
    end
end

hook.Add("InitPostEntity", "SkedaddledashCachePositionsInit", RecacheMapPositions)
hook.Add("TTTPrepareRound", "SkedaddledashCachePositionsRound", RecacheMapPositions)

-- Shark Trap Immunity Hook
hook.Add("EntityTakeDamage", "SkedaddledashSharkTrapImmunity", function(target, dmginfo)
    if IsValid(target) and target:IsPlayer() and target.SkedaddledashSharkGrace then
        local inflictor = dmginfo:GetInflictor()
        if IsValid(inflictor) then
            local class = inflictor:GetClass()
            if class == "ttt_shark_trap" or class == "ttt_pap_left_shark_trap" then
                dmginfo:SetDamage(0)
                return true
            end
        end
    end
end)

-- dance gun Immunity (random music)
hook.Add("EntityTakeDamage", "Skedaddledash_DanceGunGracePeriod", function(target, dmginfo)
    if not IsValid(target) or not target:IsPlayer() then return end

    if target.SkedaddledashDanceGrace and CurTime() < target.SkedaddledashDanceGrace then
        local inflictor = dmginfo:GetInflictor()

        if IsValid(inflictor) and inflictor:GetClass() == "weapon_ttt_dancedead" then
            dmginfo:SetDamage(0)
            return true 
        end
    end
end)

-- Redirect Shark Entity
hook.Add("OnEntityCreated", "SkedaddledashCleanSharkEntity", function(ent)
    timer.Simple(0, function()
        if not IsValid(ent) then return end
        local class = ent:GetClass()

        if class == "ttt_shark_ent" or class == "ttt_pap_left_shark_ent" then
            local sharkPos2D = ent:GetPos() * Vector(1, 1, 0)
            for _, ply in ipairs(player.GetAll()) do
                if ply.SkedaddledashSharkGrace and ply.SkedaddledashOriginPos then
                    local origPos2D = ply.SkedaddledashOriginPos * Vector(1, 1, 0)
                    local curPos2D = ply:GetPos() * Vector(1, 1, 0)
                    if origPos2D:DistToSqr(sharkPos2D) <= 9 or curPos2D:DistToSqr(sharkPos2D) <= 9 then
                        ent:SetPos(ply.SkedaddledashOriginPos + Vector(0, 0, -75))
                        break
                    end
                end
            end
        end
    end)
end)

local function FindFurthestValidPos(ply)
    local plyPos = ply:GetPos()
    local mins, maxs = ply:OBBMins(), ply:OBBMaxs()

    if #CachedSpawnPositions == 0 then RecacheMapPositions() end

    -- Copy vector references into candidate list
    local candidatePositions = table.Copy(CachedSpawnPositions)

    -- Sort raw vectors directly by furthest distance from player
    table.sort(candidatePositions, function(a, b)
        return plyPos:DistToSqr(a) > plyPos:DistToSqr(b)
    end)

    local maxChecks = 25
    local checksDone = 0

    for _, rawPos in ipairs(candidatePositions) do
	
        local floorTr = util.TraceHull({
            start = rawPos + Vector(0, 0, 32),
            endpos = rawPos - Vector(0, 0, 64),
            mins = mins,
            maxs = maxs,
            mask = MASK_PLAYERSOLID,
            filter = ply
        })

        local floorPos = floorTr.Hit and floorTr.HitPos or rawPos
        local checkPos = floorPos + Vector(0, 0, 10)
		
		if checkPos.z < (LowestSpawnZ - 600) then -- this is just to check if a location isn't well below the actual map
            continue 
        end

        local hullTr = util.TraceHull({
            start = checkPos,
            endpos = checkPos,
            mins = mins,
            maxs = maxs,
            filter = ply
        })

        checksDone = checksDone + 1

        if not hullTr.StartSolid then
            -- 1. Check point contents & surface material at the floor position
            local pointContents = util.PointContents(checkPos)
            local isWater = (bit.band(pointContents, CONTENTS_WATER) ~= 0) 
                         or (bit.band(pointContents, CONTENTS_SLIME) ~= 0) 
                         or (floorTr.MatType == MAT_WATER)

            -- 2. Scan player bounding box at floor position for trigger_hurt or func_water
            local isHazard = false
            for _, hazardEnt in ipairs(ents.FindInBox(checkPos + mins, checkPos + maxs)) do
                if IsValid(hazardEnt) then
                    local cls = hazardEnt:GetClass()
                    if cls == "trigger_hurt" or cls == "func_water" then
                        isHazard = true
                        break
                    end
                end
            end

            -- 3. Return the furthest valid floor position
            if not isWater and not isHazard then
                return floorPos
            end
        end

        if checksDone >= maxChecks then break end
    end

    return plyPos
end

local function CleansePlayer(ply, originalPos)

	if not IsValid(ply) or not ply:Alive() then return end
	
    local targetPos = originalPos or ply:GetPos()
    ply.SkedaddledashOriginPos = Vector(targetPos.x, targetPos.y, targetPos.z)
    local entIndex = ply:EntIndex()

    timer.Create("SkedaddledashOriginCleanup_" .. entIndex, 3, 1, function()
        if IsValid(ply) then ply.SkedaddledashOriginPos = nil end
    end)
	
	--Bear Trap
    if timer.Exists("beartrapdmg" .. entIndex) then timer.Destroy("beartrapdmg" .. entIndex) end
    ply.IsTrapped = false
    ply:Extinguish()
    
    --Barnacles
    --ply:SetVelocity(-ply:GetVelocity())
    ply:RemoveEFlags(EFL_IS_BEING_LIFTED_BY_BARNACLE)
    ply:SetParent(nil)
    
    for _, barnacle in ipairs(ents.FindByClass("npc_barnacle")) do
        if IsValid(barnacle) and barnacle:GetEnemy() == ply then         
            barnacle:Fire("LetGo", nil, 0, ply, ply)
        end
    end

	--Shark Trap
    ply.SkedaddledashSharkGrace = true
    timer.Create("SkedaddledashSharkGraceTimer_" .. entIndex, 2, 1, function()
        if IsValid(ply) then ply.SkedaddledashSharkGrace = nil end
    end)
	
	--Dance Guns
	ply:StopSound("thrilcut.wav")
	ply:StopSound("mjow.wav")

	local prefixes = { "reDance_Thriller", "reDance_DanceDead" }
	for _, prefix in ipairs(prefixes) do
		if timer.Exists(prefix .. "_Loop_" .. entIndex) then timer.Destroy(prefix .. "_Loop_" .. entIndex) end
		if timer.Exists(prefix .. "_Death_" .. entIndex) then timer.Destroy(prefix .. "_Death_" .. entIndex) end
	end
    
    --Wintershowl
    ply:SetNW2Float("IceStaffSlow", 0)
    ply:SetMaterial("")
    ply:StopParticles()

    if ply.RestoreSpeed then
        ply:SetMaxSpeed(ply.RestoreSpeed)
        ply.RestoreSpeed = nil
    else
        ply:SetMaxSpeed(240) -- Fallback default run speed
    end

    ply:ConCommand("pp_mat_overlay \"\"")

    if tfaww_icestaffed then
        tfaww_icestaffed[ply:EntIndex()] = nil
    end
    
    --Player Magneto-Stick
    for _, wep in ipairs(ents.FindByClass("weapon_zm_carry")) do
        if IsValid(wep) and wep.Victim == ply and isfunction(wep.Reset) then
            wep:Reset()
        end
    end
    
	--Handcuffs
    ply:SetNWBool("IsCuffed", false)
	
	if timer.Exists("CantPickUp") and ply:GetNWBool( "FrozenYay", false ) then
		timer.Stop("CantPickUp")
		ply:SetNWBool( "FrozenYay", false )
		ply:SetNWBool( "GotCuffed", true )
	end
	
	--DanceDead (random music)
	local danceTimerName = "DanceDeadGunTimer" .. ply:EntIndex()
	if timer.Exists(danceTimerName) then
		timer.Destroy(danceTimerName)
	end

	ply.SkedaddledashDanceGrace = CurTime() + 22
	ply:SetNW2Bool("DanceGunThirdPerson", false)

	local danceSounds = {
		"badmusic", "ballball", "coffindance", "comeon", "disfigureblank",
		"doomfart", "epicsaxguy", "fortnitevictoryroyale", "hamsterdance",
		"memecompilation", "penismusic", "rickroll", "titanic", "onepiece", "yipeejazz"
	}

	for _, sndName in ipairs(danceSounds) do
		ply:StopSound("dancedead/shoot/" .. sndName .. ".mp3")
		ply:StopSound("dancedead/dance/" .. sndName .. ".mp3")
	end
	
	--Dislocator
	for _, disk in ipairs(ents.FindByClass("ttt_dislocator_disk")) do
		if IsValid(disk) and IsValid(disk.PunchEntity) and disk.PunchEntity == ply then
			disk:StopSound("dislocator_disk_active")
			disk:StopSound("dislocator_disk_inactive")
			disk:Remove()
		end
	end	
	
	--Science Show
	for _, piano in ipairs(ents.FindByClass("ent_ttt_asdf_sience_show")) do
		if IsValid(piano) and piano.Victim == ply then

			ply:StopSound("piano/idea.wav")
			ply:StopSound("piano/crash.wav")
			ply:StopSound("piano/piano.wav")


			piano:Remove()
		end
	end
	
	--Groovitron
	if ply:GetNWBool("TTTPAPGroovitronThirdPerson", false) then
		ply:SetNWBool("TTTPAPGroovitronThirdPerson", false)
	end

	--Cannibal
	if ply.TTTCannibalEaten then
		local sID64 = ply:SteamID64()

		-- 1. Stop the digestion timer
		timer.Remove("TTTCannibalDigestion_" .. sID64)

		-- 2. Clear state properties safely
		if ply.ClearProperty then
			ply:ClearProperty("TTTCannibalEaten")
		else
			ply.TTTCannibalEaten = nil
		end

		-- 3. Detach from the Cannibal and reset spectator state
		ply:SetParent(nil)
		ply:SpectateEntity(nil)
		ply:UnSpectate()

		-- 4. Restore player rendering and view models
		ply:SetNoDraw(false)
		ply:DrawViewModel(true)
		ply:DrawWorldModel(true)
		if IsValid(ply.hat) then
			ply.hat:SetNoDraw(false)
		end

		-- 5. Wipe stored weapon backup if present
		if CANNIBAL and CANNIBAL.playerWeapons then
			CANNIBAL.playerWeapons[sID64] = nil
		end

	end
	
	--eagle flight
	if istable(efrn) then
		for i, ragdoll in ipairs(efrn) do
			if (IsValid(ragdoll)) and (IsValid(ragdoll.Owner)) and ragdoll.Owner == ply then
				ragdoll.unragdoll()
			end
		end
	end
	
	--Spectator / Disguise Cleanse
	local specTarget = ply:GetObserverTarget()
	local specMode = ply:GetObserverMode()

	-- Prop Disguiser Active
	if ply:GetNWBool("PD_Disguised") then
		timer.Remove(ply:SteamID() .. "_DisguiseTime")
		ply:SetNWBool("PD_Disguised", false)
		ply:SetNWFloat("PD_TimeLeft", 0)

		if IsValid(ply.DisguisedProp) then
			ply.DisguisedProp.IsADisguise = false
			ply.DisguisedProp:Remove()
		end
		ply.DisguisedProp = nil

		local wep = ply:GetWeapon("weapon_ttt_propdisguiser") -- or active weapon
		if IsValid(wep) then
			wep:SetNWBool("PD_WepDisguised", false)
		end
	end

	-- Exit Spectate Mode
	if ply:GetObserverMode() ~= OBS_MODE_NONE and (not  ply.PAPPlayerTrapperTrapped) then
		if IsValid(specTarget) and specTarget:GetClass() == "prop_ragdoll" and specMode == OBS_MODE_CHASE then
			specTarget:Remove()
		end

		-- RE-ENTRY & REINSTATEMENT
		local savedEquipment = ply:GetEquipmentItems()
		
		ply.noClear = true
		ply:SetParent(nil)
		ply:UnSpectate()
		ply:Spawn()
		ply:SetNWBool("HasSkedaddledash", true)

		timer.Simple(0.1, function()
			if IsValid(ply) then
				ply.noClear = nil
				if ply:Alive() then
					-- Restore Equipment across TTT2 / CR-TTT / Vanilla
					if savedEquipment then
						if TTT2 then
							if istable(savedEquipment) then
								for item, state in pairs(savedEquipment) do
									if state == true then ply:GiveEquipmentItem(item) end
								end
							end
						elseif CR_VERSION and istable(savedEquipment) then
							for item, state in pairs(savedEquipment) do
								if state == true and isnumber(item) then
									ply:AddEquipmentItem(item)
								elseif isnumber(state) then
									ply:AddEquipmentItem(state)
								elseif isstring(state) or isstring(item) then
									local equipName = isstring(state) and state or item
									if ply.GiveEquipmentItem then
										ply:GiveEquipmentItem(equipName)
									end
								end
							end
						elseif isnumber(savedEquipment) and savedEquipment > 0 then
							ply:AddEquipmentItem(savedEquipment)
						end
					end
				end
			end
		end)
	end
	
	--Random Grav Nade
	if timer.Exists("TTTPAPRandomGravNade" .. ply:SteamID64()) then 
		timer.Destroy("TTTPAPRandomGravNade" .. ply:SteamID64())
		ply:SetGravity(1)
	end
    
    --Player Trapper (There's a lot I don't understand, since I got a lot of help from AI, especially on this next bit. I think it uses voodoo)
    if ply.PAPPlayerTrapperTrapped then
        ply.PAPCleansing = true

        for _, jetgun in ipairs(ents.FindByClass("tfa_jetgun")) do
            if IsValid(jetgun) then
                local owner = jetgun:GetOwner()
                local wasEquipped = IsValid(owner) and owner:IsPlayer()
                local gunPos = wasEquipped and owner:GetPos() or jetgun:GetPos()
                local gunAng = wasEquipped and owner:GetAngles() or jetgun:GetAngles()

                -- Resolve upgrade object
                local upgradeObj = jetgun.PAPUpgrade
                if not upgradeObj and TTTPAP then
                    if isfunction(TTTPAP.GetUpgrade) then
                        upgradeObj = TTTPAP:GetUpgrade("player_trapper")
                    elseif TTTPAP.upgrades and TTTPAP.upgrades["player_trapper"] then
                        upgradeObj = TTTPAP.upgrades["player_trapper"]
                    end
                end

                -- Gather other trapped victims (excluding the Skedaddledash user)
                local trappedVictims = {}
                if jetgun.PAPPlayerTrapperCapturedPlayers then
                    for _, victim in ipairs(jetgun.PAPPlayerTrapperCapturedPlayers) do
                        if IsValid(victim) and victim ~= ply and victim:Alive() then
                            victim.PAPCleansing = true
                            table.insert(trappedVictims, victim)
                        end
                    end
                end

                -- Strip/Remove the old Trapper entity
                if wasEquipped then
                    owner:StripWeapon("tfa_jetgun")
                else
                    jetgun:Remove()
                end

                -- Spawn fresh Jetgun
                local newGun = ents.Create("tfa_jetgun")
                if IsValid(newGun) then
                    newGun:SetPos(gunPos + Vector(0, 0, 10))
                    newGun:SetAngles(gunAng)
                    newGun:Spawn()

                    timer.Simple(0.05, function()
                        if IsValid(newGun) then
                            if TTTPAP and upgradeObj then
                                TTTPAP:ApplyUpgrade(newGun, upgradeObj)
                            end

                            -- Re-bind to native PAP table
                            newGun.PAPPlayerTrapperCapturedPlayers = newGun.PAPPlayerTrapperCapturedPlayers or {}
                            for _, victim in ipairs(trappedVictims) do
                                if IsValid(victim) and victim:Alive() then
                                    table.insert(newGun.PAPPlayerTrapperCapturedPlayers, victim)
                                end
                            end
                            
                            -- Attach custom Owner Tracking via Think hook
                            hook.Add("Think", "PAP_PlayerTrapper_OwnerCheck_" .. newGun:EntIndex(), function()
                                if not IsValid(newGun) then
                                    hook.Remove("Think", "PAP_PlayerTrapper_OwnerCheck_" .. newGun:EntIndex())
                                    return
                                end

                                local currentOwner = newGun:GetOwner()

                                -- Trigger camera updates whenever the owner changes (picked up or dropped)
                                if currentOwner ~= lastOwner then
                                    lastOwner = currentOwner

                                    for _, p in ipairs(player.GetAll()) do
                                        if IsValid(p) and p.PAPPlayerTrapperNewGun == newGun then
                                            if IsValid(currentOwner) then
                                                p:SpectateEntity(currentOwner)
                                            else
                                                p:SpectateEntity(newGun)
                                            end
                                        end
                                    end
                                end
                            end)

                            -- Attach weapon entity reference directly onto players
                            for _, victim in ipairs(trappedVictims) do
                                if IsValid(victim) then
                                    victim.PAPPlayerTrapperNewGun = newGun
                                end
                            end

                            -- Check ALL players on removal for matching newPlayerTrapper variable
                            newGun:CallOnRemove("PAP_PlayerTrapper_CleanupVictims", function(ent)
                                for _, p in ipairs(player.GetAll()) do
                                    if IsValid(p) and p.PAPPlayerTrapperNewGun == ent then
                                        p:UnSpectate()
                                        p:DrawViewModel(true)
                                        p:DrawWorldModel(true)
                                        p.PAPPlayerTrapperTrapped = false
                                        p.PAPPlayerTrapperStartTime = nil
                                        p.PAPPlayerTrapperNewGun = nil

                                        if p:Alive() then
                                            p:Spawn()
                                        end
                                    end
                                end
                            end)

                            -- Re-apply state & execution timers
                            for _, victim in ipairs(trappedVictims) do
                                if IsValid(victim) and victim:Alive() then
                                    victim.PAPPlayerTrapperTrapped = true
                                    
                                    if IsValid(owner) then
                                        victim:Spectate(OBS_MODE_IN_EYE)
                                        victim:SpectateEntity(owner)
                                    else
                                        victim:Spectate(OBS_MODE_IN_EYE)
                                        victim:SpectateEntity(newGun)
                                    end

                                    victim:DrawViewModel(false)
                                    victim:DrawWorldModel(false)

                                    local elapsedTime = victim.PAPPlayerTrapperStartTime and (CurTime() - victim.PAPPlayerTrapperStartTime) or 0
                                    local remainingTime = math.max(0.1, 30 - elapsedTime)

                                    victim.PAPCleansing = nil

                                    -- Execution Timer
                                    local timerID = "PAP_PlayerTrapper_" .. victim:SteamID64() .. "_" .. newGun:EntIndex()
                                    timer.Create(timerID, remainingTime, 1, function()
                                        if not IsValid(newGun) or not IsValid(victim) or not victim.PAPPlayerTrapperTrapped then return end

                                        victim:UnSpectate()
                                        victim:DrawViewModel(true)
                                        victim:DrawWorldModel(true)

                                        if victim:Alive() then
                                            victim:Kill()
                                        end

                                        if newGun.PAPPlayerTrapperCapturedPlayers then
                                            table.RemoveByValue(newGun.PAPPlayerTrapperCapturedPlayers, victim)
                                        end

                                        timer.Simple(1, function()
                                            if IsValid(victim) then
                                                victim.PAPPlayerTrapperTrapped = false
                                                victim.PAPPlayerTrapperStartTime = nil
                                                victim.PAPPlayerTrapperNewGun = nil
                                            end
                                        end)
                                    end)
                                end
                            end

                            -- Force owner pickup
                            if IsValid(owner) and owner:Alive() then
                                owner:PickupWeapon(newGun)
                                owner:SelectWeapon("tfa_jetgun")
                            end
                        end
                    end)
                end
            end
        end

        -- Fully release the Skedaddledash user/bot
        ply:UnSpectate()
        ply:DrawViewModel(true)
        ply:DrawWorldModel(true)
        ply.PAPPlayerTrapperTrapped = false
        ply.PAPPlayerTrapperStartTime = nil
        ply.PAPPlayerTrapperNewGun = nil
        ply.PAPCleansing = nil

        if ply:Alive() then
            ply:Spawn()
        end
    end
	
	--Common
	if ply:HasGodMode() then
		ply:GodDisable()
	end

    ply:Freeze(false)
    ply:UnLock()
    constraint.RemoveAll(ply)
	ply:DoAnimationEvent(ACT_RESET, 0)
	
	--Here's a custom hook for nerds
	hook.Run("SkedaddledashOnCleanse", ply, originalPos)
		
end

local function ApplyLandingPhase(ply, targetPos)
    -- Determine target orientation using cardinal line traces
    local traceStart = targetPos + Vector(0, 0, 32)
    local traceDist = 200

    local directions = {
        { dir = Vector(1, 0, 0),  yaw = 0 },    -- Forward / North
        { dir = Vector(-1, 0, 0), yaw = 180 },  -- Backward / South
        { dir = Vector(0, 1, 0),  yaw = 90 },   -- Right / East
        { dir = Vector(0, -1, 0), yaw = -90 }   -- Left / West
    }

    local validDirections = {}

    for _, d in ipairs(directions) do
        local tr = util.TraceLine({
            start = traceStart,
            endpos = traceStart + (d.dir * traceDist),
            filter = ply
        })

        -- If the ray made it all the way without hitting anything
        if not tr.Hit then
            table.insert(validDirections, d)
        end
    end

    -- If we found clear directions, pick one at random and point OPPOSITE to it
    if #validDirections > 0 then
        local chosen = validDirections[math.random(#validDirections)]
        local currentAng = ply:EyeAngles()
        
        -- Facing opposite to the open space direction: chosen.yaw + 180
        ply:SetEyeAngles(Angle(currentAng.p, math.NormalizeAngle(chosen.yaw + 180), currentAng.r))
    end

    -- Proceed with positioning and slide math
    local fwd = ply:GetAimVector()
    fwd.z = 0
    fwd:Normalize()

    local slideStartPos = targetPos - (fwd * 135)
    ply:SetPos(slideStartPos)

    ply:SetNWBool("SkedaddledashIsLanding", true)
    ply:SetNWFloat("SkedaddledashLandStart", CurTime())

    -- Send network message to play sound directly on nearby clients & caster
	local maxAudibleDistSqr = 800 * 800
	local recipients = {}

	for _, recipient in ipairs(player.GetAll()) do
		if recipient:GetPos():DistToSqr(slideStartPos) <= maxAudibleDistSqr then
			table.insert(recipients, recipient)
		end
	end

	-- Send only to players close enough to actually hear it
	if #recipients > 0 then
		net.Start("SkedaddledashPlaySkidSound")
			net.WriteEntity(ply)
			net.WriteEntity(ply.SkedaddledashSoundEnt)
		net.Send(recipients)
	end
	
	if IsValid(ply.SkedaddledashSoundEnt) then
		ply.SkedaddledashSoundEnt:Remove()
		ply.SkedaddledashSoundEnt = nil
	end

    local startTime = CurTime()
    local slideDuration = 0.75
    local totalDuration = 0.85
    local hookName = "SkedaddledashSlide_" .. ply:EntIndex()

    hook.Add("Think", hookName, function()
        if not IsValid(ply) or not ply:Alive() then
            hook.Remove("Think", hookName)
            return
        end

        local elapsed = CurTime() - startTime
        if elapsed <= slideDuration then
            local rawFraction = math.Clamp(elapsed / slideDuration, 0, 1)
            local deceleratedFraction = 1 - math.pow(1 - rawFraction, 2)
            ply:SetPos(LerpVector(deceleratedFraction, slideStartPos, targetPos))
        else
            ply:SetPos(targetPos)
        end

        if elapsed >= totalDuration then
            ply:SetPos(targetPos)
            ply:SetNWBool("SkedaddledashIsLanding", false)
            ply:SetNWFloat("SkedaddledashLandStart", 0)
            hook.Remove("Think", hookName)
        end
    end)
end

local function DropAndSpinItems(ply)
    -- Base position lifted up to chest/head height to prevent ground clipping
    local basePos = ply:GetPos() + Vector(0, 0, 50)
    local plyAngles = ply:GetAngles()
    
    -- X-axis relative to player's facing direction (Right vector)
    local spinAxis = ply:GetRight()

    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) and wep.AllowDrop ~= false then
            local class = wep:GetClass()
            
            ply:StripWeapon(class)

            local dropped = ents.Create(class)
            if IsValid(dropped) then
                -- Random direction in 3D, forcing Z to be slightly upward so items don't spawn into the floor
                local dir = Vector(math.Rand(-1, 1), math.Rand(-1, 1), math.Rand(0.2, 1)):GetNormalized()
                local randomOffset = dir * math.Rand(5, 30)
                local itemPos = basePos + randomOffset

                dropped:SetPos(itemPos)
                dropped:SetAngles(plyAngles)
                dropped:Spawn()

                -- Tag network state and parameters for client-side rendering
                dropped:SetNWBool("SkedaddledashSpinning", true)
                dropped:SetNWFloat("SkedaddledashSpinStart", CurTime())
                dropped:SetNWVector("SkedaddledashSpinAxis", spinAxis)

                -- Disable gravity & suspend physics during spin animation
                local phys = dropped:GetPhysicsObject()
                if IsValid(phys) then
                    phys:EnableGravity(false)
                    phys:SetVelocity(Vector(0, 0, 0))
                    phys:Sleep()
                end

                -- Restore physics and gravity after 1.5s
                timer.Simple(1.5, function()
                    if IsValid(dropped) then
                        dropped:SetNWBool("SkedaddledashSpinning", false)
                        
                        local pObj = dropped:GetPhysicsObject()
                        if IsValid(pObj) then
                            pObj:Wake()
                            pObj:EnableGravity(true)
                        end
                    end
                end)
            end
        end
    end
end

local function ExecuteSkedaddledash(ply)
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

    ply:SetNWBool("SkedaddledashIsCasting", false)
    ply:SetNWFloat("SkedaddledashCastStart", 0)

    local trueOriginPos = ply:GetPos()
    local targetPos = FindFurthestValidPos(ply)
    local currentHP = ply:Health()
    local maxHP = ply:GetMaxHealth()
    local currentCredits = ply:GetCredits() or 0
    
    -- Drop and trigger spin state on dropped items
    DropAndSpinItems(ply)
	
	CleansePlayer(ply, trueOriginPos)
	
	if TTT2 then
		for _, wep in ipairs(ply:GetWeapons()) do
			if IsValid(wep) then
				-- Optional: check if weapon should be stripped (e.g. keep holstered base hands)
				if wep:GetClass() ~= "weapon_ttt_unarmed" then
					ply:StripWeapon(wep:GetClass())
				end
			end
		end
	else
		ply:StripWeapons()
	end
    ply:StripAmmo()

    ply:Give("weapon_ttt_unarmed")
    ply:SetVelocity(-ply:GetVelocity())
    ply:SetMaxHealth(maxHP)
    ply:SetHealth(currentHP)
    ply:SetCredits(currentCredits)

    ApplyLandingPhase(ply, targetPos)

	net.Start("SkedaddledashSmokePuff")
		net.WriteVector(trueOriginPos + Vector(0, 0, 32))
	net.SendPVS(trueOriginPos)

    ply:ChatPrint("You escaped, but left all your items behind")
end

hook.Add("SetupMove", "SkedaddledashTreadmillLogic", function(ply, mv, cmd)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply:GetNWBool("SkedaddledashIsCasting", false) then
        if ply.SkedaddledashCastStartPos then
            mv:SetOrigin(ply.SkedaddledashCastStartPos)
            local startTime = ply:GetNWFloat("SkedaddledashCastStart", CurTime())
            local elapsed = math.Clamp(CurTime() - startTime, 0, 1)
            local speedMult = 1 + (4 * elapsed)
            local fwd = ply:GetAimVector()
            fwd.z = 0
            fwd:Normalize()
            mv:SetVelocity(fwd * (300 * speedMult))
        end
    elseif ply:GetNWBool("SkedaddledashIsLanding", false) then
        mv:SetVelocity(Vector(0, 0, 0))
    end
end)

hook.Add("UpdateAnimation", "SkedaddledashSpeedUpAnimSV", function(ply, velocity, maxseqgroundspeed)
    if ply:GetNWBool("SkedaddledashIsCasting", false) and IsValid(ply) and ply:Alive() then
        local startTime = ply:GetNWFloat("SkedaddledashCastStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 1)
        ply:SetPlaybackRate(1 + (5 * elapsed))
        return true
    end
end)

net.Receive("SkedaddledashStartCast", function(len, ply)
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

    local hasPassive = ply:GetNWBool("HasSkedaddledash", false)
    local nextUse = ply:GetNWFloat("SkedaddledashNextUse", 0)

    if not hasPassive or CurTime() < nextUse or ply:GetNWBool("SkedaddledashIsCasting", false) then
        net.Start("SkedaddledashRejectCast")
        net.Send(ply)
        return
    end

    local cooldown = cv_cooldown:GetFloat()
    ply:SetNWFloat("SkedaddledashNextUse", CurTime() + cooldown)

    local curPos = ply:GetPos()
    
	local soundEnt = ents.Create("info_target")
	if IsValid(soundEnt) then
		soundEnt:SetPos(curPos)
		soundEnt:Spawn()
		
		-- Emit the sound ON THE ENTITY so we can stop it on this specific entity later
		soundEnt:EmitSound("skedadledash.run", 80, 100, 1.0, CHAN_AUTO)
		
		-- Save reference on the player so the landing phase can reach it
		ply.SkedaddledashSoundEnt = soundEnt

		-- Fallback cleanup: remove the dummy entity after the audio finishes (3 seconds)
		timer.Simple(3, function()
			if IsValid(soundEnt) then soundEnt:Remove() end
		end)
	end

    ply.SkedaddledashCastStartPos = Vector(curPos.x, curPos.y, curPos.z)
    
    -- Enable fall & collision immunity for cast duration
    ply.SkedaddledashBarnacleGrace = true

    -- Freeze velocity and physical movement during cast
    ply:SetVelocity(-ply:GetVelocity())
    ply:SetNWBool("SkedaddledashIsCasting", true)
    ply:SetNWFloat("SkedaddledashCastStart", CurTime())

    local entIndex = ply:EntIndex()
    timer.Create("SkedaddledashCastTimer_" .. entIndex, 1.0, 1, function()
        if IsValid(ply) then
            ply.SkedaddledashCastStartPos = nil
            ply.SkedaddledashBarnacleGrace = false
            ExecuteSkedaddledash(ply)
        end
    end)
end)

-- Global function to trigger the full Skedaddledash sequence on players or bots
function TriggerSkedaddledash(ply)
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

    -- Ensure passive status is set on network table
    ply:SetNWBool("HasSkedaddledash", true)

    -- If currently trapped in Player Trapper, clear spectate instantly so SetPos/Spawn works
    if ply.PAPPlayerTrapperTrapped then
        ply:UnSpectate()
    end

    -- Run the actual teleport, cleanse, and landing sequence
    ExecuteSkedaddledash(ply)
end

-- function to override primary attack functions for predictable timers to dance weapons (I'm sure this is fine ...)
local function OverrideDanceGun(config)
    local swep = weapons.GetStored(config.classname)
    if not swep then return end

    swep.PrimaryAttack = function(self)
        if not self:CanPrimaryAttack() then return end

        local owner = self:GetOwner() or self.Owner
        if IsValid(owner) and config.shootSound then
            owner:EmitSound(config.shootSound)
        end

        local cone = self.Primary.Cone
        local bullet = {
            Num        = 1,
            Src        = owner:GetShootPos(),
            Dir        = owner:GetAimVector(),
            Spread     = Vector(cone, cone, 0),
            Tracer     = 1,
            Force      = 10,
            Damage     = 1,
            TracerName = "PhyscannonImpact",
            Callback   = function(att, tr)
                if SERVER or (CLIENT and IsFirstTimePredicted()) then
                    local ent = tr.Entity
                    if SERVER and IsValid(ent) and ent:IsPlayer() then
                        if config.hitSound then
                            ent:EmitSound(config.hitSound)
                        end

                        ent:GodEnable()

                        local entIndex = ent:EntIndex()
                        local danceTimer = config.prefix .. "_Loop_" .. entIndex
                        local deathTimer = config.prefix .. "_Death_" .. entIndex

                        -- Loop dance animation & freeze state
                        timer.Create(danceTimer, 1, config.duration or 14, function()
                            if not IsValid(ent) or not ent:Alive() then return end
                            local danceChange = math.random(1, 2)
                            if danceChange == 1 then
                                ent:DoAnimationEvent(ACT_GMOD_GESTURE_TAUNT_ZOMBIE, 1641)
                            else
                                ent:DoAnimationEvent(ACT_GMOD_TAUNT_DANCE, 1642)
                            end
                            if not ent:IsFrozen() then ent:Freeze(true) end
                        end)

                        ent:Freeze(true)

                        -- Delayed kill timer
                        timer.Create(deathTimer, config.duration or 14, 1, function()
                            if IsValid(ent) and ent:Alive() then
                                ent:GodDisable()
                                ent:Freeze(false)

                                local totalHealth = ent:Health()
                                local inflictWep = config.inflictorClass and ents.Create(config.inflictorClass) or nil

                                if IsValid(inflictWep) then
                                    ent:TakeDamage(totalHealth, att, inflictWep)
                                else
                                    ent:TakeDamage(totalHealth, att)
                                end

                                timer.Simple(2, function()
                                    if IsValid(ent) and ent:IsFrozen() then
                                        ent:Freeze(false)
                                    end
                                end)
                            end
                        end)
                    end
                end
            end
        }

        if IsValid(owner) then
            owner:FireBullets(bullet)
        end

        if SERVER then
            self:TakePrimaryAmmo(1)
        end
    end
end

hook.Add("InitPostEntity", "Skedaddledash_OverrideDanceGuns", function()
    -- Thriller Gun Configuration
    OverrideDanceGun({
        classname      = "weapon_ttt_thriller",
        prefix         = "reDance_Thriller",
        shootSound     = "mjow.wav",
        hitSound       = "thrilcut.wav",
        duration       = 14,
        inflictorClass = "weapon_ttt_thriller"
    })

    -- DanceDead Gun Configuration
    OverrideDanceGun({
        classname      = "dancedead",
        prefix         = "reDance_DanceDead",
        shootSound     = "mjow.wav",
        hitSound       = "thrilcut.wav",
        duration       = 14
    })
end)


-- Global function to trigger the full Skedadledash sequence on players or bots (for testing purposes only)
function TriggerSkedadledash(ply)
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

    -- Ensure passive status is set on network table
    ply:SetNWBool("HasSkedadledash", true)

    -- If currently trapped in Player Trapper, clear spectate instantly so SetPos/Spawn works
    if ply.PAPPlayerTrapperTrapped then
        ply:UnSpectate()
    end

    -- Run the actual teleport, cleanse, and landing sequence
    TriggerSkedaddledash(ply)
end