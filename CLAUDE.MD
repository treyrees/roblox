# Project Roadmap

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
