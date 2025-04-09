class_name component_health
extends Node3D

var anim_player : AnimationPlayer = null
@export var current_health : float :
	set(new_health):
		#print(new_health)
		if new_health <= current_health:
			anim_player.play("take_damage")
			#current_health = new_health
			if current_health <= 0:
				anim_player.play("die")
			else:
				anim_player.queue("idle")
		current_health = new_health


func _ready() -> void:
	for i in get_parent().get_children():
		if i.get_node_or_null("AnimationPlayer") is AnimationPlayer:
			anim_player = i.get_node_or_null("AnimationPlayer")

#func take_damage(attack : Attack) -> void:
	#current_health -= attack.attack_damage
	
#func _process(delta: float) -> void:
	#if anim_player:
		#if anim_player.current_animation != "take_damage" and anim_player.current_animation != "idle":
			#anim_player.play("idle")
