-- Include the required lua files
include( "sh_init.lua" )
include( "cl_calcview.lua" )
include( "cl_playermodels.lua" )
include( "cl_scoreboard.lua" )
include( "cl_viewmodel.lua" )


-- Create data folders
if ( !file.IsDir( "half-life_2_campaign", "DATA" ) ) then

	file.CreateDir( "half-life_2_campaign" )

end

if ( !file.IsDir( "half-life_2_campaign/client", "DATA" ) ) then

	file.CreateDir( "half-life_2_campaign/client" )

end


-- Client only constants
DROWNING_SOUNDS = {
	"player/pl_drown1.wav",
	"player/pl_drown2.wav",
	"player/pl_drown3.wav"
}


-- Called by ShowScoreboard
function GM:CreateScoreboard()

	if ( scoreboard ) then
	
		scoreboard:Remove()
		scoreboard = nil
	
	end

	scoreboard = vgui.Create( "scoreboard" )

end


-- This creates the drowning effect
function DrowningEffect( len )

	surface.PlaySound( DROWNING_SOUNDS[ math.random( 1, #DROWNING_SOUNDS ) ] )
	deAlpha = 100
	deAlphaUpdate = 0

end
net.Receive( "DrowningEffect", DrowningEffect )


-- Do not want!
function GM:HUDDrawScoreBoard()
end


-- Called every frame to draw the hud
function GM:HUDPaint()

	if ( ( !GetConVar( "cl_drawhud" ):GetBool() ) || ( self.ShowScoreboard && IsValid( LocalPlayer() ) && ( LocalPlayer():Team() != TEAM_DEAD ) ) ) then
	
		return
	
	end

	if ( !showNav ) then hook.Run( "HUDDrawTargetID" ) end
	hook.Run( "HUDDrawPickupHistory" )
	surface.SetDrawColor( 0, 0, 0, 0 )

	w = ScrW()
	h = ScrH()
	centerX = w / 2
	centerY = h / 2

	-- Draw nav marker/point
	if ( showNav && checkpointPosition && ( LocalPlayer():Team() == TEAM_ALIVE ) ) then
	
		local checkpointDistance = math.Round( LocalPlayer():GetPos():Distance( checkpointPosition ) / 39 )
		local checkpointPositionScreen = checkpointPosition:ToScreen()
	
		surface.SetDrawColor( 255, 255, 255, 255 )
	
		if ( ( checkpointPositionScreen.x > 32 ) && ( checkpointPositionScreen.x < ( w - 43 ) ) && ( checkpointPositionScreen.y > 32 ) && ( checkpointPositionScreen.y < ( h - 38 ) ) ) then
		
			surface.SetTexture( surface.GetTextureID( "hl2c_nav_marker" ) )
			surface.DrawTexturedRect( checkpointPositionScreen.x - 14, checkpointPositionScreen.y - 14, 28, 28 )
			draw.DrawText( tostring( checkpointDistance ).." m", "roboto16", checkpointPositionScreen.x, checkpointPositionScreen.y + 15, Color( 255, 220, 0, 255 ), 1 )
		
		else
		
			local r = math.Round( centerX / 2 )
			local checkpointPositionRad = math.atan2( checkpointPositionScreen.y - centerY, checkpointPositionScreen.x - centerX )
			local checkpointPositionDeg = 0 - math.Round( math.deg( checkpointPositionRad ) )
			surface.SetTexture( surface.GetTextureID( "hl2c_nav_pointer" ) )
			surface.DrawTexturedRectRotated( math.cos( checkpointPositionRad ) * r + centerX, math.sin( checkpointPositionRad ) * r + centerY, 32, 32, checkpointPositionDeg + 90 )
		
		end
	
	end

	-- If dead, then draw spectator letterbox
	if ( LocalPlayer():Team() == TEAM_DEAD ) then
	
		surface.SetDrawColor( 0, 0, 0, 255 )
		surface.DrawRect( 0, 0, w, h * 0.10 )
		surface.DrawRect( 0, h - h * 0.10, w, h * 0.10 )
	
	else
	
		-- Drowning Effect
		if ( deAlpha && ( deAlpha > 0 ) ) then
		
			if ( CurTime() >= ( deAlphaUpdate + 0.01 ) ) then
			
				deAlpha = deAlpha - 1
				deAlphaUpdate = CurTime()
			
			end
		
			surface.SetDrawColor( 0, 0, 255, deAlpha )
			surface.DrawRect( 0, 0, w, h )
		
		end
	
		-- AUX bar
		lerpedEnergy = Lerp( RealFrameTime() * 10, lerpedEnergy, energy )
		if ( lerpedEnergy <= 99.9 ) then
		
			draw.RoundedBox( 4, ( ScrH() - h * 0.132 ) / 27.75, ScrH() - h * 0.132, h * 0.026 * 8.2, h * 0.026, Color( 0, 0, 0, 76 ) )
			surface.SetDrawColor( 255, 235, 20, 200 )
			surface.DrawRect( ( ScrH() - h * 0.126 ) / 22.3, ScrH() - h * 0.126, ( lerpedEnergy / 100 ) * ( h * 0.015 * 12.75 ), h * 0.015 )
		
		end
	
	end

	-- Are we going to the next map?
	if ( nextMapCountdownStart ) then
	
		local nextMapCountdownLeft = math.Round( nextMapCountdownStart + NEXT_MAP_TIME - CurTime() )
		if ( nextMapCountdownLeft > 0 ) then
		
			draw.SimpleTextOutlined( "Next Map in "..tostring( nextMapCountdownLeft ), "orbitron32Bold", centerX, h - h * 0.075, Color( 255, 255, 255, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color( 0, 0, 0, 255 ) )
		
		else
		
			draw.SimpleTextOutlined( "Switching Maps!", "orbitron32Bold", centerX, h - h * 0.075, Color( 255, 255, 255, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color( 0, 0, 0, 255 ) )
		
		end
	
	end

	-- Are we restarting the map?
	if ( restartMapCountdownStart ) then
	
		local restartMapCountdownLeft = math.Round( restartMapCountdownStart + RESTART_MAP_TIME - CurTime() )
		if ( restartMapCountdownLeft > 0 ) then
		
			draw.SimpleTextOutlined( "Restarting Map in "..tostring( restartMapCountdownLeft ), "orbitron32Bold", centerX, h - h * 0.075, Color( 255, 255, 255, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color( 0, 0, 0, 255 ) )
		
		else
		
			draw.SimpleTextOutlined( "Restarting Map!", "orbitron32Bold", centerX, h - h * 0.075, Color( 255, 255, 255, 200 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color( 0, 0, 0, 255 ) )
		
		end
	
	end

	-- On top of it all
	hook.Run( "DrawDeathNotice", 0.85, 0.04 )

end


-- Called every frame
function GM:HUDShouldDraw( name )

	if ( IsValid( LocalPlayer() ) ) then
	
		if ( self.ShowScoreboard && ( LocalPlayer():Team() != TEAM_DEAD ) ) then
		
			return false
		
		end
	
		local wep = LocalPlayer():GetActiveWeapon()
	
		if ( IsValid( wep ) && ( wep.HUDShouldDraw != nil ) ) then
		
			return wep.HUDShouldDraw( wep, name )
		
		end
	
	end

	return true

end


-- Called when we initialize
function GM:Initialize()

	-- Initial variables for client
	energy = 100
	lerpedEnergy = 0
	self.ShowScoreboard = false
	showNav = false
	scoreboard = nil

	-- Fonts we will need later
	surface.CreateFont( "roboto16", { size = 16, weight = 400, antialias = true, additive = false, font = "Roboto" } )
	surface.CreateFont( "roboto16Bold", { size = 16, weight = 700, antialias = true, additive = false, font = "Roboto Bold" } )
	surface.CreateFont( "orbitron32Bold", { size = 32, weight = 400, antialias = true, additive = false, font = "orbitronbold" } )

	-- Language
	language.Add( "worldspawn", "World" )
	language.Add( "func_door_rotating", "Door" )
	language.Add( "func_door", "Door" )
	language.Add( "phys_magnet", "Magnet" )
	language.Add( "trigger_hurt", "Trigger Hurt" )
	language.Add( "entityflame", "Fire" )
	language.Add( "env_explosion", "Explosion" )
	language.Add( "env_fire", "Fire" )
	language.Add( "func_tracktrain", "Train" )
	language.Add( "npc_launcher", "Headcrab Pod" )
	language.Add( "func_tank", "Mounted Turret" )
	language.Add( "npc_helicopter", "Helicopter" )
	language.Add( "npc_bullseye", "Turret" )
	language.Add( "prop_vehicle_apc", "APC" )
	language.Add( "item_healthkit", "Health Kit" )
	language.Add( "item_healthvial", "Health Vial" )
	language.Add( "combine_mine", "Mine" )
	language.Add( "npc_grenade_frag", "Grenade" )
	language.Add( "npc_metropolice", "Civil Protection" )
	language.Add( "npc_combine_s", "Combine Soldier" )
	language.Add( "npc_strider", "Strider" )

	-- Run this command for a more HL2 style gameplay
	RunConsoleCommand( "r_radiosity", "4" )

end


-- Called when a bind is pressed
function GM:PlayerBindPress( ply, bind, down )

	if ( ( bind == "+menu" ) && down ) then
	
		RunConsoleCommand( "lastinv" )
		return true
	
	end

	if ( ( bind == "+menu_context" ) && down ) then
	
		hook.Call( "OpenPlayerModelMenu", GAMEMODE )
		return true
	
	end

	return false

end


-- Called when a player sends a chat message
function GM:OnPlayerChat( ply, text, team, dead )

	local tab = {}

	if ( dead || ( IsValid( ply ) && ( ply:Team() == TEAM_DEAD ) ) ) then
	
		table.insert( tab, Color( 255, 30, 40 ) )
		table.insert( tab, "*DEAD* " )
	
	end

	if ( team ) then
	
		table.insert( tab, Color( 30, 160, 40 ) )
		table.insert( tab, "(TEAM) " )
	
	end

	if ( IsValid( ply ) ) then
	
		table.insert( tab, ply )
	
	else
	
		table.insert( tab, "Console" )
	
	end

	table.insert( tab, Color( 255, 255, 255 ) )
	table.insert( tab, ": "..text )

	chat.AddText( unpack( tab ) )
	chat.PlaySound()

	return true

end


-- Called when going to the next map
function NextMap( len )

	nextMapCountdownStart = net.ReadFloat()

end
net.Receive( "NextMap", NextMap )


-- Called when player spawns for the first time
function PlayerInitialSpawn( len )

	-- Shows the help menu
	if ( !file.Exists( "half-life_2_campaign/client/shown_help.txt", "DATA" ) ) then
	
		ShowHelp( 0 )
		file.Write( "half-life_2_campaign/client/shown_help.txt", "You've viewed the help menu in Half-Life 2 Campaign." )
	
	end

	-- Enable or disable the custom playermodel menu
	CUSTOM_PLAYERMODEL_MENU_ENABLED = net.ReadBool()

end
net.Receive( "PlayerInitialSpawn", PlayerInitialSpawn )


-- Called when restarting maps
function RestartMap( len )

	restartMapCountdownStart = net.ReadFloat()

	GAMEMODE:ScoreboardShow()

end
net.Receive( "RestartMap", RestartMap )


-- Called by show help
function ShowHelp( len )

	local helpText = "-= KEYBOARD SHORTCUTS =-\n[F1] (Show Help) - Opens this menu.\n[F2] (Show Team) - Toggles the navigation marker on your HUD.\n[F3] (Spare 1) - Spawns a vehicle if allowed.\n[F4] (Spare 2) - Removes a vehicle if you have one.\n\n-= OTHER NOTES =-\nOnce you're dead you cannot respawn until the next map."

	local helpMenu = vgui.Create( "DFrame" )
	local helpPanel = vgui.Create( "DPanel", helpMenu )
	local helpLabel = vgui.Create( "DLabel", helpPanel )

	helpLabel:SetText( helpText )
	helpLabel:SetTextColor( color_black )
	helpLabel:SizeToContents()
	helpLabel:SetPos( 5, 5 )

	local w, h = helpLabel:GetSize()
	helpMenu:SetSize( w + 20, h + 43 )

	helpPanel:StretchToParent( 5, 28, 5, 5 )

	helpMenu:SetTitle( "Help" )
	helpMenu:Center()
	helpMenu:MakePopup()

end
net.Receive( "ShowHelp", ShowHelp )


-- Called by client pressing -score
function GM:ScoreboardHide()

	self.ShowScoreboard = false

	if ( scoreboard ) then
	
		scoreboard:SetVisible( false )
	
	end

	gui.EnableScreenClicker( false )

end


-- Called by client pressing +score
function GM:ScoreboardShow()

	if ( game.SinglePlayer() ) then return end

	self.ShowScoreboard = true

	if ( !scoreboard ) then
	
		self:CreateScoreboard()
	
	end

	scoreboard:SetVisible( true )
	scoreboard:UpdateScoreboard( true )

	gui.EnableScreenClicker( true )

end


-- Called when the player is drawn
function GM:PostPlayerDraw( ply )

	if ( showNav && IsValid( ply ) && ply:Alive() && ( ply:Team() == TEAM_ALIVE ) && ( ply != LocalPlayer() ) ) then
	
		local bonePosition = ply:GetBonePosition( ply:LookupBone( "ValveBiped.Bip01_Head1" ) || 0 ) + Vector( 0, 0, 16 )
		cam.Start2D()
			draw.SimpleText( ply:Name().." ("..ply:Health().."%)", "TargetIDSmall", bonePosition:ToScreen().x, bonePosition:ToScreen().y, self:GetTeamColor( ply ), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
		cam.End2D()
	
	end

end


-- Called by ShowTeam
function ShowTeam( len )

	showNav = !showNav

end
net.Receive( "ShowTeam", ShowTeam )


-- Called by server
function SetCheckpointPosition( len )

	checkpointPosition = net.ReadVector()

end
net.Receive( "SetCheckpointPosition", SetCheckpointPosition )


-- Called by server Think()
function UpdateEnergy( len )

	energy = net.ReadFloat()

end
net.Receive( "UpdateEnergy", UpdateEnergy )
