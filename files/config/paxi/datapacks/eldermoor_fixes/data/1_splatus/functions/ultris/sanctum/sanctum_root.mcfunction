
######### OMINOUS #########

#pearl1
execute as @e[type=ender_pearl,nbt={Item:{id:"minecraft:ender_pearl",Count:1b,tag:{UltrisOminousPearl:1,Enchantments:[{id:"minecraft:unbreaking"}]}}}] at @s run function 1_splatus:ultris/sanctum/pearl

#ender eye
execute as @e[type=eye_of_ender,nbt={Item:{id:"minecraft:ender_eye",Count:1b,tag:{UltrisOminousPearl:1,Enchantments:[{id:"minecraft:unbreaking"}]}}}] at @s run function 1_splatus:ultris/sanctum/endereye


#tps to nearest player 
execute as @e[type=item,tag=ultris_endereye] at @s run function 1_splatus:ultris/sanctum/endereye_item

###################################


# Loads function for the sanctum (1_splatus:ultris/sanctum/position)


execute if score 5tick ultris_clock matches 1 as @a at @s unless entity @e[distance=..64,type=#1_splatus:ultris/sanctum_pos,tag=sanctumpos] run tag @s remove ultris_player_64blocks_sanctum
execute if score 5tick ultris_clock matches 1 as @a at @s if entity @e[distance=..64,type=#1_splatus:ultris/sanctum_pos,tag=sanctumpos] run tag @s add ultris_player_64blocks_sanctum

execute if entity @a[tag=ultris_player_64blocks_sanctum] run function 1_splatus:ultris/sanctum/position






#xp
execute if score 5tick ultris_clock matches 2 as @a store result score @s ultris_xp run xp query @s levels


#thing with enderman
execute if score 5tick ultris_clock matches 1..2 as @e[type=item,nbt={Item:{id:"minecraft:glowstone_dust",Count:1b,tag:{CorruptDust:1}}}] at @s run function 1_splatus:ultris/sanctum/enderman_convert




#clear flames
execute if score 1 randomizer2 matches 1 if entity @e[tag=sanctum_var_pos] run function 1_splatus:ultris/sanctum/clear_fire