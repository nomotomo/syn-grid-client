# Syn-Grid — Gameplay Depth & Battle Intensity Design Ideas

_A brainstorming doc, not an implementation plan. Pick anything, ignore anything._ 
Companion to `improvements.md` (which covers visual/UX polish); this file focuses on **gameplay systems, difficulty, and combat experience.**

Last updated: Jan 2026 (session #6, design pass only)

---

## The core problem this doc addresses

Right now Syn-Grid loop is:
1. Buy items with gold
2. Place them on a 4×4 grid
3. Auto-battle plays out
4. Repeat

That's a solid MVP loop, but it's flat: **every match feels like the previous match with slightly different numbers**. Players will churn once they've seen 20 fights unless we introduce meaningful **variance**, **stakes**, and **decision depth**.

This doc is organized by the four levers that most consistently lift auto-battler retention:

1. **Grid variety** — the board itself changes match-to-match
2. **Difficulty & progression** — the challenge escalates in *interesting* ways
3. **Item depth** — items become more than "attack + HP"
4. **Battle intensity & post-mortem** — the fight becomes readable, then re-playable

Then a section on **cool ideas** that don't fit above but would give Syn-Grid a distinct identity.

Difficulty tags on every entry: `XS` (<15 min design) · `S` (~1 h) · `M` (~4 h) · `L` (~1 day) · `XL` (>2 days).
Server-need tags: `client-only` (zero server changes) · `server-tiny` (schema tweak) · `server-major` (new endpoints/rules).

---

## 1. Grid variety — the board itself becomes a decision

The 4×4 grid is Syn-Grid's identity. Right now every match uses the same board. That's the biggest single depth win available. **All ideas in this section swap the same server contract (grid IDs → item IDs → attributes) and only change what cells exist / do.**

### 1.1 Grid shape variants  •  M · server-tiny
Ship a small pool of grid shapes selected at match start. Same 16 total cells but the *shape* changes which items can synergise:

- **Classic** — 4×4 flat (current)
- **Diamond** — 4×4 rotated 45°; corners are single tips (item there attacks 3× / turn but has 0 armour)
- **Column** — 2×8 tall column (frontline / backline forced)
- **Cross** — plus-sign shape (only 12 cells, cornerless — no flanking synergies)
- **Ring** — hollow 6×6 outer border (24 cells but center cell is "the eye" — high-risk high-reward)
- **Split** — two 2×4 sub-grids with a 1-cell gap; synergies can't cross the gap unless a "bridge" item is placed

Server just needs one field `grid_shape: string` in the match config; client renders differently, same battle log format.

### 1.2 Terrain cells  •  M · server-tiny
Some cells have baked-in effects. Reveal them before the shop opens so the player buys around them:

- **Fire cell** 🔥 — items placed here deal +20 % damage, but lose 5 HP/tick
- **Frost cell** ❄️ — items placed here attack 30 % slower, but take 40 % less damage
- **Void cell** 🌀 — items here are invisible to opponents until they fire (bonus first-strike damage)
- **Amplifier cell** ⚡ — attacks from this cell chain to a random adjacent enemy for 25 % damage
- **Cursed cell** 💀 — items here lose their category tint (no synergies apply)
- **Sanctum cell** ✨ — items here get +50 % HP but can't move for the round

Client displays a subtle glyph in the empty-cell "+" slot showing the cell type. Terrain distribution changes per match seed.

### 1.3 Locked / hazard cells  •  S · server-tiny
Not every cell is placeable. Adds spatial puzzles:

- **Rubble** — cell is blocked entirely; you have 15 cells this match
- **Blood pact** — cell is placeable but takes 10 % of your remaining LIFE this round
- **Vault** — cell is locked until you spend 25 gold to unlock it (bank an item-slot for the price of a shop refresh)
- **Portal pair** — two cells linked; adjacency for synergy is *through the portal* not through the grid

### 1.4 Expanding grid across rounds  •  L · server-tiny
Start round 1 at 3×3 (9 cells). Round 5 unlocks the 4th row/column (16 cells). Round 10 unlocks a 5×5 (25 cells). Round 15 unlocks a 6×6 (36 cells).

This makes early rounds tight (every placement matters) and late rounds baroque (build a fantasy). It also gives clear power progression the player can *feel*.

### 1.5 Directional / facing mechanics  •  L · server-major
Every item has a facing direction (N/E/S/W). Melee attacks the cell it faces; ranged attacks in a line; arcane in a 3-cell arc.

Massive depth lift but requires a real server rule change. Best introduced as a **"Tactics" mode** — an alternative game type behind a queue selector, not the default.

### 1.6 Static structures  •  M · server-tiny
Non-item cells that generate effects each tick:

- **Anvil** — every 3 ticks, a random adjacent MELEE item gains +5 attack
- **Wellspring** — every 2 ticks, a random adjacent ally heals 8 HP
- **Ballista** — fires a shared shot (all players in match get the shot dmg added to their side)
- **Rift** — random cell rotates all items around it 90° clockwise once per round (comedy chaos)

---

## 2. Difficulty & progression — the challenge escalates *interestingly*

The season mechanic (LIFE + TRIUMPH + leaderboard) is a great foundation. But right now every round feels similar. This section is about **making each round feel different from the last**.

### 2.1 Round modifiers (drafted per match)  •  M · server-tiny
Before each match, the player sees the modifier and can plan around it. Pool of 15-20, one active per round:

- **Fog of war** — you can't see the opponent's grid until combat starts
- **Overtime** — round ends in 40 ticks (half normal); items that survive give bonus gold
- **Iron wall** — every item starts with +25 armour but shop items cost +50 %
- **Glass cannon** — all items 2× damage, 0.5× HP
- **Rich round** — start with 3× normal gold; only 6 shop items ever offered
- **Draft round** — pick 3 items from 6 offered *one at a time*
- **Elite spawn** — opponent's grid has one legendary-tier item you can't beat with attack alone
- **Sudden death** — first item to fall on either side ends the round
- **Reflection** — 25 % of damage taken is dealt back to the attacker
- **Homogeneous** — you can only place items from ONE category (MELEE / RANGED / ARCANE)
- **Time dilation** — attack speed halves for the first 20 ticks then doubles for the remainder

Modifier is announced with a full-viewport banner + a `MODIFIER` chip that stays visible in the HUD row.

### 2.2 Boss encounters every N rounds  •  L · server-major
Every 5th round is a **Boss Fight** — a fixed AI opponent with a signature attack. Named + illustrated so they feel like characters:

- **The Foreman** (round 5) — 8 identical Iron Swords in a diamond formation; kill him by out-tanking the volley
- **Mistress Ember** (round 10) — every 5 ticks, a random cell of yours ignites; requires spread positioning
- **The Warden** (round 15) — his items regenerate 20 HP/tick; you must burst-kill each one below the regen threshold
- **Season boss** (final round) — themed monster with a unique gimmick; killing them gives a permanent cosmetic (aura effect on your player card)

Bosses drop **exotic items** — rare rewards you can't get in the normal shop. Adds anticipation.

### 2.3 League / rank tiers  •  M · server-tiny
The leaderboard is one flat list today. Break it into leagues:

- Bronze → Silver → Gold → Diamond → Master → Grand Master
- Each league has its own leaderboard; matches only pair you with same-league opponents
- End-of-season promotions/demotions across a 3-day settle window
- League borders/colours on the leaderboard rows

Cheap to ship, huge social win (players screenshot their promotion).

### 2.4 Match-affecting terrain that persists  •  L · server-tiny
Between matches, the *season map* has a persistent state:

- Some regions are "hot" (fire terrain bias)
- Winning matches in a region "cools" it
- The player picks which region to queue into
- Regions unlock over the season

Gives strategic macro-planning on top of the tactical matches. Requires a season-wide state table server-side.

### 2.5 Handicap streak-based scaling  •  S · server-tiny
If a player loses 3 in a row, the next match gets a subtle +10 % starting gold bonus (silent — don't tell them). If they win 3 in a row, opponent difficulty pool shifts up one league.

Aim: keep everyone in the "close-fought win-loss" band that maximises engagement.

### 2.6 Round objectives beyond "win"  •  M · server-tiny
Some matches have side quests worth bonus TRIUMPH:

- "Win without any ARCANE items placed"
- "Take fewer than 20 total damage"
- "Get 3 crits in a single round"
- "Have every item survive"

Show them as chips in the pre-round briefing; check server-side at match end.

---

## 3. Item depth — items become more than stats

Right now items feel like "ATK / DEF / SPD numbers". This section adds *personality and interactions*.

### 3.1 Item passives (unique per template)  •  L · server-major
Every item has a passive that fires on a condition:

- **Iron Sword** — "Every 4th attack crits."
- **Ember Wand** — "First attack sets target on fire (5 dmg/tick for 3 ticks)."
- **Frost Orb** — "On hit, target's next attack is 40 % slower."
- **Tower Shield** — "Adjacent allies take 15 % less damage."
- **Healing Draught** — "When any ally drops below 30 % HP, restores 20 HP one time per round."

Server needs a passive-effects table + tick engine hooks. Client displays passives as bullet-list text in the item tooltip.

### 3.2 Item merges & upgrades  •  M · server-tiny
3 of the same item on your bench/grid at end-of-round auto-merge into a tier-up version:

- 3× Iron Sword (I) → 1× Iron Sword (II), +50 % all stats
- 3× Iron Sword (II) → 1× Iron Sword (III) with an added passive
- 3× (III) → 1× MYTHIC variant with a unique-per-item ability

Standard TFT/auto-battler pattern; deep, satisfying, easy to add.

### 3.3 Item slots / enchantments  •  L · server-major
Items have 0–3 enchantment slots. Gems drop from boss fights and can be socketed:

- **Bloodstone** — item gains 10 % lifesteal
- **Emberchip** — item deals +5 fire damage per hit
- **Void shard** — item's first attack of every round is guaranteed crit

Gives players a way to differentiate identical items and creates a **loot chase** feed.

### 3.4 Item mastery tracks  •  M · client-only (cosmetic)
Every unique item you own tracks lifetime uses. Milestones:

- 10 uses → item name gains a bronze underline
- 50 uses → silver
- 100 uses → gold + a subtle particle glow on the card
- 250 uses → PRISMATIC — item card has an animated foil shader

Zero balance impact, huge cosmetic hook. Motivates players to build with "their" items even when new items drop.

### 3.5 Class / role synergies  •  L · server-major
Each item has 1-2 tags beyond category:

- **Iron Sword** — MELEE, "Warrior", "Iron"
- **War Hammer** — MELEE, "Warrior", "Iron"
- **Ember Wand** — ARCANE, "Mage", "Fire"

Tag-count triggers a set bonus:

- 2× Warrior → +10 attack to all Warriors
- 3× Warrior → +10 attack, +50 HP to all Warriors  
- 2× Iron → adjacent Iron items chain their crit chance
- 3× Fire → all items deal fire DoT on hit

Adds "collect the set" motivation to shop purchases.

### 3.6 Consumables + one-shot cards  •  M · server-tiny
Shop occasionally offers **consumables** (used the moment you buy them, gone forever):

- **Reroll Amulet** — refresh the shop for free
- **Steal Kit** — take one item slot from opponent (visible in their grid), place it on yours
- **Mercenary Ticket** — hire a random tier-2 item, only for this round
- **Vision Draught** — see opponent's grid this round

Injects randomness and "big moment" plays.

---

## 4. Battle intensity & post-mortem — the fight becomes readable

This is the section that answers "**why did I win/lose?**" Currently the fight ends and the player is dumped to the round-end scene with no explanation. Below is the plan to fix that.

### 4.1 Live battle telemetry overlays  •  M · client-only

**A. Damage-dealt "meter" per item during combat**
Under each item card during the fight, a tiny bar fills right-to-left showing that item's damage contribution to the round. At end-of-fight it stays visible — the MVP item is instantly obvious.

**B. Synergy activation banners**
When a synergy triggers mid-fight, a small "SYNERGY: Iron Set (2)" chip slides in from the side for 2 s and joins a stacked list on the right edge. Players see *why* their build is working.

**C. Damage type icons on floats**
The floating damage number gets a tiny prefix icon: 🗡 physical, ✨ magical, 🔥 fire DoT, 🛡 shield-absorbed, ⚡ crit. Reads at a glance.

**D. Threat meter**
Small pill at the top of the enemy grid ranks their top-3 damage-dealers. If you know which item to counter, you can predict better next round.

**E. HP bar segments**
Split the HP bar into visual chunks so damage taken is countable ("I took 3 chunks that round"). Same server data, better readability.

### 4.2 Post-match "Battle Report" screen  •  L · client-only + server-tiny

New scene between combat and round-end. Ships as a **swipe-through 3-page report**:

**Page 1 — VERDICT**
- Big banner: "VICTORY" or "DEFEAT" or "OVERTIME"
- One-line reason: "Your Iron Set synergy carried the round" / "You had no answer to their crit chain"
- Match duration, total damage exchanged

**Page 2 — DAMAGE BREAKDOWN**
- Pie chart of your damage by item (highlights the MVP)
- Bar chart of damage taken by each of your items (highlights the weak link)
- Synergy contributions ranked
- Crit rate + tick-by-tick DPS graph

**Page 3 — POST-MORTEM ADVICE**
Uses the combat log to compute:
- "Your Ember Wand only fired 3 times — placing it in a Void cell would have doubled its output"
- "You lost your Leather Armor at tick 22 — swapping it to the back row survives 12 ticks longer"
- "Two of your items had no synergy — consider replacing your Tower Shield with another Iron piece"

Advice is generated from a small local rule engine (no ML needed for MVP). The server just tags events with metadata; client formats the sentences.

### 4.3 Timeline replay scrubber  •  L · client-only
Post-match, let the player scrub through the fight tick by tick. Bottom slider shows HP bars over time; tapping any moment jumps the replay there. Highlights the "turning point tick" (biggest HP swing) in gold.

Retention lever: players screenshot and share clutch moments.

### 4.4 Rematch button with a tweak  •  M · server-tiny
Round-end has a "REMATCH WITH BUFF" button. Cost: 20 gold. Retries the same match with a small buff (e.g., "+10 % attack this fight only"). Adds a safety-valve for tilted losses. Bounded so it can't be abused (max 1 rematch per round).

### 4.5 Grid heatmap  •  M · client-only
Overlay on the post-match grid showing:
- Damage-dealt heat (green = high, red = low)
- Damage-taken heat (blue overlay)
- Cells that never fired flash red — instant "your positioning wasted this slot" signal

### 4.6 Highlight reel  •  L · client-only
5-second auto-generated clip of the best moment (biggest crit, closest survive, best synergy chain). Uses the existing screen shake/damage-float/hitmark stack. Bookended by a "MOMENT OF THE FIGHT" title card.

### 4.7 Trigger-based hints during battle  •  S · client-only
If the player is losing badly (>60 % HP down at tick 15), a subtle amber pill appears: "TIP: Losing hard — check Battle Report for placement suggestions". Prevents the "why am I losing, no idea" spiral.

---

## 5. Hints system — meet the player where they are

A dedicated hints system pays dividends in retention because it lets casual players discover depth at their own pace.

### 5.1 Progressive tutorial (only for new players)  •  M · client-only
First 3 matches show tinted overlays pointing at each system as it's used for the first time:

- Match 1: HUD pills → shop → grid → START
- Match 2: synergies → merges → shop-refresh cost
- Match 3: modifiers → boss preview → battle report

Skippable at any point. Never repeats.

### 5.2 "?" chip on every item card  •  S · client-only
Long-press an item card to open a themed popover: stats, passive, synergy tags, best-slot suggestions, kill count with that item.

### 5.3 Suggested-loadout scroll  •  M · server-tiny
On the shop screen, a "SUGGESTED FOR THIS MATCH" carousel shows 3 curated builds based on the round's modifier + opponent's known preferences. Tap to preview.

### 5.4 Adaptive coaching  •  L · server-tiny
Server tracks lose streaks. After 3 straight losses, an in-game coach character (illustrated as an arcane owl or similar) appears at the main menu:

> "Struggling? Your last three matches lost to crit chains. Try adding a `Frost Orb` — it slows attackers by 30 %."

Feels warm, not condescending. Turn off in settings.

### 5.5 Contextual tooltips triggered by *inaction*  •  S · client-only
If the player hovers on an empty cell for 3+ seconds during grid-prep, show a "Best fit for this cell:" mini card suggesting the strongest bench item to place there.

---

## 6. Cool ideas — Syn-Grid's distinct identity

These are the "what makes this game *this game* and not another auto-battler" hooks. Ordered by wow-factor.

### 6.1 The Grimoire — item lineage & lore  •  L · client-only
Every item has a 3-line lore paragraph that unlocks progressively:

- First kill with the item unlocks line 1 ("Forged in the ember pits of Kaethis…")
- 25 kills unlocks line 2 (the item's tragic backstory)
- 100 kills unlocks line 3 (a hidden secret — maybe a stat buff or a cosmetic aura)

Codex screen (already in `improvements.md` §3.1) hosts all unlocked lore. Neon Grimoire aesthetic delivered on with real *content*.

### 6.2 Season storyline / chapter cutscenes  •  XL · client-only
Every season has a thin narrative. Round 5 unlocks Chapter 1: a 3-slide vignette (still images + pixel-font captions) that ties into the boss fight. Chapter 5 concludes the arc.

Cheap to produce (no voice acting, just still art), massive perceived-value bump. Turns a session into a *story you're inside of*.

### 6.3 Draft mode / snake draft between friends  •  L · server-major
A separate queue: 2 players alternate picking from a shared pool of 12 items until each has 8. Then they build their grid privately and fight. High-skill mode; competitive scene fodder.

### 6.4 Roguelike season  •  L · server-major
Alternate season type where LIFE = 1 (permadeath). Every 3rd round offers a **choice: 3 items OR 1 rare item OR 25 gold**. Death resets your run but banks a fraction of TRIUMPH.

Loved by roguelike-fans, gives the game a whole different rhythm.

### 6.5 Coop grid — share a board with a friend  •  XL · server-major
Two players share a 6×4 grid; each controls one half. Synergies can cross the seam. Voice/emote in-match. Great social hook.

### 6.6 Item combining crafting  •  L · server-major
2 items on your bench can be **combined** at the end of a round for a fixed gold cost. Recipes are hidden until discovered:

- Iron Sword + Ember Wand → **Flamebrand** (MELEE, ARCANE tags, fire DoT)
- Frost Orb + Longbow → **Icebow** (RANGED, slows target)
- Healing Draught + Leather Armor → **Blessed Mail** (+regen)

The "recipes discovered" count becomes a bragging stat.

### 6.7 Random daily event  •  M · server-tiny
Every day at UTC-noon, a global event flips a switch for 24 h:

- "Fire Day" — all ARCANE items deal +20 % damage
- "Iron Day" — all MELEE items gain +20 armour
- "Coin Rush" — 2× gold from every round

Announced with an in-app notification. Players return to check.

### 6.8 Player callsign titles  •  S · client-only
Unlockable prefixes/suffixes that display before/after the callsign on the leaderboard:

- **The Undefeated** (win 10 in a row)
- **Grid Master** (fill all 16 cells with tier-III items in one match)
- **Fire Sage** (own 20 unique ARCANE items lifetime)
- **Ironblood** (defeat The Warden without losing an item)

Only 3 can be equipped at once. Peacocking is a proven retention lever.

### 6.9 Item skins / transmog  •  M · client-only + optional server
Change the *appearance* of an item without changing stats:

- Iron Sword → Obsidian Sword skin (unlocked from Boss 1)
- Ember Wand → Ice Wand skin (unlocked from a Frost Day event)
- Tower Shield → Warden's Bulwark skin (unlocked from beating The Warden)

Sprite work already exists as a base; skins are just recolours + minor pixel tweaks. Could later monetise as cosmetic-only DLC.

### 6.10 Guild banners on team floors  •  L · server-major
When guilds exist, the friendly arcane-circle floor renders the guild sigil in the centre of the disc. Free at-a-glance social identity every match. Uses the existing `arcane_circle_floor.gdshader` with an extra sampler for the sigil.

### 6.11 Weather system between matches  •  M · server-tiny
The season map has a weather layer that shifts every ~30 min:

- **Storm** — all matches this window have a chance of "chain lightning" event (random cell hit for burst dmg)
- **Frost** — attack speeds slowed 10 %; all games take longer, meaty tanks shine
- **Voidfall** — random cell every round becomes a Void cell

Simple state variable server-side; huge feel-shift per session.

### 6.12 Reactive main menu  •  S · client-only
The main menu's rune-field backdrop reacts to the player's recent performance:

- Win streak → more purple pings, warmer glow
- Loss streak → cooler tones, sparser pings
- Just after a boss kill → a fading boss silhouette drifts through the field once

Zero mechanical impact, huge "the game knows me" vibe.

### 6.13 Live match ticker on main menu  •  M · client-only
Bottom of main menu: a marquee showing recent notable events across the whole player base — "PlayerX just clutched a Boss 3 kill", "The Undefeated title unlocked by PlayerY (first ever)". FOMO in a good way.

### 6.14 Streamer mode  •  S · client-only
Toggle in settings that hides opponents' callsigns (replaces with generated placeholder like "PLAYER-4A7C"). Anticipates the streaming crowd; costs nothing.

### 6.15 Prestige season loop  •  L · server-major
End-of-season, if you're in Diamond+ league, opt into "Prestige" — reset all triumph in exchange for a permanent tiny buff (+2 % starting gold, +1 max LIFE, unique animated title, etc.). Extends late-game.

---

## 7. My 3 recommended "next-quarter" bundles

If you want a curated batch of the above with the best gameplay-lift per hour, here are my picks:

### 🎯 Bundle A — "Every match feels different"  •  ~3 days
Ships items **1.1** (grid shape variants), **1.2** (terrain cells), **2.1** (round modifiers). One config file drives all three. Immediately transforms the "every match is the same" complaint into "I never know what I'll get". Requires only a `match_config` JSON field on the server.

### 🎯 Bundle B — "I understand my losses"  •  ~5 days
Ships items **4.2** (Battle Report screen — 3 pages), **4.5** (grid heatmap), **5.4** (adaptive coaching). Solves the biggest player-comprehension gap in the entire game. Server work is minimal (event tags); most cost is the report layout + rule engine.

### 🎯 Bundle C — "Depth without complexity"  •  ~1 week
Ships **3.1** (item passives), **3.2** (merges), **3.5** (class synergies). This is the classic auto-battler depth stack. Server rules engine grows meaningfully but rewards are proportional — this is the single biggest lift for competitive longevity.

---

## 8. Anti-goals — things NOT to do

To keep this doc honest, ideas I've considered and **rejected**:

- **Turn-based mode** — kills the auto-battler identity; every attempt in the genre has failed
- **Pay-to-win items** — sinks retention faster than any other single mistake in the genre
- **Ranked seasons shorter than 2 weeks** — churn increases; players don't feel their climb
- **Chat during matches** — moderation cost >> engagement gain for a 2-player auto-battler; keep it to emotes
- **Randomly-generated items with stats** — breaks the "known item" mastery loop; only *fixed items with unlockable skins/enchants* preserve the mastery hook
- **Timed daily energy** — Syn-Grid's session length (~5 min per round) is already self-limiting; energy adds nothing
- **Ads mid-round** — kill it with fire
- **Cross-play trades / open economy** — inevitable RMT (real-money-trading) grey market, huge support cost

---

## 9. If I had one week to lift retention *right now*

I'd ship in this order, one per day:

1. **Day 1** — 2.1 Round modifiers (biggest immediate variety lift, one server field)
2. **Day 2** — 3.2 Item merges (satisfying, everyone-knows-what-to-do-with-it)
3. **Day 3** — 4.1 D/E Threat meter + HP bar segments (fixes readability)
4. **Day 4** — 4.2 Battle Report screen page 1 only (the verdict + one-line reason)
5. **Day 5** — 1.1 Grid shape variants (2 shapes to start: Classic + Diamond)
6. **Day 6** — 6.8 Player callsign titles (3-5 titles unlocked by existing achievements)
7. **Day 7** — 5.1 Progressive tutorial + 5.2 "?" long-press item info

That's a full week of daily patches, each visible to players. Everything else in this doc is Phase 2+.

---

## 10. Architect pass (Jul 2026) - refinements and new ideas

_Added by Claude Code (Lead Architect) after reviewing this doc against the server's Gameplay Depth epic (sync-grid #26, children G1-G7) and the client backlog._

### 10.1 Where this doc overlaps the server epic (do not double-build)

Several ideas above are already specced server-side with dependency ordering.
Build them through the epic, not as fresh designs:

- §3.1 item passives → covered by **G1** (potions/relics/stamina) + **G2** (status effects, elemental types).
- §3.5 class/role synergies → covered by **G5** (synergy evolution: buff-neighbor, defensive, scaling, set bonuses).
- §2.1 round modifiers and §2.2 bosses → covered by **G7** (mutators + PvE boss ladder).
- §1.2 terrain cells and §1.3 locked cells → **G6** already introduces blocked/buff special cells as hero starting conditions; terrain should extend that same `CellEffect` foundation rather than invent a parallel system.
- §3.3 enchantment sockets → fold into **G4** (rarity + catalog) as a later phase; do not build a separate gem system first.

### 10.2 Refinements to existing ideas

- **Merge the two hint designs**: improvements.md §2.2 (best-slot long-press) and this doc's §5.5 (inaction tooltips) are the same "placement suggester" - build one client-side suggestion engine with two triggers.
- **Fold §6.7 daily events and §6.11 weather into one system**: both are "a timed global modifier row in the DB that the match-maker reads"; one table, one endpoint, two presentation skins.
- **Battle report advice (§4.2 page 3) and adaptive coaching (§5.4) share one rule engine**: a small client-side library that pattern-matches the combat log; the coach is just a different render target.
- **§2.6 round objectives should reuse G7's mutator announcement UI** (full-viewport banner + HUD chip) so the pre-round briefing has one consistent surface.
- **§3.2 item merges is the single highest-value non-epic item in this doc**: it is a known-good genre pattern, server-tiny, and every player instantly understands it. Promoted to P1.

### 10.3 New ideas (this pass)

#### A. Weekly Gauntlet - fixed-seed event mode  •  M · server-tiny
Combat is already deterministic with injected `rng.Source`.
Once a week, publish a fixed seed: every player gets identical shop rolls, identical modifier schedule, identical boss.
Separate 7-day leaderboard; end-of-week cosmetic reward for top percentile.
This is the cheapest possible "fair competitive event" because the determinism work is already done.

#### B. Nemesis rival ghosts  •  S · server-tiny
Track the async opponent who most recently eliminated you.
When matchmaking pairs you against a newer ghost of that same player, show a "REVENGE MATCH" chip; winning banks bonus triumph.
Personalizes async PvP - the opponent stops being a random name.

#### C. Gold interest / banking  •  S · server-tiny
At round end, +1 bonus gold per 10 gold banked, capped at +5.
Creates the classic spend-now-vs-compound decision every auto-battler economy needs.
Server-side only; client shows an "INTEREST +N" line in the round-end gold award.

#### D. Shop pity timer  •  S · server-tiny
Bad-luck protection: after N consecutive shop rolls with zero synergy-relevant items for the player's current grid, guarantee one.
Silent - never surfaced in UI.
Reduces tilt-quits without touching perceived fairness.

#### E. Shareable replay codes  •  M · server-tiny + client M
The combat log is already a complete deterministic record.
Expose `GET /v1/replays/{match_id}`, give the round-end scene a "COPY REPLAY CODE" button, and let anyone paste a code to watch the fight in CombatReplayScene.
Zero new simulation work; pure serialization + one client entry point.

#### F. Practice Forge - sandbox vs your own ghost  •  M · client + server-tiny
Re-fight your previous round with a rearranged grid, no rewards, unlimited retries.
Teaches placement cause-and-effect better than any tutorial text.
Needs one endpoint: "run combat against my own round-N snapshot".

#### G. Dynamic BGM intensity layers  •  M · client-only
Author the combat track as stems (base / percussion / lead).
Fade stems in as either team drops below 50% then 25% total HP.
Vertical remixing is the single biggest audio-feel win after the SFX matrix.

#### H. Grid scars - cosmetic battle memory  •  S · client-only
Cells where one of your items died this session show a faint crack/scorch decal for the rest of the session.
Zero mechanics; the board quietly tells your story.

#### I. One-thumb reachability mode  •  S · client-only
Settings toggle that keeps all primary action buttons inside the bottom 60% of the portrait viewport.
Cheap and meaningful for one-handed commute play.

### 10.4 Issue map (created Jul 2026)

Server (`nomotomo/sync-grid`) - epic **#57 "Match Variety and Meta Systems"** (children M1-M10 = #47-#56) plus the existing gameplay-depth epic #26:
item merges (#47), round objectives (#48), combat-log metadata for the battle report (#49), board variety on the G6 cell foundation (#50), leagues (#51), weekly gauntlet (#52), economy depth (#53), nemesis ghosts (#54), shareable replays (#55), timed global events (#56).

Client (`nomotomo/sync-grid-client`) - epic **#42 "Client Experience Roadmap"** (children E1-E14 = #28-#41):
combat feel batch (#28), combat readability overlays (#29), audio completion (#30), battle report scene + heatmap (#31), grid-prep clarity (#32), onboarding + hints (#33), meta screens (#34), round-end ceremony (#35), accessibility (#36), tech debt (#37), BGM layers (#38), leaderboard polish (#39), retention pack (#40), polish grab-bag (#41).

Every issue carries a `P0`-`P3` label and an explicit order; the two epics hold the cross-repo sequencing.

---

_End of design brainstorm. Pick anything, push back on anything, add anything._
