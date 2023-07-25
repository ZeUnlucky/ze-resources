local parts = {
    [0]     = 'UNKNOWN',
	[11816] = 'PELVIS',
    [31085] = 'HEAD',
    [31086] = 'HEAD',
    [39317] = 'NECK',
    [57597] = 'SPINE',
    [23553] = 'SPINE',
    [24816] = 'SPINE',
    [24817] = 'SPINE',
    [24818] = 'SPINE',
    [10706] = 'UPPER_BODY',
    [64729] = 'UPPER_BODY',
    [11816] = 'LOWER_BODY',
    [45509] = 'LARM',
    [61163] = 'LARM',
    [18905] = 'LHAND',
    [4089] = 'LFINGER',
    [4090] = 'LFINGER',
    [4137] = 'LFINGER',
    [4138] = 'LFINGER',
    [4153] = 'LFINGER',
    [4154] = 'LFINGER',
    [4169] = 'LFINGER',
    [4170] = 'LFINGER',
    [4185] = 'LFINGER',
    [4186] = 'LFINGER',
    [26610] = 'LFINGER',
    [26611] = 'LFINGER',
    [26612] = 'LFINGER',
    [26613] = 'LFINGER',
    [26614] = 'LFINGER',
    [58271] = 'LLEG',
    [63931] = 'LLEG',
    [2108] = 'LFOOT',
    [14201] = 'LFOOT',
    [40269] = 'RARM',
    [28252] = 'RARM',
    [57005] = 'RHAND',
    [58866] = 'RFINGER',
    [58867] = 'RFINGER',
    [58868] = 'RFINGER',
    [58869] = 'RFINGER',
    [58870] = 'RFINGER',
    [64016] = 'RFINGER',
    [64017] = 'RFINGER',
    [64064] = 'RFINGER',
    [64065] = 'RFINGER',
    [64080] = 'RFINGER',
    [64081] = 'RFINGER',
    [64096] = 'RFINGER',
    [64097] = 'RFINGER',
    [64112] = 'RFINGER',
    [64113] = 'RFINGER',
    [36864] = 'RLEG',
    [51826] = 'RLEG',
    [20781] = 'RFOOT',
    [52301] = 'RFOOT',
}

local HitCount = 0

local BodyParts = {
	['UNKNOWN'] = { label = 'Body', CauseLimp = 2 },
	['PELVIS'] = { label = 'Genitals', CauseLimp = 5},
    ['HEAD'] = { label = 'Head', CauseLimp = 0 },
    ['NECK'] = { label = 'Neck', CauseLimp = 1 },
    ['SPINE'] = { label = 'Spine', CauseLimp = 3 },
    ['UPPER_BODY'] = { label = 'Upper Body', CauseLimp = 2 },
    ['LOWER_BODY'] = { label = 'Lower Body', CauseLimp = 2 },
    ['LARM'] = { label = 'Left Arm', CauseLimp = 0 },
    ['LHAND'] = { label = 'Left Hand', CauseLimp = 0 },
    ['LFINGER'] = { label = 'Left Hand Fingers', CauseLimp = 0 },
    ['LLEG'] = { label = 'Left Leg', CauseLimp = 5 },
    ['LFOOT'] = { label = 'Left Foot', CauseLimp = 5 },
    ['RARM'] = { label = 'Right Arm', CauseLimp = 0 },
    ['RHAND'] = { label = 'Right Hand', CauseLimp = 0 },
    ['RFINGER'] = { label = 'Right Hand Fingers', CauseLimp = 0 },
    ['RLEG'] = { label = 'Right Leg', CauseLimp = 5 },
    ['RFOOT'] = { label = 'Right Foot', CauseLimp = 5 },
}



BONES = {
	--[[Pelvis]][11816] = true,
	--[[SKEL_L_Thigh]][58271] = true,
	--[[SKEL_L_Calf]][63931] = true,
	--[[SKEL_L_Foot]][14201] = true,
	--[[SKEL_L_Toe0]][2108] = true,
	--[[IK_L_Foot]][65245] = true,
	--[[PH_L_Foot]][57717] = true,
	--[[MH_L_Knee]][46078] = true,
	--[[SKEL_R_Thigh]][51826] = true,
	--[[SKEL_R_Calf]][36864] = true,
	--[[SKEL_R_Foot]][52301] = true,
	--[[SKEL_R_Toe0]][20781] = true,
	--[[IK_R_Foot]][35502] = true,
	--[[PH_R_Foot]][24806] = true,
	--[[MH_R_Knee]][16335] = true,
	--[[RB_L_ThighRoll]][23639] = true,
	--[[RB_R_ThighRoll]][6442] = true,
}

Citizen.CreateThread(function()	
	while true do		
		Citizen.Wait(0)		
		if HasEntityBeenDamagedByAnyPed(GetPlayerPed(-1)) and not IsEntityDead(GetPlayerPed(-1)) and not HasPedBeenDamagedByWeapon(GetPlayerPed(-1), 0, 1) then
			local hit, bone = GetPedLastDamageBone(GetPlayerPed(-1))
			HitCount = HitCount + BodyParts[parts[bone]].CauseLimp			
			if HitCount >= 5 and not IsEntityOnFire(GetPlayerPed(-1)) then
				exports['mythic_notify']:DoHudText('error',"You're unable to move!")
				Citizen.Wait(100)
				Tipol()		
				Citizen.Wait(5000)
				HitCount = 0
			end														
		end
		ClearEntityLastDamageEntity(GetPlayerPed(-1))
	end
end)

function Tipol()
	SetPedToRagdoll(GetPlayerPed(-1), 3500,3500,0,true,true,false)			
	return false
end


function alert(msg)
	SetNotificationTextEntry("STRING")
	AddTextComponentString(msg)
	DrawNotification(true,true)	
end
