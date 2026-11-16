scoreboard objectives add eldermoor_chk dummy

execute as @a store result score @s eldermoor_chk run clear @s minecraft:enchanted_book{UltrisEnchantedCharm:1} 0
execute as @a[scores={eldermoor_chk=1..},tag=!ultris_hascharm] at @s run function 1_splatus:ultris/wither/has_charm
execute as @a[tag=ultris_hascharm] unless score @s eldermoor_chk matches 1.. run function 1_splatus:ultris/wither/has_charm_lol_not

execute as @e[type=item,nbt={Item:{id:"minecraft:netherite_helmet",tag:{ShulkerShellHelmet:1}}}] at @s unless block ~ ~-0.05 ~ #1_splatus:ultris/permeable run function 1_splatus:ultris/other/misc/convert_netherite

scoreboard players set 5tick ultris_clock 0