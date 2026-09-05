local cv_key = CreateClientConVar("ttt_skedaddledash_key", "double_sprint", true, false, "Set custom key bind for Skedaddledash (e.g., 'f', 'g', 'mouse3', or 'double_sprint' to double-tap sprint).")

local doubleTapWindow = 0.3
local lastSprintTap = 0

local isCasting = false
local castEndTime = 0
local castCamPos = nil

local isLanding = false
local landCamAngles = nil
local landStartPos = nil

local ply

-- feel for to use this section for your own perk, but please credit Zaratusa (+ I added a cooldown timer)
-- your perk needs a "hud = true" in the table, to work properly
------------------------------------------------------------

surface.CreateFont("Trebuchet32", {
	font = "Trebuchet MS", 
	size = 32,             
	weight = 800,           
	antialias = true,
	shadow = false
})

local hudMaterial = Material("vgui/ttt/hud_skedaddledash.png")
local hudOverlayMaterial = Material("vgui/ttt/hud_skedaddledash_overlay.png", "smooth noclamp")
local hudBlinkMaterial = Material("vgui/ttt/hud_blink.png")

local cooldownTime = nil

local blinkTime = 3
local blinkNum = 7
local startPixel = 9
local endPixel = 56
local pixelW = (endPixel - startPixel)

local defaultY = ScrH() / 2 + 20
local yCoordinate = defaultY
local ply

local function getYCoordinate(currentPerkID)
	local amount, i, perk = 0, 1
	ply = ply or LocalPlayer()

	while i < currentPerkID do
		local role = ply:GetRole()
		perk = GetEquipmentItem(role, i)

		if not perk then
			perk = GetEquipmentItem(ROLE_TRAITOR, i)

			if not perk then
				perk = GetEquipmentItem(ROLE_DETECTIVE, i)
			end
		end

		if istable(perk) and perk.hud and ply:HasEquipmentItem(perk.id) then
			amount = amount + 1
		end

		if CRVersion and CRVersion("2.1.2") then
			i = i + 1
		else
			i = i * 2
		end
	end

	return defaultY - 80 * amount
end

local function triangleWave(x, cycle)

	local phase = (x * cycle) % 1  
	return 1 - (2 * math.abs(phase - 0.5))
end

hook.Add("TTTBoughtItem", "SkedaddledashHudYCoord", function()
	ply = ply or LocalPlayer()
	if ply:HasEquipmentItem(EQUIP_SKEDADDLEDASH) then
		yCoordinate = getYCoordinate(EQUIP_SKEDADDLEDASH)
	end
end)

hook.Add("HUDPaint", "SkedaddledashHud", function()
	ply = ply or LocalPlayer()
	if ply:GetNWBool("HasSkedaddledash", false) and ply:HasEquipmentItem(EQUIP_SKEDADDLEDASH) and (not TTT2) then
		surface.SetMaterial(hudMaterial)
		surface.SetDrawColor(255, 255, 255, 255)
		surface.DrawTexturedRect(20, yCoordinate, 64, 64)
		
		local nextUse = ply:GetNWFloat("SkedaddledashNextUse", 0)
		local remaining = math.max(0, nextUse + blinkTime - CurTime())
		
		surface.SetMaterial(hudOverlayMaterial)
		
		if remaining > blinkTime then
			
			cooldownTime = cooldownTime or GetConVar("ttt_skedaddledash_cooldown"):GetFloat()
			
			local cooldownLeftText = tostring(math.max(0, math.ceil(remaining - blinkTime)))
			local currentW = startPixel + math.floor((pixelW * (1 - ((remaining - blinkTime)/math.max(0.001,cooldownTime)))))
			local currentUVEnd = currentW/64

			surface.DrawTexturedRectUV(20, yCoordinate, currentW, 64, 0, 0, currentUVEnd, 1)
			draw.SimpleTextOutlined(cooldownLeftText, "Trebuchet32", 52, yCoordinate + 32, Color(255, 127, 127, 192), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 255))			
		else
		
			surface.DrawTexturedRect(20, yCoordinate, 64, 64)
			
			if (remaining > 0) and (remaining < blinkTime) then
				
				local blinkValue = triangleWave(remaining/blinkTime,blinkNum)
				local alfa = math.floor(255 * blinkValue)
				
				surface.SetMaterial(hudBlinkMaterial)
				surface.SetDrawColor(255, 255, 255, alfa)
				surface.DrawTexturedRect(20, yCoordinate, 64, 64)
			end
		end
		
		
	end
end)


net.Receive("SkedaddledashRejectCast", function()
    isCasting = false
    castCamPos = nil
end)

net.Receive("SkedaddledashPlaySkidSound", function()
	local dashingPlayer = net.ReadEntity()
	local soundEnt = net.ReadEntity()
	if IsValid(soundEnt) then
        soundEnt:StopSound("cartoon-sound-fx-funny-run.wav")
        soundEnt:StopSound("skedadledash.run")
		soundEnt:Remove()
	end
	
	if IsValid(dashingPlayer) then		
        dashingPlayer:EmitSound("cartoon-skid-stop-fx.wav", 75, 100, 0.35, CHAN_AUTO)
    end
end)

net.Receive("SkedaddledashSmokePuff", function()
    local origin = net.ReadVector()
    if not origin then return end

    local emitter = ParticleEmitter(origin)
    if not emitter then return end

    -- Spawn 25 small particles expanding outward in a sphere
    for i = 1, 25 do
        local particle = emitter:Add("particle/smokesprites_0001", origin + VectorRand() * 5)
        if particle then
            -- Expand in random 3D directions (outward poof)
            particle:SetVelocity(VectorRand():GetNormalized() * math.Rand(60, 120))
            
            -- Timing & fading
            particle:SetDieTime(math.Rand(0.4, 0.7)) -- Fades out quickly
            particle:SetStartAlpha(160)               -- Semi-translucent start
            particle:SetEndAlpha(0)                   -- Complete fade out
            
            -- Sizing
            particle:SetStartSize(math.Rand(12, 18))  -- Small initial puff size
            particle:SetEndSize(math.Rand(45, 65))    -- Dissipates outward as it grows
            
            -- Light grey coloration
            local grey = math.random(180, 210)
            particle:SetColor(grey, grey, grey)
            
            -- Slow rotation & physics
            particle:SetRoll(math.Rand(0, 360))
            particle:SetRollDelta(math.Rand(-2, 2))
            particle:SetAirResistance(100) -- Decelerates outward movement smoothly
        end
    end

    emitter:Finish()
end)

local function TriggerCastSequence(ply)
    local currentTime = CurTime()
    local nextUse = ply:GetNWFloat("SkedaddledashNextUse", 0)

    if currentTime >= nextUse then
        isCasting = true
        castEndTime = currentTime + 1.0
        castCamPos = ply:GetPos() + Vector(0, 0, 52)
        
        
        net.Start("SkedaddledashStartCast")
        net.SendToServer()
    else
        ply:ChatPrint("Skedaddledash is on cooldown")
    end 
end

hook.Add("CreateMove", "SkedaddledashKeyDetector", function(cmd)
    ply = ply or LocalPlayer()
    if not IsValid(ply) or not ply:Alive() or ply:IsSpec() then return end

    if ply:GetNWBool("SkedaddledashIsLanding", false) then
        if not isLanding then
            isLanding = true
            landCamAngles = cmd:GetViewAngles()
            landStartPos = ply:GetPos()
        end
    else
        isLanding = false
        landStartPos = nil
    end

    if isCasting then
        if CurTime() < castEndTime then
            cmd:ClearMovement()
            local ang = cmd:GetViewAngles()
            ang.p = math.Clamp(ang.p, -10, 10)
            cmd:SetViewAngles(ang)
            return
        else
            isCasting = false
            castCamPos = nil
        end
    end

    if isLanding then
        cmd:ClearMovement()
        cmd:ClearButtons()
        if landCamAngles then
            cmd:SetViewAngles(Angle(5, landCamAngles.y, landCamAngles.r))
        end
        return
    end

    local hasPassive = ply:GetNWBool("HasSkedaddledash", false)
    if not hasPassive then return end

    -- ConVar key resolution
    local boundKeyStr = string.Trim(string.lower(cv_key:GetString()))
    local targetKeyCode = (boundKeyStr ~= "" and boundKeyStr ~= "double_sprint") and input.GetKeyCode(boundKeyStr) or KEY_NONE

    -- Single-Key Activation (if a valid non-sprint key string was configured)
    if targetKeyCode ~= KEY_NONE then
        if input.IsKeyDown(targetKeyCode) or input.IsMouseDown(targetKeyCode) then
            if not ply.SkedaddledashWasCustomKeyDown then
                ply.SkedaddledashWasCustomKeyDown = true
                TriggerCastSequence(ply)
            end
        else
            ply.SkedaddledashWasCustomKeyDown = false
        end
    else
        
		local keyActivation = input.IsKeyDown(KEY_LSHIFT)
		if ConVarExists("ttt_sprint_activate_key") then
			local key =  GetConVar("ttt_sprint_activate_key")
			if key:GetInt() == 0 then
				keyActivation = input.IsKeyDown(KEY_E)
			elseif key:GetInt() == 2 then
				keyActivation = input.IsKeyDown(KEY_LCONTROL)
			elseif key:GetInt() == 3 then
				keyActivation = input.IsKeyDown(CustomActivateKey:GetFloat())
			end
		end
		if CR_VERSION or TTT2 then
			keyActivation = cmd:KeyDown(IN_SPEED)
		end
		
        if keyActivation then
            if not ply.SkedaddledashWasKeyDown then
                ply.SkedaddledashWasKeyDown = true
                local currentTime = CurTime()

                if (currentTime - lastSprintTap) <= doubleTapWindow then
                    TriggerCastSequence(ply)
                end

                lastSprintTap = currentTime
            end
        else
            ply.SkedaddledashWasKeyDown = false
        end
    end
end)

local function GetSafeLandingSequence(ply)
    local candidates = { "swimming_all", "jump_holding", "jump_loop", "cid_flail", "swimming_idle" }
    for _, name in ipairs(candidates) do
        local seq = ply:LookupSequence(name)
        if seq and seq ~= -1 then return seq end
    end
    return nil
end

hook.Add("CalcMainActivity", "SkedaddledashForceAnimations", function(ply, velocity)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply:GetNWBool("SkedaddledashIsCasting", false) then
        local seq = ply:LookupSequence("run_all_01")
        if seq and seq ~= -1 then return ACT_MP_RUN, seq end
        return ACT_MP_RUN, -1
    elseif ply:GetNWBool("SkedaddledashIsLanding", false) then
        local startTime = ply:GetNWFloat("SkedaddledashLandStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 0.85)

        if elapsed >= 0.75 then
            local seq = ply:LookupSequence("idle_all_01") or ply:LookupSequence("idle_all_02")
            if seq and seq ~= -1 then return ACT_MP_STAND_IDLE, seq end
            return ACT_MP_STAND_IDLE, -1
        else
            local seq = GetSafeLandingSequence(ply)
            if seq then return ACT_MP_SWIM, seq end
            return ACT_MP_SWIM, -1
        end
    end
end)

hook.Add("CalcView", "SkedaddledashCastCamera", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end

    if isCasting then
        local view = {}
        local anchorPos = castCamPos or (pos + Vector(0, 0, 52))
        local viewAngles = Angle(5, angles.y, angles.r)
        local trace = util.TraceLine({
            start = anchorPos,
            endpos = anchorPos - (viewAngles:Forward() * 90) + Vector(0, 0, 10),
            filter = ply
        })

        local startTime = ply:GetNWFloat("SkedaddledashCastStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 1)

        view.origin = trace.HitPos + trace.HitNormal * 4
        view.angles = viewAngles
        --view.fov = fov + (18 * elapsed)
        view.drawviewer = true
        return view
    elseif ply:GetNWBool("SkedaddledashIsLanding", false) then
        local view = {}
        local camAngles = landCamAngles or angles
        local fixedLandingAngles = Angle(5, camAngles.y, camAngles.r)
        local basePos = (landStartPos or pos) + Vector(0, 0, 52)
        local anchorPos = basePos - (fixedLandingAngles:Forward() * 60)

        local trace = util.TraceLine({ start = basePos, endpos = anchorPos, filter = ply })
        local startTime = ply:GetNWFloat("SkedaddledashLandStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 0.85)

        local fovProgress = math.Clamp(elapsed / 0.75, 0, 1)
        view.origin = trace.HitPos + trace.HitNormal * 4
        view.angles = fixedLandingAngles
        --view.fov = fov + (18 * (1 - fovProgress))
        view.drawviewer = true
        return view
    end
end)

hook.Add("UpdateAnimation", "SkedaddledashSpeedUpAnimCL", function(ply, velocity, maxseqgroundspeed)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply:GetNWBool("SkedaddledashIsCasting", false) then
        local startTime = ply:GetNWFloat("SkedaddledashCastStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 1)
        ply:SetPoseParameter("move_x", 1.0)
        ply:SetPoseParameter("move_y", 0.0)
        ply:SetPlaybackRate(1 + (5 * elapsed))
        return true
    elseif ply:GetNWBool("SkedaddledashIsLanding", false) then
        local startTime = ply:GetNWFloat("SkedaddledashLandStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 0.85)

        ply:SetPoseParameter("move_x", 0.0)
        ply:SetPoseParameter("move_y", 0.0)

        if elapsed >= 0.75 then
            ply:SetPlaybackRate(Lerp((elapsed - 0.75) / 0.10, 0.5, 0.0))
        else
            local seq = GetSafeLandingSequence(ply)
            if seq then ply:SetSequence(seq) end
            ply:SetPlaybackRate(Lerp(elapsed / 0.75, 5.0, 1.5))
        end
        return true
    end
end)

hook.Add("PrePlayerDraw", "SkedaddledashSquishPreDraw", function(ply)
    if not IsValid(ply) or not ply:Alive() then return end

    if ply:GetNWBool("SkedaddledashIsCasting", false) then
        local startTime = ply:GetNWFloat("SkedaddledashCastStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 1)
        local squishProgress = math.Clamp(elapsed / 0.5, 0, 1)

        local mat = Matrix()
        mat:Scale(Vector(1.0 - (0.10 * squishProgress), 1.0 - (0.10 * squishProgress), 1.0 + (0.15 * squishProgress)))
        mat:Rotate(Angle(-10 - (20 * squishProgress), 0, 0))
        ply:EnableMatrix("RenderMultiply", mat)

        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then ply:ManipulateBoneAngles(headBone, Angle(0, -15 * squishProgress, 0)) end

    elseif ply:GetNWBool("SkedaddledashIsLanding", false) then
        -- Force the render mesh orientation to match camera view angles exactly
        local targetAng = landCamAngles or ply:EyeAngles()
        ply:SetRenderAngles(Angle(0, targetAng.y, 0))

        local startTime = ply:GetNWFloat("SkedaddledashLandStart", CurTime())
        local elapsed = math.Clamp(CurTime() - startTime, 0, 0.85)

        local leanAngle = -45
        local headYaw = -20

        if elapsed > 0.75 then
            local uprightProgress = (elapsed - 0.75) / 0.10
            leanAngle = Lerp(uprightProgress, -45, 0)
            headYaw = Lerp(uprightProgress, -20, 0)
        end

        local mat = Matrix()
        mat:Rotate(Angle(leanAngle, 0, 0))
        ply:EnableMatrix("RenderMultiply", mat)

        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then ply:ManipulateBoneAngles(headBone, Angle(0, headYaw, 0)) end
    end
end)

hook.Add("PostPlayerDraw", "SkedaddledashSquishPostDraw", function(ply)
    if IsValid(ply) then
        ply:DisableMatrix("RenderMultiply")
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then ply:ManipulateBoneAngles(headBone, Angle(0, 0, 0)) end
    end
end)

hook.Add("DoPlayerDeath", "SkedaddledashClientDeathCleanup", function(ply)
    if IsValid(ply) then
        ply:DisableMatrix("RenderMultiply")
        local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
        if headBone then ply:ManipulateBoneAngles(headBone, Angle(0, 0, 0)) end
    end
end)

hook.Add("PostDrawOpaqueRenderables", "SkedaddledashSpinItemsCL", function()
    local curTime = CurTime()

    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and ent:GetNWBool("SkedaddledashSpinning", false) then
            local startTime = ent:GetNWFloat("SkedaddledashSpinStart", curTime)
            local elapsed = math.Clamp(curTime - startTime, 0, 1.5)

            if elapsed < 1.5 then
                -- Linear deceleration: 1.0x initial speed down to 0.5x speed at 1.5s
                local speedFactor = 1 - (0.5 * (elapsed / 1.5))
                local degreesPerSecond = -1080 -- Base spin speed (~3 rotations/sec)
                
                local deltaDegrees = degreesPerSecond * speedFactor * FrameTime()
                local axis = ent:GetNWVector("SkedaddledashSpinAxis", ent:GetRight())

                -- Reverted back to positive deltaDegrees to flip direction
                local currentAng = ent:GetAngles()
                currentAng:RotateAroundAxis(axis, deltaDegrees)
                
                ent:SetAngles(currentAng)
            end
        end
    end
end)