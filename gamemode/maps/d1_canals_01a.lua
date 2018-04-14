NEXT_MAP = "d1_canals_02"


-- Player spawns
function hl2cPlayerSpawn( ply )

	ply:Give( "weapon_crowbar" )
	ply:Give( "weapon_pistol" )

end
hook.Add( "PlayerSpawn", "hl2cPlayerSpawn", hl2cPlayerSpawn )


-- Initialize entities
function hl2cInitPostEntity()

	ents.FindByName( "spawnitems_template" )[ 1 ]:Remove()

end
hook.Add( "InitPostEntity", "hl2cInitPostEntity", hl2cInitPostEntity )
