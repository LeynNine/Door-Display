local TitleColor = Color( 0, 200, 0, 255 )
local TitleOutlineColor = Color( 0, 0, 0, 255 )

local OwnerColor = Color( 255, 215, 0, 255 )
local OwnerOutlineColor = Color( 0, 0, 0, 200 )

local CoownerColor = Color( 255, 215, 0, 255 )
local CoownerOutlineColor = Color( 0, 0, 0, 200 )

local AllowedGroupsColor = Color( 0, 0, 255, 255 )
local AllowedGroupsOutlineColor = Color( 0, 0, 0, 200 )

local PurchaseColor = Color( 0, 200, 0, 255 )
local PurchaseOutlineColor = Color( 0, 0, 0, 255 )

local DrawDistance = 250



if SERVER then return end


surface.CreateFont( "DoorDisplayTitleFont", {
	font = "CloseCaption_Bold",
	size = 40,
	weight = 1500, 
	blursize = 0, 
	scanlines = 0, 
	antialias = true, 
	underline = false, 
	italic = false, 
	strikeout = false, 
	symbol = false, 
	rotary = false, 
	shadow = false, 
	additive = false, 
	outline = false,
} )

surface.CreateFont( "DoorDisplayTrebuchetSmall", {
	font = "CloseCaption_Bold",
	size = 22,
	blursize = 0, 
	scanlines = 0, 
	antialias = true, 
	underline = false, 
	italic = false, 
	strikeout = false, 
	symbol = false, 
	rotary = false, 
	shadow = false, 
	additive = false, 
	outline = false,
} )

surface.CreateFont("LawsFont", {
	font = "CloseCaption_Bold",
	size = 55,
	weight = 2000,
	blursize = 0,
	scanlines = 0,
	antialias = true,
	underline = false,
	italic = false,
	strikeout = false,
	symbol = false,
	rotary = false,
	shadow = false,
	additive = false,
	outline = false,
} )


local doorInfo = {}

local function computeFadeAlpha( time, dur, sa, ea, start )
	time = time - (start or 0)

	if time < 0 then return sa end	
	if time > dur then return ea end

	return sa + ((math.sin( (time / dur) * (math.pi / 2) )^2) * (ea - sa))
end

local function colorMulAlpha( col, mul )
	return Color( col.r, col.g, col.b, col.a * mul )
end

local function isDoor( door )
	if door.isDoor and door.isKeysOwnable then
		return door:isDoor() and door:isKeysOwnable()
	end
end

local function isOwnable( door )
	if door.getKeysNonOwnable then
		return door:getKeysNonOwnable() != true
	end
end

local function getTitle( door )
	if door.getKeysTitle then
		return door:getKeysTitle()
	end
end

local function getOwner( door )
	if door.getDoorOwner then
		local owner = door:getDoorOwner()

		if IsValid( owner ) then
			return owner
		end
	end
end

local function getCoowners( door )
	local owner = getOwner( door )
	local coents = {}

	if door.isKeysOwnedBy then
		for _, ply in pairs( player.GetAll() ) do
			if door:isKeysOwnedBy( ply ) and ply != owner then
				table.insert( coents, ply )
			end
		end
	end

	return coents
end

local function isAllowedToCoown( door, ply )
	if door.isKeysAllowedToOwn and door.isKeysOwnedBy then
		return door:isKeysAllowedToOwn( ply ) and !door:isKeysOwnedBy( ply )
	end
end

local function getAllowedGroupNames( door )
	local ret = {}

	if door.getKeysDoorGroup and door:getKeysDoorGroup() then
		table.insert( ret, door:getKeysDoorGroup() )
	elseif door.getKeysDoorTeams then
		for tid in pairs( door:getKeysDoorTeams() or {} ) do
			local tname = team.GetName( tid )

			if tname then
				table.insert( ret, tname )
			end
		end
	end

	return ret
end


hook.Add( "HUDDrawDoorData", "sh_doordisplay_hudoverride", function( door )
	if isDoor( door ) and isOwnable( door ) then
		if #getAllowedGroupNames( door ) < 1 then
			local dist = door:GetPos():Distance( LocalPlayer():GetShootPos() )
			local admul = math.cos( (dist / DrawDistance) * (math.pi / 2) )^2

			if !getOwner( door ) then
				draw.SimpleTextOutlined(
					"F2 чтобы купить!",
					"DoorDisplayTitleFont",
					ScrW() / 2, ScrH() / 2,
					colorMulAlpha( PurchaseColor, admul ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
					1, colorMulAlpha( PurchaseOutlineColor, admul )
				)
			elseif isAllowedToCoown( door, LocalPlayer() ) then
				draw.SimpleTextOutlined(
					"F2 чтобы добавить владельца",
					"DoorDisplayTitleFont",
					ScrW() / 2, ScrH() / 2,
					colorMulAlpha( PurchaseColor, admul ),
					TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
					1, colorMulAlpha( PurchaseOutlineColor, admul )
				)
			end
		end

		return true
	end
end )

hook.Add( "PostDrawTranslucentRenderables", "sh_doordisplay_drawdisplay", function()
	for _, door in pairs( ents.GetAll() ) do
		if !isDoor( door ) or !isOwnable( door ) then continue end

		local dinfo = doorInfo[door]

		if !dinfo then
			dinfo = {
				coownCollapsed = true
			}

			local dimens = door:OBBMaxs() - door:OBBMins()
			local center = door:OBBCenter()
			local min, j 

			for i=1, 3 do
				if !min or dimens[i] <= min then
					j = i
					min = dimens[i]
				end
			end

			local norm = Vector()
			norm[j] = 1

			local lang = Angle( 0, norm:Angle().y + 90, 90 )

			if door:GetClass() == "prop_door_rotating" then
				dinfo.lpos = Vector( center.x, center.y, 30 ) + lang:Up() * (min / 6)
			else
				dinfo.lpos = center + Vector( 0, 0, 20 ) + lang:Up() * ((min / 2) - 0.1)
			end
			
			dinfo.lang = lang

			doorInfo[door] = dinfo
		end

		local dist = door:GetPos():Distance( LocalPlayer():GetShootPos() )

		if dist <= DrawDistance then
			dinfo.viewStart = dinfo.viewStart or CurTime()

			local title = getTitle( door )
			local owner = getOwner( door )
			local coowners = getCoowners( door ) or {}
			local allowedgroups = getAllowedGroupNames( door )

			local lpos, lang = Vector(), Angle()
			lpos:Set( dinfo.lpos )
			lang:Set( dinfo.lang )

			local ang = door:LocalToWorldAngles( lang )
			local dot = ang:Up():Dot( 
				LocalPlayer():GetShootPos() - door:WorldSpaceCenter()
			)

			if dot < 0 then
				lang:RotateAroundAxis( lang:Right(), 180 )

				lpos = lpos - (2 * lpos * -lang:Up())
				ang = door:LocalToWorldAngles( lang )
			end

			local pos = door:LocalToWorld( lpos )
			local scale = 0.14

			local vst = dinfo.viewStart
			local ct = CurTime()

			cam.Start3D2D( pos, ang, scale )
				local admul = math.cos( (dist / DrawDistance) * (math.pi / 2) )^2
				local amul = computeFadeAlpha( ct, 0.75, 0, 1, vst ) * admul

				if #allowedgroups < 1 then
					if title and #title > 16 then
						title = title:Left( 16 ) .. "..."
					end

					draw.SimpleTextOutlined(
						owner and (title or "Занято") or "Свободно",
						"DoorDisplayTitleFont",
						0, 10,
						colorMulAlpha( TitleColor, amul ),
						TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
						1, colorMulAlpha( TitleOutlineColor, amul )
					)

					if owner then
						amul = computeFadeAlpha( ct, 0.75, 0, 1, vst + 0.35 ) * admul

						draw.SimpleTextOutlined(
							owner:Nick(),
							"CloseCaption_Bold",
							0, 50,
							colorMulAlpha( OwnerColor, amul ),
							TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
							1, colorMulAlpha( OwnerOutlineColor, amul )
						)

						if #coowners > 0 then
							if !dinfo.coownCollapsed then
								local conames = {}

								for i=1, #coowners do
									table.insert( conames, coowners[i]:Nick() )
								end

								table.sort( conames )

								for i=1, #conames do
									amul = computeFadeAlpha( ct, 0.75, 0, 1, dinfo.coownExpandStart + 0.2*i ) * admul

									draw.SimpleTextOutlined(
										conames[i],
										"DoorDisplayTitleFont",
										0, 60 + 25*i,
										colorMulAlpha( CoownerColor, amul ),
										TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
										1, colorMulAlpha( CoownerOutlineColor, amul )
									)
								end
							else
								amul = computeFadeAlpha( ct, 1, 0, 1, vst + 1.0 ) * admul

								local whitpos = util.IntersectRayWithPlane( 
									LocalPlayer():GetShootPos(), LocalPlayer():GetAimVector(),
									pos, ang:Up()
								)
								local cy = 0
								local cactive = false

								if whitpos and LocalPlayer():GetEyeTrace().Entity == door then
									local hitpos = door:WorldToLocal( whitpos ) - lpos

									cy = -hitpos.z / scale
									cactive = true
								end

								if (ct - vst) >= 2 and cactive and cy >= 80 and cy <= 80 + 25 then
									dinfo.coownExpandRequestStart = dinfo.coownExpandRequestStart or CurTime()

									if CurTime() - dinfo.coownExpandRequestStart >= 0.75 then
										dinfo.coownCollapsed = false
										dinfo.coownExpandStart = CurTime()
										dinfo.coownExpandRequestStart = nil
									end

									amul = computeFadeAlpha( ct, 0.75, 1, 0, dinfo.coownExpandRequestStart ) * admul --fade out
								else
									dinfo.coownExpandRequestStart = nil
								end

								draw.SimpleTextOutlined(
									"And " .. #coowners .. " other(s)",
									"DoorDisplayTitleFont",
									0, 80,
									colorMulAlpha( CoownerColor, amul ),
									TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
									1, colorMulAlpha( CoownerOutlineColor, amul )
								)
							end
						end
					end
				else
					for i=1, #allowedgroups do
						amul = computeFadeAlpha( ct, 0.75, 0, 1, vst + 0.2*i ) * admul

						draw.SimpleTextOutlined(
							allowedgroups[i],
							"LawsFont",
							0, 50 + 30*(i-1),
							colorMulAlpha( AllowedGroupsColor, amul ),
							TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM,
							1, colorMulAlpha( AllowedGroupsOutlineColor, amul )
						)
					end
				end
			cam.End3D2D()
		else
			dinfo.viewStart = nil
			dinfo.coownCollapsed = true
		end
	end
end )