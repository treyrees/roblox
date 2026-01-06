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

## Development Roadmap

### MVP — Launch Requirements

These features are essential to prevent immediate churn and prove the core loop works.

#### Core Racing (Must Ship)

- [ ] Race mechanics work (movement, stamina, abilities)
- [ ] Ghost recording during races
- [ ] Ghost playback (8-12 simultaneous ghosts)
- [ ] Leaderboard storage and retrieval
- [ ] 3-day leg structure with scoring (80% best time, 20% consistency, PB bonus)

#### Skill Ceiling Mitigation (Must Ship)

- [ ] **Relative leaderboards** — Default view shows "Players near you" not global top 10
- [ ] **Percentile display** — Show "Top 28%" instead of "Rank 4,847"
- [ ] **Personal improvement framing** — Display "You're 1.4s faster than your first run"
- [ ] **Milestone times** — Bronze/silver/gold target times per track that anyone can achieve

#### Social Foundation (Must Ship)

- [ ] **Auto-rival system** — Assign player someone 0.5-2s faster, show their ghost, notify on overtake
- [ ] **Friend leaderboard** — Filter leaderboard to Roblox friends list

---

### Post-Launch Phase 1 (Month 2)

Build these after validating core loop with real player data.

#### Competitive Depth

- [ ] **Skill brackets** — Bronze/Silver/Gold/Diamond tiers with separate leaderboards
  - Requires: 2-3 legs of data to determine bracket thresholds
- [ ] **Bracket promotion/relegation** — Move between tiers based on performance

#### Social Expansion

- [ ] **Crews/Teams** — Groups of 5-20 players
  - Crew leaderboard (sum of top 5 members' scores)
  - Crew chat
  - Crew cosmetics/identity
- [ ] **Daily challenges** — Side objectives for variety
  - "Beat track without using ability"
  - "Get 3 clean laps in a row"
  - "Find hidden collectible"

---

### Post-Launch Phase 2 (Month 3+)

Deepen engagement systems.

#### Social Features

- [ ] **Head-to-head challenges** — Challenge friends directly, async duel format
- [ ] **Challenge notifications** — Alert when someone beats your challenged time

#### Content Variety

- [ ] **Character rotation incentives** — Bonus for using "featured character of the day"
  - Requires: 4+ balanced characters
- [ ] **Track weather variants** — Day 2 rain/night/fog variants
  - Same layout, different feel
  - Extends track mastery curve

---

### Reach Goals (3-6+ Months)

Polish features for a healthy, growing game.

#### Spectator/Content

- [ ] **Spectate + react** — Watch friends' runs, react with emotes
- [ ] **Clip sharing** — One-button save, auto-generate shareable highlight
- [ ] **Community spotlight** — "Ghost of the Day" featuring mid-tier players

#### Scale Features

- [ ] **Parallel casual track** — Unranked track that rotates daily
  - Only when DAU > 5k (splitting playerbase is okay)
- [ ] **Track evolution within leg** — Shortcuts open on Day 3, obstacles move
  - High level design complexity per track

---

### Backlog

- [ ] Add accessory support (requires character specific config)
- [ ] Character select polish

---

## Implementation Notes

### Ghost Data Structure

```lua
GhostRun = {
    player_id = "string",
    character_id = "string",
    total_time = 0.0,
    recorded_at = timestamp,
    path = {
        { time = 0.0, position = Vector3, rotation = Vector3, anim = "string" },
        -- recorded every ~100ms
    }
}
```

### Rival Assignment Logic

```lua
-- Find rival: someone 0.5-2s faster than player's best time
function assignRival(playerBestTime, leaderboard)
    local candidates = {}
    for _, entry in ipairs(leaderboard) do
        local delta = playerBestTime - entry.time
        if delta >= 0.5 and delta <= 2.0 then
            table.insert(candidates, entry)
        end
    end
    if #candidates > 0 then
        return candidates[math.random(#candidates)]
    end
    return nil
end
```

### Percentile Calculation

```lua
function calculatePercentile(playerRank, totalPlayers)
    return math.floor((1 - (playerRank / totalPlayers)) * 100)
end
-- Rank 100 out of 1000 = Top 90%
-- Rank 500 out of 1000 = Top 50%
```

### Milestone Times (Per Track)

```lua
-- Set during track design, tuned after playtesting
TrackMilestones = {
    ["san_diego_desert"] = {
        bronze = 180.0,  -- 3:00 - almost anyone can hit this
        silver = 150.0,  -- 2:30 - requires learning the track
        gold = 130.0,    -- 2:10 - requires optimization
    }
}
```

---

## Success Metrics

### MVP Launch (Week 1-2)

- Players complete at least one full leg (3 days)
- Day 3 retention > Day 1 (players return to finish leg)
- Players beat at least bronze milestone time

### Month 2

- Crew formation rate > 20% of active players
- Players have active rival relationship
- Skill bracket distribution is roughly even (not everyone in Bronze)

### Month 3+

- DAU stable or growing
- Content creators making clips
- Friend referral rate increasing

---

## Anti-Patterns to Avoid

1. **Don't show global leaderboard by default** — Demoralizing for new players
2. **Don't require all 3 days for rewards** — Punishes people with schedules
3. **Don't let one god run win everything** — Consistency scoring prevents this
4. **Don't split playerbase too early** — Casual track waits until DAU is high
5. **Don't over-scope crews** — Start simple: leaderboard + chat, add features later
