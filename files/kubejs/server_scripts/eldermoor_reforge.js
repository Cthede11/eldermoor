// Eldermoor: every item the Reforge Station accepts gets an eldermoor:reforge/<kind> tag (tools/reforge.py).
// Tiered pools for those tags live in kubejs/data/eldermoor/tiered_modifiers/pools/reforge.
// The class tests run in Java (Guava's Predicates.instanceOf over the item registry), so no item object reaches the
// script: handing all items to JavaScript made Rhino build and keep a reflection table for each of ~4,800 item
// classes, about 400 MB of memory for as long as the game ran (measured 2026-11-23, tools/perftest.py --histo).
let $ForgeReg = Java.loadClass('net.minecraftforge.registries.ForgeRegistries')
let $ToolActions = Java.loadClass('net.minecraftforge.common.ToolActions')
let $Preds = Java.loadClass('com.google.common.base.Predicates')
let $Maps = Java.loadClass('com.google.common.collect.Maps')
let $ImmutableMap = Java.loadClass('com.google.common.collect.ImmutableMap')
let $I = n => Java.loadClass('net.minecraft.world.item.' + n)    // a class wrapper: Java receives the Class itself

function itemsOf(all, names) {
  let p = null
  names.forEach(n => { let q = $Preds.instanceOf($I(n)); p = p == null ? q : $Preds['or(com.google.common.base.Predicate,com.google.common.base.Predicate)'](p, q) })
  return $Maps['filterValues(java.util.Map,com.google.common.base.Predicate)'](all, p).keySet()     // ResourceKeys only
}

ServerEvents.tags('item', e => {
  // overloads named explicitly: Rhino finds copyOf(Map) and copyOf(Iterable) equally good for a Set
  let all = $ImmutableMap['copyOf(java.lang.Iterable)']($ForgeReg.ITEMS.getEntries())
  let done = {}, counts = {}, n = 0
  let tag = (kind, names, test) => itemsOf(all, names).forEach(k => {
    let id = String(k.location())
    if (done[id]) return
    if (test) { try { if (!test(id)) return } catch (err) { return } }
    done[id] = true
    e.add('eldermoor:reforge/' + kind, id)
    counts[kind] = (counts[kind] || 0) + 1
    n++
  })
  // same classes the station's input slot accepts, first match wins
  tag('armor', ['ArmorItem'])
  tag('shields', ['ShieldItem'])
  tag('bows', ['BowItem', 'CrossbowItem'])
  tag('fishing', ['FishingRodItem'])
  tag('tools', ['PickaxeItem', 'ShovelItem', 'HoeItem', 'ShearsItem'])
  // a paxel or hammer is an AxeItem that also digs like a pickaxe: it reforges as a mining tool
  tag('tools', ['AxeItem'], id => { let st = Item.of(id); return st.canPerformAction($ToolActions.PICKAXE_DIG) || st.canPerformAction($ToolActions.SHOVEL_DIG) })
  tag('axes', ['AxeItem'])
  tag('melee', ['SwordItem', 'TridentItem'])
  console.info('eldermoor reforge: tagged ' + n + ' items the Reforge Station accepts (' + Object.keys(counts).map(k => k + ' ' + counts[k].toFixed(0)).join(', ') + ')')
})
