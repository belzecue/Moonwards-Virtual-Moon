extends AEntity
# TODO: Decide whether a single type of entities will be enough.
# Should start showing when we add more things to the game.
class_name ActorEntity
# Entity class, serves as a medium between Components to communicate.

## Spatial Entity common data

# The current `state` of the entity. 
# Contains metadata in regards to what entity is currently doing.
var state: ActorEntityState = ActorEntityState.new()

# `MASTER`
# Input vector
master var input: Vector3 = Vector3.ZERO

# `REMOTE`
# Look dir of our actor
master var look_dir: Vector3 = Vector3.ZERO

# `PUPPET`
# The world position of this entity on the server
puppet var srv_pos: Vector3 = Vector3.ZERO

# Velocity of the actor
var velocity = Vector3()


func _process_server(_delta) -> void:
#	for p in Network.network_instance.players.values():
#		if p.peer_id != 1:
#			rset_unreliable_id(p.peer_id, "srv_pos", srv_pos)
	rset("srv_pos", srv_pos)
#	rset_unreliable("look_dir", look_dir)

func _process_client(_delta) -> void:
	rset_unreliable_id(1, "input", input)
#	rset_unreliable_id(1, "look_dir", look_dir)
