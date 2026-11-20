// Eldermoor: every item the Reforge Station accepts gets an eldermoor:reforge/<kind> tag (tools/reforge.py).
// Tiered pools for those tags live in kubejs/data/eldermoor/tiered_modifiers/pools/reforge.
let $ForgeReg = Java.loadClass('net.minecraftforge.registries.ForgeRegistries')
let $ToolActions = Java.loadClass('net.minecraftforge.common.ToolActions')
let $I = n => Java.loadClass('net.minecraft.world.item.' + n)
let R_ARMOR = $I('ArmorItem'), R_SHIELD = $I('ShieldItem'), R_BOW = $I('BowItem'), R_XBOW = $I('CrossbowItem'),
    R_ROD = $I('FishingRodItem'), R_SHEARS = $I('ShearsItem'), R_PICK = $I('PickaxeItem'), R_SHOVEL = $I('ShovelItem'),
    R_HOE = $I('HoeItem'), R_AXE = $I('AxeItem'), R_SWORD = $I('SwordItem'), R_TRIDENT = $I('TridentItem')

function reforgeKind(item) {
  // same classes the station's input slot accepts
  if (item instanceof R_ARMOR) return 'armor'
  if (item instanceof R_SHIELD) return 'shields'
  if (item instanceof R_BOW || item instanceof R_XBOW) return 'bows'
  if (item instanceof R_ROD) return 'fishing'
  let tool = item instanceof R_PICK || item instanceof R_SHOVEL || item instanceof R_HOE || item instanceof R_SHEARS
  let axe = item instanceof R_AXE
  if (tool || axe) {
    let st = item.getDefaultInstance()
    // a paxel or hammer is an AxeItem that also digs like a pickaxe: it reforges as a mining tool
    if (tool || st.canPerformAction($ToolActions.PICKAXE_DIG) || st.canPerformAction($ToolActions.SHOVEL_DIG)) return 'tools'
    return 'axes'
  }
  if (item instanceof R_SWORD || item instanceof R_TRIDENT) return 'melee'
  return null
}

ServerEvents.tags('item', e => {
  let n = 0
  $ForgeReg.ITEMS.getValues().forEach(item => {
    let kind = null
    try { kind = reforgeKind(item) } catch (err) { return }
    if (kind == null) return
    e.add('eldermoor:reforge/' + kind, String($ForgeReg.ITEMS.getKey(item)))
    n++
  })
  console.info('eldermoor reforge: tagged ' + n + ' items the Reforge Station accepts')
})
