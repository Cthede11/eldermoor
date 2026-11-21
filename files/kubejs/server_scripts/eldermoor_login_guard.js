// Login protection: no damage while the world is still loading on the player's screen.
// Written by tools/login_guard.py - edit it there, assemble.py overwrites this file.
const GUARD_MAX = 2400          // ticks: hard cap after login
const GUARD_GRACE = 60       // ticks of protection left once the player takes control
let Mob = null
try {
  Mob = Java.loadClass('net.minecraft.world.entity.Mob')
} catch (e) {
  console.error('[eldermoor] login guard: mob calming disabled: ' + e)
}

// Rotation as the properties yRot/xRot: on the server KubeJS finds neither getYRot() nor m_146908_() (probed 2026-11-21).
// Inside blocks use let, not const: Rhino throws "redeclaration of var" when a block with a const runs twice.
function guardBaseline(player, data) {
  data.putDouble('eldermoorGuardX', player.x)
  data.putDouble('eldermoorGuardZ', player.z)
  data.putFloat('eldermoorGuardYaw', player.yRot)
  data.putFloat('eldermoorGuardPitch', player.xRot)
}

PlayerEvents.loggedIn(event => {
  const player = event.player
  const data = player.persistentData
  data.putInt('eldermoorGuard', GUARD_MAX)
  data.putBoolean('eldermoorGuardInput', false)
  guardBaseline(player, data)
  player.setStatusMessage(Text.gold('You are protected while the world loads.'))
})

PlayerEvents.tick(event => {
  const player = event.player
  const data = player.persistentData
  let left = data.getInt('eldermoorGuard')
  if (left <= 0) return
  left--
  if (!data.getBoolean('eldermoorGuardInput')) {
    let dx = player.x - data.getDouble('eldermoorGuardX')
    let dz = player.z - data.getDouble('eldermoorGuardZ')
    let moved = dx * dx + dz * dz
    if (moved > 64) {
      guardBaseline(player, data)          // a teleport, not the player walking
    } else {
      let turned = Math.abs(player.yRot - data.getFloat('eldermoorGuardYaw')) +
                     Math.abs(player.xRot - data.getFloat('eldermoorGuardPitch'))
      if (moved > 0.25 || turned > 2) {
        data.putBoolean('eldermoorGuardInput', true)
        if (left > GUARD_GRACE) left = GUARD_GRACE
      }
    }
  }
  if (Mob != null && left % 20 == 0) {
    let id = player.getId()
    player.level.getEntitiesOfClass(Mob, player.getBoundingBox().inflate(24)).forEach(mob => {
      let target = mob.getTarget()
      if (target != null && target.getId() == id) mob.setTarget(null)
    })
  }
  data.putInt('eldermoorGuard', left)
  if (left == 0) player.setStatusMessage(Text.gray('Login protection has ended.'))
})

EntityEvents.hurt(event => {
  const entity = event.entity
  if (!entity.isPlayer()) return
  if (entity.persistentData.getInt('eldermoorGuard') <= 0) return
  let kind = ''
  try { kind = String(event.source.getMsgId()) } catch (e) {}
  if (kind == 'outOfWorld' || kind == 'genericKill') return   // never trap anyone in the void or block /kill
  event.cancel()
})
