// Magnum Torch guard: Umvuthana and Elokosa pack followers share their leader's fate under a torch.
// Written by tools/torch_guard.py - edit it there, assemble.py overwrites this file.
// Magnum Torch judges mobs by the spawn type Forge records in finalizeSpawn. Raptors and Howlers add their followers
// before those are finalized, so the torch let the followers through even when it cancelled the leader.
const TORCH_GUARD_FOLLOWERS = ['mowziesmobs:umvuthana_follower_raptor', 'mowziesmobs:elokosa_follower_howler']
const TORCH_GUARD_MARK = 'eldermoorTorchChecked'
let torchGuardPending = []

EntityEvents.spawned(event => {
  let e = event.entity
  if (TORCH_GUARD_FOLLOWERS.indexOf(String(e.type)) < 0) return
  let data = e.persistentData
  if (data.getBoolean(TORCH_GUARD_MARK)) return   // checked when it first spawned; this is a chunk load
  data.putBoolean(TORCH_GUARD_MARK, true)
  if (e.spawnType != null) return                  // finalized before joining: Magnum Torch has judged it
  let leader = null
  try { leader = e.getLeaderUUID() } catch (err) { return }
  if (leader == null || !leader.isPresent()) return
  torchGuardPending.push({ follower: e, leader: leader.get() })
})

ServerEvents.tick(event => {
  if (torchGuardPending.length == 0) return
  let batch = torchGuardPending
  torchGuardPending = []
  for (let i = 0; i < batch.length; i++) {
    let p = batch[i]
    // The leader joins right after its followers, in the same tick. If it is not in the world now, it was cancelled.
    let level = p.follower.level
    if (!p.follower.isAddedToWorld() || level == null) continue
    if (level.getEntity(p.leader) == null) p.follower.discard()
  }
})
