scoreboard objectives add eldermoor_chk dummy
#ADVANCEMENTS------------------------
advancement grant @a only 1_splatus:ultris/root

execute if score 1sec ultris_clock matches 1 as @a[advancements={1_splatus:ultris/sanctum/eye_of_ender=false}] store result score @s eldermoor_chk run clear @s minecraft:ender_eye{display:{Name:'{"translate":"Ominous Pearl","color":"light_purple","italic":true}'},Enchantments:[{id:"minecraft:unbreaking",lvl:1s}]} 0
execute if score 1sec ultris_clock matches 1 run advancement grant @a[advancements={1_splatus:ultris/sanctum/eye_of_ender=false},scores={eldermoor_chk=1..}] only 1_splatus:ultris/sanctum/eye_of_ender

execute if score 1sec ultris_clock matches 1 as @a[advancements={1_splatus:ultris/command=false}] store result score @s eldermoor_chk run clear @s minecraft:command_block{display:{Name:'{"translate":"Ominous Pearl","color":"light_purple","italic":true}'},Enchantments:[{id:"minecraft:unbreaking",lvl:1s}]} 0
execute if score 1sec ultris_clock matches 1 run advancement grant @a[advancements={1_splatus:ultris/command=false},scores={eldermoor_chk=1..}] only 1_splatus:ultris/command

#ALL
execute if score 5tick ultris_clock matches 1 run function 1_splatus:ultris/other/check_advancement

execute as @a[advancements={1_splatus:ultris/completed=true},tag=!ultris_completed_all_bosses] at @s run function 1_splatus:ultris/music/play_ultrisconqueror
execute as @a[advancements={1_splatus:ultris/completed=true},tag=!ultris_completed_all_bosses] at @s run function 1_splatus:ultris/music/play_ultrisconqueror2

execute as @a[advancements={1_splatus:ultris/completed=true},tag=!ultris_completed_all_bosses] at @s run tag @s add ultris_completed_all_bosses

execute as @a[advancements={1_splatus:ultris/completed_ultra=true},tag=!ultris_completed_all_bosses_ultra] at @s run function 1_splatus:ultris/music/play_ultrisconqueror
execute as @a[advancements={1_splatus:ultris/completed_ultra=true},tag=!ultris_completed_all_bosses_ultra] at @s run function 1_splatus:ultris/music/play_ultrisconqueror2
execute as @a[advancements={1_splatus:ultris/completed_ultra=true},tag=!ultris_completed_all_bosses_ultra] at @s run tag @s add ultris_completed_all_bosses_ultra



execute as @a[advancements={1_splatus:ultris/completed_ultra=false},tag=ultris_completed_all_bosses_ultra] at @s run tag @s remove ultris_completed_all_bosses_ultra
execute as @a[advancements={1_splatus:ultris/completed=false},tag=ultris_completed_all_bosses] at @s run tag @s remove ultris_completed_all_bosses
#-----------------
