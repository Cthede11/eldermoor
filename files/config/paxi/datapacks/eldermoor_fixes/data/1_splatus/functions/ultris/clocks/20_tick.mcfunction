
execute store result score gamerule_mobGriefing datasettings run gamerule mobGriefing

execute as @a unless score @s ultris_uuid1 = @s ultris_uuid1 store result score @s ultris_uuid1 run data get entity @s UUID[0]
execute as @a unless score @s ultris_uuid2 = @s ultris_uuid2 store result score @s ultris_uuid2 run data get entity @s UUID[1]
execute as @a unless score @s ultris_uuid3 = @s ultris_uuid3 store result score @s ultris_uuid3 run data get entity @s UUID[2]
execute as @a unless score @s ultris_uuid4 = @s ultris_uuid4 store result score @s ultris_uuid4 run data get entity @s UUID[3]

scoreboard players set 1sec ultris_clock 0