-- Send the required lua files to the client
AddCSLuaFile( "cl_calcview.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_playermodels.lua" )
AddCSLuaFile( "cl_scoreboard.lua" )
AddCSLuaFile( "cl_scoreboard_playerlist.lua" )
AddCSLuaFile( "cl_scoreboard_playerrow.lua" )
AddCSLuaFile( "cl_viewmodel.lua" )
AddCSLuaFile( "sh_config.lua" )
AddCSLuaFile( "sh_init.lua" )
AddCSLuaFile( "sh_player.lua" )

-- Include the required lua files
include( "sv_globalstates.lua" )
include( "sh_init.lua" )

-- Include the configuration for this map
if ( file.Exists( "half-life_2_campaign/gamemode/maps/"..game.GetMap()..".lua", "LUA" ) ) then

	include( "maps/"..game.GetMap()..".lua" )

end

-- Create data folders
if ( !file.IsDir( "half-life_2_campaign", "DATA" ) ) then

	file.CreateDir( "half-life_2_campaign" )

end

if ( !file.IsDir( "half-life_2_campaign/players", "DATA" ) ) then

	file.CreateDir( "half-life_2_campaign/players" )

end


-- Create console variables to make these config vars easier to access
local hl2c_admin_physgun = CreateConVar( "hl2c_admin_physgun", ADMIN_NOCLIP, FCVAR_NOTIFY )
local hl2c_admin_noclip = CreateConVar( "hl2c_admin_noclip", ADMIN_PHYSGUN, FCVAR_NOTIFY )
local hl2c_server_ammo_limit = CreateConVar( "hl2c_server_ammo_limit", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_custom_playermodels = CreateConVar( "hl2c_server_custom_playermodels", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_checkpoint_respawn = CreateConVar( "hl2c_server_checkpoint_respawn", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_dynamic_skill_level = CreateConVar( "hl2c_server_dynamic_skill_level", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_lag_compensation = CreateConVar( "hl2c_server_lag_compensation", 1, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_player_respawning = CreateConVar( "hl2c_server_player_respawning", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )
local hl2c_server_jeep_passenger_seat = CreateConVar( "hl2c_server_jeep_passenger_seat", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE } )


-- Precache all the player models ahead of time
for _, playerModel in pairs( PLAYER_MODELS ) do

	util.PrecacheModel( playerModel )

end


-- Called when the player attempts to suicide
function GM:CanPlayerSuicide( ply )

	if ( ply:Team() == TEAM_COMPLETED_MAP ) then
	
		ply:ChatPrint( "You cannot suicide once you've completed the map." )
		return false
	
	elseif ( ply:Team() == TEAM_DEAD ) then
	
		ply:ChatPrint( "This may come as a surprise, but you are already dead." )
		return false
	
	end

	if ( !ply.vulnerable ) then
	
		ply:ChatPrint( "You're currently invulnerable. Suicide attempt blocked!" )
		return false
	
	end

	return true

end 


-- Creates a spawn point
function GM:CreateSpawnPoint( pos, yaw )

	local ips = ents.Create( "info_player_start" )
	ips:SetPos( pos )
	ips:SetAngles( Angle( 0, yaw, 0 ) )
	ips:SetKeyValue( "spawnflags", "1" )
	ips:Spawn()

end


-- Creates a trigger delaymapload
function GM:CreateTDML( min, max )

	tdmlPos = max - ( ( max - min ) / 2 )
	
	local tdml = ents.Create( "trigger_delaymapload" )
	tdml:SetPos( tdmlPos )
	tdml.min = min
	tdml.max = max
	tdml:Spawn()

end


-- Called when the player dies
function GM:DoPlayerDeath( ply, attacker, dmgInfo )

	ply.deathPos = ply:EyePos()

	-- Add to deadPlayers table to prevent respawning on re-connect
	if ( ( ( !hl2c_server_player_respawning:GetBool() && !FORCE_PLAYER_RESPAWNING ) || OVERRIDE_PLAYER_RESPAWNING ) && !table.HasValue( deadPlayers, ply:SteamID() ) ) then
	
		table.insert( deadPlayers, ply:SteamID() )
	
	end
	
	ply:RemoveVehicle()
	if ( ply:FlashlightIsOn() ) then ply:Flashlight( false ); end
	ply:CreateRagdoll()
	ply:SetTeam( TEAM_DEAD )
	ply:AddDeaths( 1 )

	-- Clear player info
	ply.info = nil

end


-- Called when the player is waiting to spawn
function GM:PlayerDeathThink( ply )

	if ( ply.NextSpawnTime && ( ply.NextSpawnTime > CurTime() ) ) then return; end

	if ( ( ply:GetObserverMode() != OBS_MODE_ROAMING ) && ( ply:IsBot() || ply:KeyPressed( IN_ATTACK ) || ply:KeyPressed( IN_ATTACK2 ) || ply:KeyPressed( IN_JUMP ) ) ) then
	
		if ( ( !hl2c_server_player_respawning:GetBool() && !FORCE_PLAYER_RESPAWNING ) || OVERRIDE_PLAYER_RESPAWNING ) then
		
			ply:Spectate( OBS_MODE_ROAMING )
			ply:SetPos( ply.deathPos )
			ply:SetNoTarget( true )
		
		else
		
			ply:SetTeam( TEAM_ALIVE )
			ply:Spawn()
		
		end
	
	end

end


-- Called when entities are created
function GM:OnEntityCreated( ent )

	-- NPC Lag Compensation
	if ( hl2c_server_lag_compensation:GetBool() && ent:IsNPC() && !table.HasValue( NPC_EXCLUDE_LAG_COMPENSATION, ent:GetClass() ) ) then
	
		ent:SetLagCompensated( true )
	
	end

	-- Vehicle Passenger Seating
	if ( hl2c_server_jeep_passenger_seat:GetBool() && !GetConVar( "hl2_episodic" ):GetBool() && ent:IsVehicle() && string.find( ent:GetClass(), "prop_vehicle_jeep" ) ) then
	
		ent.passengerSeat = ents.Create( "prop_vehicle_prisoner_pod" )
		ent.passengerSeat:SetPos( ent:LocalToWorld( Vector( 21, -32, 18 ) ) )
		ent.passengerSeat:SetAngles( ent:LocalToWorldAngles( Angle( 0, -3.5, 0 ) ) )
		ent.passengerSeat:SetModel( "models/nova/jeep_seat.mdl" )
		ent.passengerSeat:SetMoveType( MOVETYPE_NONE )
		ent.passengerSeat:SetParent( ent )
		ent.passengerSeat:Spawn()
		ent.passengerSeat:Activate()
		ent.passengerSeat.allowWeapons = true
	
	end

end


-- Called when map entities spawn
function GM:EntityKeyValue( ent, key, value )

	if ( ( ent:GetClass() == "trigger_changelevel" ) && ( key == "map" ) ) then
	
		ent.map = value
	
	end

	if ( ( ent:GetClass() == "npc_combine_s" ) && ( key == "additionalequipment" ) && ( value == "weapon_shotgun" ) ) then
	
		ent:SetSkin( 1 )
	
	end

end


-- Called when an entity has received damage	  
function GM:EntityTakeDamage( ent, dmgInfo )

	-- Gets the attacker
	local attacker = dmgInfo:GetAttacker()

	-- Godlike NPCs take no damage ever
	if ( IsValid( ent ) && table.HasValue( GODLIKE_NPCS, ent:GetClass() ) ) then
	
		return true
	
	end

	-- NPCs cannot be damaged by friends
	if ( IsValid( ent ) && ent:IsNPC() && ( ent:GetClass() != "npc_turret_ground" ) && IsValid( attacker ) && ( ent:Disposition( attacker ) == D_LI ) ) then
	
		return true
	
	end

	-- Gravity gun punt should kill NPC's
	if ( IsValid( ent ) && ent:IsNPC() && IsValid( attacker ) && attacker:IsPlayer() ) then
	
		if ( GetGlobalBool( "SUPER_GRAVITY_GUN" ) && IsValid( attacker:GetActiveWeapon() ) && ( attacker:GetActiveWeapon():GetClass() == "weapon_physcannon" ) ) then
		
			dmgInfo:SetDamage( ent:Health() )
		
		end
	
	end

	-- Crowbar and Stunstick should follow skill level
	if ( IsValid( ent ) && IsValid( attacker ) && attacker:IsPlayer() ) then
	
		if ( IsValid( attacker:GetActiveWeapon() ) && ( ( attacker:GetActiveWeapon():GetClass() == "weapon_crowbar" ) || ( attacker:GetActiveWeapon():GetClass() == "weapon_stunstick" ) ) ) then
		
			dmgInfo:SetDamage( 10 / difficulty )
		
		end
	
	end

end


-- Clears the player data folder
function GM:ClearPlayerDataFolder()

	local tableFiles, tableFolders = file.Find( "half-life_2_campaign/players/*", "DATA" )
	for k, v in ipairs( tableFiles ) do
	
		file.Delete( "half-life_2_campaign/players/"..v )
	
	end

end


-- Called by GoToNextLevel
function GM:GrabAndSwitch()

	changingLevel = true

	-- Since the file can build up with useless files we should clear it
	hook.Call( "ClearPlayerDataFolder", GAMEMODE )

	-- Store player information
	for _, ply in pairs( player.GetAll() ) do
	
		local plyInfo = {}
		local plyWeapons = ply:GetWeapons()
	
		plyInfo.predicted_map = NEXT_MAP
		plyInfo.health = ply:Health()
		plyInfo.armor = ply:Armor()
		plyInfo.score = ply:Frags()
		plyInfo.deaths = ply:Deaths()
		plyInfo.model = ply.modelName
		if ( IsValid( ply:GetActiveWeapon() ) ) then plyInfo.weapon = ply:GetActiveWeapon():GetClass(); end
	
		if ( plyWeapons && #plyWeapons > 0 ) then
		
			plyInfo.loadout = {}
		
			for _, wep in pairs( plyWeapons ) do
			
				plyInfo.loadout[ wep:GetClass() ] = {
					wep:Clip1(),
					wep:Clip2(),
					ply:GetAmmoCount( wep:GetPrimaryAmmoType() ),
					ply:GetAmmoCount( wep:GetSecondaryAmmoType() )
				}
			
			end
		
		end
	
		local plyID = ply:SteamID64() || ply:UniqueID()
		file.Write( "half-life_2_campaign/players/"..plyID..".txt", util.TableToJSON( plyInfo ) )
	
	end

	-- Switch maps
	game.ConsoleCommand( "changelevel "..NEXT_MAP.."\n" )

end


-- Called immediately after starting the gamemode  
function GM:Initialize()

	-- Variables and stuff
	deadPlayers = {}
	difficulty = 1
	updateDifficulty = 0
	changingLevel = false
	checkpointPositions = {}
	nextAreaOpenTime = 0
	startingWeapons = {}
	flashlightDrainsAUX = true

	-- Network strings
	util.AddNetworkString( "SetCheckpointPosition" )
	util.AddNetworkString( "NextMap" )
	util.AddNetworkString( "PlayerInitialSpawn" )
	util.AddNetworkString( "RestartMap" )
	util.AddNetworkString( "ShowHelp" )
	util.AddNetworkString( "ShowTeam" )
	util.AddNetworkString( "UpdateEnergy" )
	util.AddNetworkString( "DrowningEffect" )
	util.AddNetworkString( "UpdatePlayerModel" )

	-- We want regular fall damage and the ai to attack players and stuff
	game.ConsoleCommand( "ai_disabled 0\n" )
	game.ConsoleCommand( "ai_ignoreplayers 0\n" )
	game.ConsoleCommand( "ai_serverragdolls 0\n" )
	game.ConsoleCommand( "npc_citizen_auto_player_squad 1\n" )
	game.ConsoleCommand( "hl2_episodic 0\n" )
	game.ConsoleCommand( "mp_falldamage 1\n" )
	game.ConsoleCommand( "physgun_limited 1\n" )
	game.ConsoleCommand( "sv_alltalk 1\n" )
	game.ConsoleCommand( "sv_defaultdeployspeed 1\n" )

	-- Physcannon
	game.ConsoleCommand( "physcannon_tracelength 250\n" )
	game.ConsoleCommand( "physcannon_maxmass 250\n" )
	game.ConsoleCommand( "physcannon_pullforce 4000\n" )

	-- Episodic
	if ( string.find( game.GetMap(), "ep1_" ) || string.find( game.GetMap(), "ep2_" ) ) then
	
		game.ConsoleCommand( "hl2_episodic 1\n" )
	
	end

	-- Kill global states
	-- Reasoning behind this is because changing levels would keep these known states and cause issues on other maps
	hook.Call( "KillAllGlobalStates", GAMEMODE )

	-- Jeep
	local jeep = {
		Name = "Jeep",
		Class = "prop_vehicle_jeep_old",
		Model = "models/buggy.mdl",
		KeyValues = {
			TargetName = "jeep",
			vehiclescript =	"scripts/vehicles/jeep_test.txt"
		}
	}
	list.Set( "Vehicles", "Jeep", jeep )

	-- Airboat
	local airboat = {
		Name = "Airboat Gun",
		Class = "prop_vehicle_airboat",
		Category = Category,
		Model = "models/airboat.mdl",
		KeyValues = {
			TargetName = "airboat",
			vehiclescript = "scripts/vehicles/airboat.txt",
			EnableGun = 0
		}
	}
	list.Set( "Vehicles", "Airboat", airboat )

	-- Airboat w/gun
	local airboatGun = {
		Name = "Airboat Gun",
		Class = "prop_vehicle_airboat",
		Category = Category,
		Model = "models/airboat.mdl",
		KeyValues = {
			TargetName = "airboat",
			vehiclescript = "scripts/vehicles/airboat.txt",
			EnableGun = 1
		}
	}
	list.Set( "Vehicles", "Airboat Gun", airboatGun )

	-- Jalopy
	local jalopy = {
		Name = "Jalopy",
		Class = "prop_vehicle_jeep",
		Model = "models/vehicle.mdl",
		KeyValues = {
			TargetName = "jeep",
			vehiclescript =	"scripts/vehicles/jalopy.txt"
		}
	}
	list.Set( "Vehicles", "Jalopy", jalopy )

end


-- Function for spawn points
local function MasterPlayerStartExists()

	-- Returns true if conditions are met
	for _, ips in pairs( ents.FindByClass( "info_player_start" ) ) do
	
		if ( ips:HasSpawnFlags( 1 ) || INFO_PLAYER_SPAWN ) then
		
			return true
		
		end
	
	end

	return false

end


-- Called as soon as all map entities have been spawned 
function GM:InitPostEntity()

	-- Remove old spawn points
	if ( MasterPlayerStartExists() ) then
	
		for _, ips in pairs( ents.FindByClass( "info_player_start" ) ) do
		
			if ( !ips:HasSpawnFlags( 1 ) || INFO_PLAYER_SPAWN ) then
			
				ips:Remove()
			
			end
		
		end
	
	end

	-- Setup INFO_PLAYER_SPAWN
	if ( INFO_PLAYER_SPAWN ) then
	
		GAMEMODE:CreateSpawnPoint( INFO_PLAYER_SPAWN[ 1 ], INFO_PLAYER_SPAWN[ 2 ] )
	
	end

	-- Setup TRIGGER_CHECKPOINT
	if ( !game.SinglePlayer() && TRIGGER_CHECKPOINT ) then
	
		for _, tcpInfo in pairs( TRIGGER_CHECKPOINT ) do
		
			local tcp = ents.Create( "trigger_checkpoint" )
		
			tcp.min = tcpInfo[ 1 ]
			tcp.max = tcpInfo[ 2 ]
			tcp.pos = tcp.max - ( ( tcp.max - tcp.min ) / 2 )
			tcp.skipSpawnpoint = tcpInfo[ 3 ]
			tcp.OnTouchRun = tcpInfo[ 4 ]
		
			tcp:SetPos( tcp.pos )
			tcp:Spawn()
		
			table.insert( checkpointPositions, tcp.pos )
		
		end
	
	end

	-- Setup TRIGGER_DELAYMAPLOAD
	if ( TRIGGER_DELAYMAPLOAD ) then
	
		GAMEMODE:CreateTDML( TRIGGER_DELAYMAPLOAD[ 1 ], TRIGGER_DELAYMAPLOAD[ 2 ] )
	
		for _, tcl in pairs( ents.FindByClass( "trigger_changelevel" ) ) do
		
			tcl:Remove()
		
		end
	
	else
	
		for _, tcl in pairs( ents.FindByClass( "trigger_changelevel" ) ) do
		
			if ( tcl.map == NEXT_MAP ) then
			
				local tclMin, tclMax = tcl:WorldSpaceAABB()
				GAMEMODE:CreateTDML( tclMin, tclMax )
			
			end
			tcl:Remove()
		
		end
	
	end
	table.insert( checkpointPositions, tdmlPos )

	-- Remove all triggers that cause the game to "end"
	for _, trig in pairs( ents.FindByClass( "trigger_*" ) ) do
	
		if ( trig:GetName() == "fall_trigger" ) then
		
			trig:Remove()
		
		end
	
	end

	-- Call a map edit (used by map lua hooks)
	hook.Call( "MapEdit", GAMEMODE )

	-- Update ammo tables
	hook.Call( "UpdateAmmoTables", GAMEMODE )

end


-- Called when we need to update the ammo items and ammo max values
function GM:UpdateAmmoTables()

	-- Ammo items
	AMMO_ITEMS = {
		[ "item_ammo_357" ] = game.GetAmmoID( "357" ),
		[ "item_ammo_357_large" ] = game.GetAmmoID( "357" ),
		[ "item_ammo_ar2" ] = game.GetAmmoID( "AR2" ),
		[ "item_ammo_ar2_large" ] = game.GetAmmoID( "AR2" ),
		[ "item_ammo_ar2_altfire" ] = game.GetAmmoID( "AR2AltFire" ),
		[ "item_box_buckshot" ] = game.GetAmmoID( "Buckshot" ),
		[ "item_ammo_crossbow" ] = game.GetAmmoID( "XBowBolt" ),
		[ "item_ammo_pistol" ] = game.GetAmmoID( "Pistol" ),
		[ "item_ammo_pistol_large" ] = game.GetAmmoID( "Pistol" ),
		[ "item_rpg_round" ] = game.GetAmmoID( "RPG_Round" ),
		[ "item_ammo_smg1" ] = game.GetAmmoID( "SMG1" ),
		[ "item_ammo_smg1_large" ] = game.GetAmmoID( "SMG1" ),
		[ "item_ammo_smg1_grenade" ] = game.GetAmmoID( "SMG1_Grenade" )
	}

	-- Ammo max values
	AMMO_MAX_VALUES = {
		[ game.GetAmmoID( "357" ) ] = GetConVarNumber( "sk_max_357" ),
		[ game.GetAmmoID( "AR2" ) ] = GetConVarNumber( "sk_max_ar2" ),
		[ game.GetAmmoID( "AR2AltFire" ) ] = GetConVarNumber( "sk_max_ar2_altfire" ),
		[ game.GetAmmoID( "Buckshot" ) ] = GetConVarNumber( "sk_max_buckshot" ),
		[ game.GetAmmoID( "XBowBolt" ) ] = GetConVarNumber( "sk_max_crossbow" ),
		[ game.GetAmmoID( "Grenade" ) ] = GetConVarNumber( "sk_max_grenade" ),
		[ game.GetAmmoID( "Pistol" ) ] = GetConVarNumber( "sk_max_pistol" ),
		[ game.GetAmmoID( "RPG_Round" ) ] = GetConVarNumber( "sk_max_rpg_round" ),
		[ game.GetAmmoID( "SMG1" ) ] = GetConVarNumber( "sk_max_smg1" ),
		[ game.GetAmmoID( "SMG1_Grenade" ) ] = GetConVarNumber( "sk_max_smg1_grenade" )
	}

end
concommand.Add( "hl2c_update_ammo_tables", function( ply ) if ( IsValid( ply ) && ply:IsAdmin() ) then hook.Call( "UpdateAmmoTables", GAMEMODE ); end end )


-- Called automatically or by the console command
function GM:NextMap()

	if ( changingLevel ) then
	
		return
	
	end

	changingLevel = true

	net.Start( "NextMap" )
		net.WriteFloat( CurTime() )
	net.Broadcast()

	timer.Simple( NEXT_MAP_TIME, function() self:GrabAndSwitch() end )

end
concommand.Add( "hl2c_next_map", function( ply ) if ( IsValid( ply ) && ply:IsAdmin() ) then NEXT_MAP_TIME = 0; hook.Call( "NextMap", GAMEMODE ); end end )


-- Called when an NPC dies
function GM:OnNPCKilled( npc, killer, weapon )

	if ( IsValid( killer ) && killer:IsVehicle() && IsValid( killer:GetDriver() ) && killer:GetDriver():IsPlayer() ) then
	
		killer = killer:GetDriver()
	
	end

	-- If the killer is a player then decide what to do with their points
	if ( IsValid( killer ) && killer:IsPlayer() && IsValid( npc ) ) then
	
		if ( NPC_POINT_VALUES[ npc:GetClass() ] ) then
		
			killer:AddFrags( NPC_POINT_VALUES[ npc:GetClass() ] )
		
		else
		
			killer:AddFrags( 1 )
		
		end
	
	end

	-- If the NPC is godlike and they die
	if ( IsValid( npc ) ) then
	
		if ( table.HasValue( GODLIKE_NPCS, npc:GetClass() ) ) then
		
			if ( IsValid( killer ) && killer:IsPlayer() ) then game.KickID( killer:UserID(), "You killed an important NPC actor!" ); end
			GAMEMODE:RestartMap()
		
		end
	
	end

	-- Convert the inflictor to the weapon that they're holding if we can
	if ( IsValid( weapon ) && ( killer == weapon ) && ( weapon:IsPlayer() || weapon:IsNPC() ) ) then
	
		weapon = weapon:GetActiveWeapon() 
		if ( !IsValid( killer ) ) then weapon = killer; end 
	
	end 

	-- Defaults
	local weaponClass = "World" 
	local killerClass = "World" 

	-- Change to actual values if not default
	if ( IsValid( weapon ) ) then weaponClass = weapon:GetClass(); end 
	if ( IsValid( killer ) ) then killerClass = killer:GetClass(); end 

	-- Send a message
	if ( IsValid( killer ) && killer:IsPlayer() ) then
	
		net.Start( "PlayerKilledNPC" )
			net.WriteString( npc:GetClass() )
			net.WriteString( weaponClass )
			net.WriteEntity( killer )
		net.Broadcast()
	
	end

end


-- Called when a player tries to pickup a weapon
function GM:PlayerCanPickupWeapon( ply, wep )

	if ( ( ply:Team() != TEAM_ALIVE ) || ( ( wep:GetClass() == "weapon_physgun" ) && !ply:IsAdmin() ) ) then
	
		return false
	
	end

	-- This prevents melee weapons disappearing
	if ( ( wep:GetPrimaryAmmoType() <= 0 ) && ply:HasWeapon( wep:GetClass() ) ) then
	
		return false
	
	end

	if ( hl2c_server_ammo_limit:GetBool() && ply:HasWeapon( wep:GetClass() ) && ( wep:GetPrimaryAmmoType() > 0 ) && AMMO_MAX_VALUES[ wep:GetPrimaryAmmoType() ] && ( ply:GetAmmoCount( wep:GetPrimaryAmmoType() ) >= AMMO_MAX_VALUES[ wep:GetPrimaryAmmoType() ] ) ) then
	
		return false
	
	end

	return true

end


-- Called when a player tries to pickup an item
function GM:PlayerCanPickupItem( ply, item )

	if ( ply:Team() != TEAM_ALIVE ) then
	
		return false
	
	end

	if ( hl2c_server_ammo_limit:GetBool() && AMMO_ITEMS[ item:GetClass() ] && AMMO_MAX_VALUES[ AMMO_ITEMS[ item:GetClass() ] ] && ( ply:GetAmmoCount( AMMO_ITEMS[ item:GetClass() ] ) >= AMMO_MAX_VALUES[ AMMO_ITEMS[ item:GetClass() ] ] ) ) then
	
		return false
	
	end

	return true

end


-- Called when a player disconnects
function GM:PlayerDisconnected( ply )

	local plyID = ply:SteamID64() || ply:UniqueID()
	if ( file.Exists( "half-life_2_campaign/players/"..plyID..".txt", "DATA" ) ) then
	
		file.Delete( "half-life_2_campaign/players/"..plyID..".txt" )
	
	end

	ply:RemoveVehicle()

	if ( game.IsDedicated() && ( player.GetCount() <= 1 ) ) then
	
		game.ConsoleCommand( "changelevel "..game.GetMap().."\n" )
	
	end

end


-- Called just before the player's first spawn 
function GM:PlayerInitialSpawn( ply )

	ply.startTime = CurTime()
	ply:SetTeam( TEAM_ALIVE )

	-- Grab previous map info
	local plyID = ply:SteamID64() || ply:UniqueID()
	if ( file.Exists( "half-life_2_campaign/players/"..plyID..".txt", "DATA" ) ) then
	
		ply.info = util.JSONToTable( file.Read( "half-life_2_campaign/players/"..plyID..".txt", "DATA" ) )
	
		if ( ( ply.info.predicted_map != game.GetMap() ) || RESET_PL_INFO ) then
		
			file.Delete( "half-life_2_campaign/players/"..plyID..".txt" )
			ply.info = nil
		
		elseif ( RESET_WEAPONS ) then
		
			ply.info.loadout = nil
		
		end
	
	end

	-- Send initial player spawn to client
	net.Start( "PlayerInitialSpawn" )
		net.WriteBool( hl2c_server_custom_playermodels:GetBool() )
	net.Send( ply )

	-- Send current checkpoint position
	if ( #checkpointPositions > 0 ) then
	
		net.Start( "SetCheckpointPosition" )
			net.WriteVector( checkpointPositions[ 1 ] )
		net.Send( ply )
	
	end

	-- Prompt players that they can spawn vehicles
	if ( ALLOWED_VEHICLE ) then
	
		ply:ChatPrint( "Vehicle spawning is allowed! Press F3 (Spare 1) to spawn it." )
	
	end

end 


-- Called by GM:PlayerSpawn
function GM:PlayerLoadout( ply )

	if ( ply.info && ply.info.loadout ) then
	
		for wep, ammo in pairs( ply.info.loadout ) do
		
			ply:Give( wep )
		
		end
	
		if ( ply.info.weapon ) then
		
			ply:SelectWeapon( ply.info.weapon )
		
		end
	
		ply:RemoveAllAmmo()
	
		for _, wep in pairs( ply:GetWeapons() ) do
		
			local wepClass = wep:GetClass()
		
			if ( ply.info.loadout[ wepClass ] ) then
			
				wep:SetClip1( tonumber( ply.info.loadout[ wepClass ][ 1 ] ) )
				wep:SetClip2( tonumber( ply.info.loadout[ wepClass ][ 2 ] ) )
				ply:GiveAmmo( tonumber( ply.info.loadout[ wepClass ][ 3 ] ), wep:GetPrimaryAmmoType() )
				ply:GiveAmmo( tonumber( ply.info.loadout[ wepClass ][ 4 ] ), wep:GetSecondaryAmmoType() )
			
			end
		
		end
	
	elseif ( startingWeapons && ( #startingWeapons > 0 ) ) then
	
		for _, wep in pairs( startingWeapons ) do
		
			ply:Give( wep )
		
		end
	
	end

	-- Lastly give physgun to admins
	if ( hl2c_admin_physgun:GetBool() && ply:IsAdmin() ) then
	
		ply:Give( "weapon_physgun" )
	
	end

	hook.Call( "PostPlayerLoadout", GAMEMODE, ply )

end


-- Called when the player attempts to noclip
function GM:PlayerNoClip( ply )

	return ( ply:IsAdmin() && hl2c_admin_noclip:GetBool() )

end


-- Returns whether the spawnpoint is suitable or not
function GM:IsSpawnpointSuitable( ply, spawnpointEnt, bMakeSuitable )

	return true

end


-- Select the player spawn
function hl2cPlayerSelectSpawn( ply )

	if ( MasterPlayerStartExists() ) then
	
		local spawnPoints = ents.FindByClass( "info_player_start" )
		return spawnPoints[ #spawnPoints ]
	
	end

end
hook.Add( "PlayerSelectSpawn", "hl2cPlayerSelectSpawn", hl2cPlayerSelectSpawn )


-- Set the player model
function GM:PlayerSetModel( ply )

	-- Stores the model as a variable part of the player
	if ( !hl2c_server_custom_playermodels:GetBool() && ply.info && ply.info.model ) then
	
		ply.modelName = ply.info.model
	
	else
	
		local modelName = player_manager.TranslatePlayerModel( ply:GetInfo( "cl_playermodel" ) )
	
		if ( hl2c_server_custom_playermodels:GetBool() || ( modelName && table.HasValue( PLAYER_MODELS, string.lower( modelName ) ) ) ) then
		
			ply.modelName = modelName
		
		else
		
			ply.modelName = table.Random( PLAYER_MODELS )
		
		end
	
	end

	if ( !hl2c_server_custom_playermodels:GetBool() ) then
	
		if ( ply:IsSuitEquipped() ) then
		
			ply.modelName = string.gsub( string.lower( ply.modelName ), "group01", "group03" )
		
		else
		
			ply.modelName = string.gsub( string.lower( ply.modelName ), "group03", "group01" )
		
		end
	
	end

	-- Precache and set the model
	util.PrecacheModel( ply.modelName )
	ply:SetModel( ply.modelName )
	ply:SetupHands()

	-- Skin, modelgroups and player color are primarily a custom playermodel thing
	if ( hl2c_server_custom_playermodels:GetBool() ) then
	
		ply:SetSkin( ply:GetInfoNum( "cl_playerskin", 0 ) )
	
		ply.modelGroups = ply:GetInfo( "cl_playerbodygroups" )
		if ( ply.modelGroups == nil ) then ply.modelGroups = "" end
		ply.modelGroups = string.Explode( " ", ply.modelGroups )
		for k = 0, ( ply:GetNumBodyGroups() - 1 ) do
		
			ply:SetBodygroup( k, ( tonumber( ply.modelGroups[ k + 1 ] ) || 0 ) )
		
		end
	
		ply:SetPlayerColor( Vector( ply:GetInfo( "cl_playercolor" ) ) )
	
	end

	-- A hook for those who want to call something after the player model is set
	hook.Call( "PostPlayerSetModel", GAMEMODE, ply )

end


-- Called when a player spawns 
function GM:PlayerSpawn( ply )

	player_manager.SetPlayerClass( ply, "player_default" )

	if ( ( ( !hl2c_server_player_respawning:GetBool() && !FORCE_PLAYER_RESPAWNING ) || OVERRIDE_PLAYER_RESPAWNING ) && ( ply:Team() == TEAM_DEAD ) ) then
	
		ply:Spectate( OBS_MODE_ROAMING )
		ply:SetPos( ply.deathPos )
		ply:SetNoTarget( true )
	
		return
	
	end

	-- If we made it this far we might might not even be dead
	ply:SetTeam( TEAM_ALIVE )

	-- Player vars
	ply.energy = 100
	ply.givenWeapons = {}
	ply.healthRemoved = 0
	ply.nextEnergyCycle = 0
	ply.nextSetHealth = 0
	ply:SetNWBool( "sprintDisabled", false )
	ply.vulnerable = false
	timer.Simple( VULNERABLE_TIME, function() if IsValid( ply ) then ply.vulnerable = true; end end )

	-- Player statistics
	ply:UnSpectate()
	ply:ShouldDropWeapon( ( !hl2c_server_player_respawning:GetBool() && !FORCE_PLAYER_RESPAWNING ) || OVERRIDE_PLAYER_RESPAWNING )
	ply:AllowFlashlight( true )
	ply:SetCrouchedWalkSpeed( 0.3 )
	hook.Call( "SetPlayerSpeed", GAMEMODE, ply, 190, 320 )
	hook.Call( "PlayerSetModel", GAMEMODE, ply )
	hook.Call( "PlayerLoadout", GAMEMODE, ply )

	-- Set stuff from last level
	if ( ply.info ) then
	
		if ( ply.info.health > 0 ) then
		
			ply:SetHealth( ply.info.health )
		
		end
	
		if ( ply.info.armor > 0 ) then
		
			ply:SetArmor( ply.info.armor )
		
		end
	
		ply:SetFrags( ply.info.score )
		ply:SetDeaths( ply.info.deaths )
	
	end

	-- Players should avoid players
	ply:SetCustomCollisionCheck( !game.SinglePlayer() )
	ply:SetAvoidPlayers( false )
	ply:SetNoTarget( false )

	-- If the player died before, kill them again
	if ( table.HasValue( deadPlayers, ply:SteamID() ) ) then
	
		ply:PrintMessage( HUD_PRINTTALK, "You cannot respawn now." )
	
		ply.deathPos = ply:EyePos()
	
		ply:RemoveVehicle()
		ply:Flashlight( false )
		ply:SetTeam( TEAM_DEAD )
		ply:AddDeaths( 1 )
	
		ply:KillSilent()
	
	end

end


-- Called when a player uses their flashlight
function GM:PlayerSwitchFlashlight( ply, on )

	if ( ply:Team() != TEAM_ALIVE ) then
	
		return false
	
	end

	return ( ply:CanUseFlashlight() && ply:IsSuitEquipped() && ( !flashlightDrainsAUX || !ply:GetNWBool( "sprintDisabled", false ) ) )

end


-- Called when a player uses something
function GM:PlayerUse( ply, ent )

	if ( ( ent:GetName() == "telescope_button" ) || ( ply:Team() != TEAM_ALIVE ) ) then
	
		return false
	
	end

	return true

end


-- Called to control whether a player can enter the vehicle or not
function GM:CanPlayerEnterVehicle( ply, vehicle, role )

	-- Used for passenger seating
	ply:SetAllowWeaponsInVehicle( vehicle.allowWeapons )

	return true

end


-- Called automatically and by the console command
function GM:RestartMap()

	if ( changingLevel ) then
	
		return
	
	end

	changingLevel = true

	net.Start( "RestartMap" )
		net.WriteFloat( CurTime() )
	net.Broadcast()

	for _, ply in pairs( player.GetAll() ) do
	
		ply:SendLua( "GAMEMODE.ShowScoreboard = true" )
	
	end

	timer.Simple( RESTART_MAP_TIME, function() game.ConsoleCommand( "changelevel "..game.GetMap().."\n" ) end )

end
concommand.Add( "hl2c_restart_map", function( ply ) if ( IsValid( ply ) && ply:IsAdmin() ) then RESTART_MAP_TIME = 0; hook.Call( "RestartMap", GAMEMODE ); end end )


-- Called every time a player does damage to an npc
function GM:ScaleNPCDamage( npc, hitGroup, dmgInfo )

	-- Where are we hitting?
	if ( hitGroup == HITGROUP_HEAD ) then
	
		hitGroupScale = 2
	
	else
	
		hitGroupScale = 1
	
	end

	-- Calculate the damage
	dmgInfo:ScaleDamage( hitGroupScale / difficulty )

end


-- Scale the damage based on being shot in a hitbox 
function GM:ScalePlayerDamage( ply, hitGroup, dmgInfo )

	-- Where are we hitting?
	if ( hitGroup == HITGROUP_HEAD ) then
	
		hitGroupScale = 2
	
	else
	
		hitGroupScale = 1
	
	end

	-- Calculate the damage
	dmgInfo:ScaleDamage( hitGroupScale * difficulty )

end 


-- Called when player presses their help key
function GM:ShowHelp( ply )

	net.Start( "ShowHelp" )
	net.Send( ply )

end


-- Called when a player presses their show team key
function GM:ShowTeam( ply )

	net.Start( "ShowTeam" )
	net.Send( ply )

end


-- Called when player wants a vehicle
function GM:ShowSpare1( ply )

	if ( ( ply:Team() != TEAM_ALIVE ) || ply:InVehicle() ) then
	
		return
	
	end

	if ( !ALLOWED_VEHICLE ) then
	
		ply:PrintMessage( HUD_PRINTTALK, "You may not spawn a vehicle at this time." )
		return
	
	end

	for _, ent in pairs( ents.FindInSphere( ply:GetPos(), 256 ) ) do
	
		if ( IsValid( ent ) && ent:IsPlayer() && ( ent != ply ) ) then
		
			ply:PrintMessage( HUD_PRINTTALK, "There are players around you! Find an open space to spawn your vehicle." )
			return
		
		end
	
	end

	ply:RemoveVehicle()

	-- Spawn the vehicle
	if ( ALLOWED_VEHICLE ) then
	
		local vehicleList = list.Get( "Vehicles" )
		local vehicle = vehicleList[ ALLOWED_VEHICLE ]
	
		if ( !vehicle ) then
		
			return
		
		end
	
		-- Create the new entity
		ply.vehicle = ents.Create( vehicle.Class )
		ply.vehicle:SetModel( vehicle.Model )
	
		-- Set keyvalues
		for a, b in pairs( vehicle.KeyValues ) do
		
			ply.vehicle:SetKeyValue( a, b )
		
		end
	
		-- Enable gun on jeep
		if ( ALLOWED_VEHICLE == "Jeep" ) then
		
			ply.vehicle:Fire( "EnableGun", "1" )
		
		end
	
		-- Set pos/angle and spawn
		local plyAngle = ply:EyeAngles()
		ply.vehicle:SetPos( ply:GetPos() + Vector( 0, 0, 48 ) + plyAngle:Forward() * 128 )
		ply.vehicle:SetAngles( Angle( 0, plyAngle.y - 90, 0 ) )
		ply.vehicle:Spawn()
		ply.vehicle:Activate()
		if ( ALLOWED_VEHICLE == "Jeep" ) then ply.vehicle:SetBodygroup( 1, 1 ) end
		ply.vehicle.creator = ply
	
	end

end


-- Called when player wants to remove their vehicle
function GM:ShowSpare2( ply )

	if ( ( ply:Team() != TEAM_ALIVE ) || ply:InVehicle() ) then
	
		return
	
	end

	if ( !ALLOWED_VEHICLE ) then
	
		ply:PrintMessage( HUD_PRINTTALK, "You may not remove your vehicle at this time." )
		return
	
	end

	ply:RemoveVehicle()

end


-- Called every frame 
function GM:Think()

	-- Restart the map if all players are dead
	if ( ( ( !hl2c_server_player_respawning:GetBool() && !FORCE_PLAYER_RESPAWNING ) || OVERRIDE_PLAYER_RESPAWNING ) && ( player.GetCount() > 0 ) && ( ( team.NumPlayers( TEAM_ALIVE ) + team.NumPlayers( TEAM_COMPLETED_MAP ) ) <= 0 ) ) then
	
		hook.Call( "RestartMap", GAMEMODE )
	
	end

	-- Change the difficulty according to number of players
	if ( hl2c_server_dynamic_skill_level:GetBool() && ( player.GetCount() > 0 ) && ( updateDifficulty < CurTime() ) ) then
	
		difficulty = math.Clamp( player.GetCount() / 32 * 3, DIFFICULTY_RANGE[ 1 ], DIFFICULTY_RANGE[ 2 ] )
		game.ConsoleCommand( "skill "..math.floor( difficulty ).."\n" )
	
		-- Do not update all the time
		updateDifficulty = CurTime() + 5
	
	end

	-- Open area portals
	if ( nextAreaOpenTime <= CurTime() ) then
	
		for _, fap in pairs( ents.FindByClass( "func_areaportal" ) ) do
		
			fap:Fire( "Open" )
		
		end
	
		nextAreaOpenTime = CurTime() + 1
	
	end

end


-- Player just picked up or was given a weapon
function GM:WeaponEquip( wep )

	if ( IsValid( wep ) && !table.HasValue( startingWeapons, wep:GetClass() ) ) then
	
		table.insert( startingWeapons, wep:GetClass() )
	
	end

end


-- Tell the game to update the player's playermodel
local function UpdatePlayerModel( len, ply )

	if ( IsValid( ply ) && ( ply:Team() == TEAM_ALIVE ) ) then
	
		hook.Call( "PlayerSetModel", GAMEMODE, ply )
	
	end

end
net.Receive( "UpdatePlayerModel", UpdatePlayerModel )


-- Dynamic skill level console variable was changed
local function DynamicSkillToggleCallback( name, old, new )

	if ( !hl2c_server_dynamic_skill_level:GetBool() ) then
	
		difficulty = DIFFICULTY_RANGE[ 1 ]
		game.ConsoleCommand( "skill "..math.Round( difficulty ).."\n" )
	
	end

end
cvars.AddChangeCallback( "hl2c_server_dynamic_skill_level", DynamicSkillToggleCallback, "DynamicSkillToggleCallback" )
