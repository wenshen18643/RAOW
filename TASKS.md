# Roblox Age of War Modernized - Development Tasks

This document outlines the development phases, goals, and specific tasks required to build the modernized Roblox *Age of War* experience.

---

## 🛠️ Phase 1: Core Combat & Animation Framework (Task 1)
**Goal:** Ensure high-fidelity, satisfying combat visuals instead of generic Roblox placeholders.

- [ ] **Dynamic Hitbox & Weapon Component System**
  - Implement a server-validated system where weapons are physical, non-collidable mesh models welded to the character's right hand.
  - Use Raycast Hitbox techniques (rather than simple `.Touched` events) to track the weapon's physical arc during an animation, ensuring accurate damage detection.
- [ ] **Contextual Animation Controller**
  - Create an animation state machine for both players (FPS/TPS rigs) and AI units.
  - Map distinct, high-impact combat animations (e.g., downward overhead swing for clubs/swords, recoil/muzzle flash for firearms) that physically drive the weapon mesh through the strike zone.
- [ ] **VFX Overhaul (No Placeholders)**
  - Design age-specific particle systems (e.g., stone sparks for the Stone Age, blood splatters, sci-fi plasma burns) that emit exactly at the point of weapon-to-unit impact.
  - Strictly prohibit generic white blocks or default Roblox selection boxes for visual feedback.

---

## 🏰 Phase 2: Complete PvE Structure & Strategy Mechanics (Tasks 2 & 4)
**Goal:** Capture the exact strategic loop of the original *Age of War* while modernizing it.

- [ ] **The Base & Economy System**
  - Implement an asynchronous resource engine managing Gold (earned via kills/time) and XP (earned via combat).
  - Create the Age Advancement Loop across 5 distinct eras:
    $$\text{Stone Age} \rightarrow \text{Castle Age} \rightarrow \text{Renaissance} \rightarrow \text{Modern} \rightarrow \text{Space Age}$$
  - Advancing unlocks upgraded bases, new units, and distinct weapon armaments.
- [ ] **Lane & Spawning Orchestration**
  - Design a strict single-lane or multi-lane navigation grid.
  - Build an optimized AI unit spawner using **Object Pooling** (recycling unit models rather than destroying/instantiating them to keep server performance smooth).
- [ ] **The "Special Ability" System**
  - Replicate the iconic *Age of War* ultimate abilities (e.g., Stone Age meteor shower, Modern Age airstrike) with proper cooldown timers, area-of-effect (AoE) damage calculations, and screen-shake visual effects.
- [ ] **Turret Slots**
  - Implement building spots on the player/enemy bases where defensive AI turrets can be purchased, upgraded, or sold dynamically.

---

## 🎛️ Phase 3: AI Difficulty Scaling & Game Modes (Task 3)
**Goal:** Create a scaling PvE system that feels challenging rather than artificially "bullet-spongy."

- [ ] **Dynamic Difficulty Config Matrix**
  - Build a global configuration module specifying distinct multipliers for Normal, Harder, and Impossible modes.
  - Modify enemy unit **HP** and **Damage** using the difficulty scaling factors:
    - **Normal:** $1.0\times$ multiplier
    - **Harder:** $1.3\times$ multiplier
    - **Impossible:** $2.0\times$ multiplier
- [ ] **Smart AI Decision Trees**
  - Scale the AI's behavior dynamically based on the selected difficulty:
    - **Normal:** Standard spawn rates, random unit composition, delayed usage of special abilities.
    - **Harder:** Moderately aggressive spawn scaling, reactive unit spawning, and timed usage of special abilities.
    - **Impossible:** Perfect economic scaling, aggressive counter-spawning (e.g., spawning anti-infantry units immediately when it detects the player spawning infantry), rapid turret upgrades, and highly strategic special ability deployment.

### Difficulty Settings Matrix

| Difficulty | HP & Damage Modifier | AI Behavior |
| :--- | :--- | :--- |
| **Normal** | $1.0\times$ | Standard spawn rate, delayed special abilities |
| **Harder** | $1.3\times$ | Moderately aggressive spawn scaling, reactive spawning |
| **Impossible** | $2.0\times$ | Perfect economic scaling, frame-perfect counter-spawns & turret upgrades |

---

## 🚀 Phase 4: The "More Fun" Modernization Pass (Task 4)
**Goal:** Elevate the classic game loop with engaging, modern mechanics.

- [ ] **The Commander FPS/PvP Override**
  - Allow the player to physically control their active general in first-person, actively fighting in the trenches alongside their AI troops.
- [ ] **Unit Synergies & Status Effects**
  - Add strategic depth: Modern units cause "Bleed" damage, futuristic plasma weapons melt armor shields, and prehistoric fire clubs deal damage over time (DoT).
- [ ] **Progression & Monetization Hooks**
  - Implement a persistent player profile system storing unlocked cosmetic weapon wraps, unique base skins, and win/loss records.

---

## 📊 Reference Game Balance Data

### Unit Cost Effectiveness

| Name | Cost | DPT (Melee) | DPT (Ranged) | DPT/Cost (Melee, $\times 10^{-3}$) | DPT/Cost (Ranged, $\times 10^{-3}$) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Club Man** | 15 | 0.40 | — | 26.67 | — |
| **Slingshot Man** | 25 | 0.25 | 0.21 | 10.00 | 8.40 |
| **Dino Rider** | 100 | 0.89 | — | 8.88 | — |
| **Sword Man** | — | — | — | — | — |
| **Archer** | — | — | — | — | — |
| **Knight** | — | — | — | — | — |
| **Dueler** | — | — | — | — | — |
| **Musketeer** | — | — | — | — | — |
| **Cannoneer** | — | — | — | — | — |
| **Melee Infantry** | — | — | — | — | — |
| **Infantry** | — | — | — | — | — |
| **Tank** | — | — | — | — | — |
| **God's Blade Soldier** | — | — | — | — | — |
| **Blaster** | — | — | — | — | — |
| **War Machine** | — | — | — | — | — |
| **Super Soldier** | — | — | — | — | — |

### Turrets Stats & Cost Effectiveness

| Name | Cost | DPT | DPT/Cost ($\times 10^{-3}$) | Range |
| :--- | :--- | :--- | :--- | :--- |
| **Rock slingshot** | 100 | 0.40 | 4.00 | 350 |
| **Egg automatic** | 200 | 0.45 | 2.25 | 300 |
| **Primitive Catapult** | 500 | 0.36 | 0.72 | 400 |
| **Catapult** | 500 | 0.57 | 1.14 | 400 |
| **Fire Catapult** | 750 | 0.71 | 0.95 | 400 |
| **Oil** | 1000 | 0.04 | 0.04 | 300 |
| **Small Cannon** | 1500 | 0.43 | 0.29 | 500 |
| **Large Cannon** | 3000 | 1.00 | 0.33 | 500 |
| **Explosives Cannon** | 6000 | 1.43 | 2.38 | 500 |
| **Single Turret** | 7000 | 1.75 | 0.25 | 500 |
| **Rocket Turret** | 9000 | 2.00 | 0.22 | 500 |
| **Double Turret** | 14000 | 2.73 | 0.195 | 500 |
| **Titanium Shooter** | 24000 | 2.50 | 0.10 | 400 |
| **Lazer Cannon** | 40000 | 4.00 | 0.10 | 500 |
| **Ion Ray** | 100000 | 6.00 | 0.06 | 500 |

### Costs of Units in Queue (Gold)

| Unit | 1 | 2 | 3 | 4 | 5 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Club Man** | 15 | 30 | 45 | 60 | 75 |
| **Slingshot Man** | 25 | 50 | 75 | 100 | 125 |
| **Dino Rider** | 100 | 200 | 300 | 400 | 500 |
| **Sword Man** | 50 | 100 | 150 | 200 | 250 |
| **Archer** | 75 | 150 | 225 | 300 | 375 |
| **Knight** | 500 | 1,000 | 1,500 | 2,000 | 2,500 |
| **Dueler** | 200 | 400 | 600 | 800 | 1,000 |
| **Musketeer** | 400 | 800 | 1,200 | 1,600 | 2,000 |
| **Cannoneer** | 1,000 | 2,000 | 3,000 | 4,000 | 5,000 |
| **Melee Infantry** | 1,500 | 3,000 | 4,500 | 6,000 | 7,500 |
| **Infantry** | 2,000 | 4,000 | 6,000 | 8,000 | 10,000 |
| **Tank** | 7,000 | 14,000 | 21,000 | 28,000 | 35,000 |
| **God's Blade Soldier** | 5,000 | 10,000 | 15,000 | 20,000 | 25,000 |
| **Blaster** | 6,000 | 12,000 | 18,000 | 24,000 | 30,000 |
| **War Machine** | 20,000 | 40,000 | 60,000 | 80,000 | 100,000 |
| **Super Soldier** | 150,000 | 300,000 | 450,000 | 600,000 | 750,000 |

---

> [!NOTE]
> Write the clean, modular Luau code for Phase X, Bullet Point Y. Use Object-Oriented Programming (OOP) principles, ensure it is secure against exploits on the server side, and comment the script thoroughly. 