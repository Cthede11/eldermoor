// One stamina wheel: Elenai Dodge (Left Alt) spends Paraglider stamina instead of feathers.
// Written by tools/pools.py - edit it there, assemble.py overwrites this file.
const DODGE_STAMINA = 80
const DODGE_RECOVERY = 10
let Stamina = null, Movement = null, Feathers = null, INVINCIBILITY = null
try {
  Stamina = Java.loadClass('tictim.paraglider.api.stamina.Stamina')
  Movement = Java.loadClass('tictim.paraglider.api.movement.Movement')
  Feathers = Java.loadClass('com.elenai.feathers.api.FeathersHelper')
  INVINCIBILITY = Java.loadClass('com.elenai.elenaidodge2.capability.PlayerInvincibilityProvider').PLAYER_INVINCIBILITY
  console.info('[eldermoor] stamina: dodges spend the Paraglider wheel (' + DODGE_STAMINA + ')')
} catch (e) {
  Stamina = null
  console.error('[eldermoor] stamina: dodge bridge disabled: ' + e)
}

PlayerEvents.tick(event => {
  if (Stamina == null) return
  const player = event.player
  const stamina = Stamina.get(player)
  if (stamina == null) return
  const data = player.persistentData
  const cap = player.getCapability(INVINCIBILITY).orElse(null)
  if (cap != null) {
    const now = cap.getInvincibility()
    if (now > data.getInt('eldermoorDodgeFrames')) {
      // a dodge just started
      if (stamina.isDepleted()) {
        cap.setInvincibility(0)
      } else {
        stamina.takeStamina(DODGE_STAMINA, false, true)
        const movement = Movement.get(player)
        if (movement != null && movement.recoveryDelay() < DODGE_RECOVERY) movement.setRecoveryDelay(DODGE_RECOVERY)
      }
    }
    data.putInt('eldermoorDodgeFrames', cap.getInvincibility())
  }
  // feathers only gate the dodge now: full, or empty while the wheel is exhausted
  const want = stamina.isDepleted() ? 0 : Feathers.getMaxFeathers(player)
  if (Feathers.getFeathers(player) != want) Feathers.setFeathers(player, want)
})
