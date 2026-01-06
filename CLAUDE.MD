# Project Roadmap

## Selectable Characters

### Character System Overview
Players can select different mounts before each race. Each mount has distinct stats that create different playstyles and strategic trade-offs. Character diversity encourages players to experiment and find mounts that match their skill level and preferred racing style.

### Current Characters

#### Standard Horse (Default)
**Playstyle:** Balanced all-rounder, good for learning the mechanics

| Stat Category | Stat | Value | Notes |
|---------------|------|-------|-------|
| **Speed** | Base Speed | 40 | Walking speed |
| | Sprint Speed | 80 | Full gallop (2x base) |
| | Acceleration | 1.2 | Lower = more horse-like buildup |
| | Deceleration | 3.0 | How fast you slow down |
| | Empty Stamina Penalty | 0.7x | Speed multiplier when stamina depleted |
| **Stamina** | Max Stamina | 100 | Total stamina pool |
| | Sprint Drain | 15/sec | Drain while sprinting |
| | Jump Cost | 20 | Per jump |
| | Double Jump Cost | 25 | Per double jump |
| | Regen (Low) | 8/sec | When stamina is low |
| | Regen (High) | 45/sec | Fast top-off when high |
| | Regen Delay | 0.5s | Before regen starts |
| | Empty Penalty Duration | 2s | Slowdown after emptying stamina |
| **Turning** | Base Turn Rate | 150°/sec | At low speed |
| | Min Turn Rate | 60°/sec | At max speed |
| | Drift Turn Bonus | 2.0x | Multiplier while drifting |
| | Drift Speed Retain | 92% | Speed kept after drift release |
| | Drift Stamina Drain | 8/sec | Extra drain while drifting |
| **Jumping** | Jump Power | 66 | Base jump height |
| | Double Jump Power | 55 | Second jump (slightly less) |
| | Air Turn Rate | 15°/sec | Normal air turning |
| | Double Jump Turn Rate | 120°/sec | Enhanced air control |
| | Double Jump Turn Duration | 0.8s | How long enhanced turning lasts |
| | Air Control | 0.15 | Influence on air velocity (0-1) |
| **Burst** | Burst Speed Mult | 1.4x | Speed boost during burst |
| | Burst Duration | 1.5s | How long burst lasts |
| | Burst Cost | 25 stamina | To trigger burst |
| | Burst Cooldown | 3.0s | Before burst available again |
| | Burst Tap Window | 0.3s | Double-tap timing |
| | Burst Turn Penalty | 0.4x | Reduced turning during burst |

---

### Planned Characters

*Add new character entries here following the same format. Each character should have:*
- **Name and type** (e.g., "Swift Stallion", "Armored Destrier")
- **Playstyle description** (e.g., "Glass cannon - high speed, low stamina")
- **Stat table** with variations from the Standard Horse

#### Character Design Guidelines
When designing new characters, consider these archetypes:

| Archetype | Speed | Stamina | Turning | Burst | Best For |
|-----------|-------|---------|---------|-------|----------|
| **Speedster** | High | Low | Low | Strong | Straightaways, experienced players |
| **Tank** | Low | High | High | Weak | Technical tracks, consistent runs |
| **Drifter** | Medium | Medium | Very High | Medium | Tracks with tight turns |
| **Sprinter** | Medium | Low | Medium | Very Strong | Short bursts, comeback potential |
| **Endurance** | Low-Medium | Very High | Medium | Weak | Long tracks, stamina management |

---

## MVP vs Reach Goals

### ✅ MVP — Ship With These

These are essential to prevent immediate churn and prove the core loop works.

**Skill Ceiling**
| Feature | Why MVP |
|---------|---------|
| Relative leaderboards ("Players near you") | Without this, new players see impossible times and quit Day 1. Trivial to implement — just filter the query. |
| Percentile display | One number that makes rank 4,847 feel like an achievement ("Top 28%!"). Cheap dopamine. |
| Personal improvement framing | "You're 1.4s faster than your first run" — requires storing first run time, which you're already doing. |
| Milestone times (bronze/silver/gold) | Set 3 static target times per track. New players need achievable goals before they care about leaderboards. |

**Content Treadmill**
| Feature | Why MVP |
|---------|---------|
| Nothing | The 3-day leg structure IS your MVP content solution. One track for 3 days is fine at launch — players are still learning. This becomes a problem at Week 4+, not Week 1. |

**Social Stickiness**
| Feature | Why MVP |
|---------|---------|
| Rival system (auto-assigned) | Low effort, high impact. Pick someone 0.5-2s faster, show their ghost, notify when they beat you. Creates pseudo-relationship with zero social coordination. |
| Friend leaderboard | Roblox already has friends list. Just filter leaderboard to friends. Players will invite friends to compete. |

**MVP Summary:** 6 features, all low-medium effort, directly address "why would I keep playing?"

---

### 🎯 Post-Launch Priority — Build These Next

These deepen engagement once you've validated the core loop.

| Feature | Why Post-Launch | When to Add |
|---------|-----------------|-------------|
| Skill brackets (Bronze/Silver/Gold/Diamond) | Requires tuning bracket thresholds based on real player data. You won't know where to draw lines until you see the distribution. | After 2-3 legs of data |
| Crews/Teams | High-impact social feature but needs UI, crew management, crew leaderboards. Scope creep risk. | Month 2 |
| Head-to-head challenges | Depends on having friends already playing. Crews create the friend density first. | After crews |
| Daily challenges | Nice variety but not critical. Players are still learning the base game. | Month 2 |
| Character rotation incentives | Requires having multiple balanced characters first. | When you have 4+ characters |

---

### 🌟 Reach Goals — Nice to Have

These are polish, not survival. Build them when the game is healthy.

| Feature | Why Reach | Notes |
|---------|-----------|-------|
| Track weather variants (Day 2 rain, etc.) | Cool but requires art/VFX work. Doesn't solve a retention crisis, just adds flavor. | Consider for Season 2 |
| Spectate + react | High effort (live sync or replay system + reaction UI). Fun but not critical. | 3-6 months out |
| Clip sharing | Requires video capture, encoding, export pipeline. Players will screen record anyway. | When you have content creator traction |
| Community spotlight / Ghost of the Day | Requires curation workflow (manual or algorithmic). Adds operational burden. | When you have community managers |
| Parallel casual track | Splits the playerbase. Only matters when you have enough players that splitting is fine. | When DAU > 5k consistently |
| Track evolution within leg (shortcuts open Day 3) | Cool concept but adds level design complexity for every track. | Experiment with one track first |

---

### Visual Summary

```
LAUNCH (MVP)
├── Relative leaderboards
├── Percentile display
├── Personal improvement messaging
├── Milestone times (bronze/silver/gold)
├── Auto-rival system
└── Friend leaderboard

MONTH 2
├── Skill brackets
├── Crews/Teams
└── Daily challenges

MONTH 3+
├── Head-to-head challenges
├── Character rotation incentives
└── Track variants

SOMEDAY
├── Spectate + react
├── Clip sharing
├── Community spotlight
└── Parallel casual track
```

---

### The Hard Truth

Your MVP is really just:
1. The race works
2. Ghosts play back
3. Leaderboard exists
4. Players see progress (not just rank)
5. One person to chase (rival)

Everything else is retention optimization on top of a working core. Get those 5 things right and you can ship.

---

### 🔧 Technical TODOs

**Character Selection System**
- [ ] Add accessory support (hats, etc.) to character costumes
- [ ] Startup character selection UI (before first spawn)
- [ ] Ensure startup UI and in-game character change UI work identically
