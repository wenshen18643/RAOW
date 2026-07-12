# Age of War: Complete Guide & Database

Welcome to the definitive database and archive of the classic tactical warfare strategy game franchise, **Age of War**. Originally created by Louissi in late 2007 with the legendary soundtrack *Glorious Morning* by Waterflame, Age of War remains a timeless Flash classic. 

This document archives game mechanics, units, turrets, specials, and strategies across **Age of War 1**, **Age of War 2**, and **Army of Ages**.

---

## 🎮 Game Overview & Core Mechanics

The core goal of Age of War is simple: **Defend your base and destroy the enemy base.**
You achieve this by:
1. Spawning units to march across the battlefield and attack the enemy.
2. Building automated defensive turrets on your base tower.
3. Unleashing powerful, map-clearing Special Attacks (God's Spells).
4. Gathering XP from combat to evolve into new, advanced historical and future eras.

### 💰 Gold Generation Rates
*   **Passive Gold Income**: 
    *   **Age of War 1**: There is **no passive gold income**. Gold is earned strictly by defeating enemy units or selling active turrets.
    *   **Age of War 2**: Gold is generated passively over time and can be boosted via tower upgrades (e.g. upgrades like *Taxation* or *Golden Castle*), but the wiki does not specify the baseline gold generation rate per second or minute.
*   **Combat Gold (Age of War 1)**: Killing an enemy unit rewards you with **130% of the unit's base training cost** (represented as the Base Cost + a 30% bounty rounded to the nearest gold).
    *   *Clubman* (Cost 15) ➔ Gained on Kill: `15 + 5 = 20` Gold
    *   *Slingshot Man* (Cost 25) ➔ Gained on Kill: `25 + 7 = 32` Gold
    *   *Dino Rider* (Cost 100) ➔ Gained on Kill: `100 + 30 = 130` Gold
    *   *Knight* (Cost 500) ➔ Gained on Kill: `500 + 150 = 650` Gold
    *   *Super Soldier* (Cost 150,000) ➔ Gained on Kill: `150,000 + 45,000 = 195,000` Gold

### 📈 Unit XP Rewards
Experience points scale predictably off the gold cost of units:
*   **XP Gained From Killing an Enemy**: When you destroy an enemy unit, the XP you receive is exactly **double (2x) the unit's Gold purchase cost** (with the game rounding the Clubman's reward from 30 up to 40).
*   **XP Gained From Your Own Unit Dying ("Pity" XP)**: When one of your own deployed units dies, you receive a passive pity payout equal to exactly **half (0.5x) of that unit's Gold cost** (or 25% of what a kill is worth).
*   **XP Gained From Special Attacks**: The Special Attack button does not grant a flat XP reward upon activation. Instead, you receive the full individual Kill XP for each enemy unit wiped out by the attack. E.g. a Meteor Shower that sweeps and kills three 15-Gold Clubmen will reward you with `3 * 40 = 120 XP` total.

#### 📊 Complete Age-by-Age XP Breakdown (Age of War 1 / The Wars Variants)
| Age & Unit | Gold Cost | Kill XP | Death XP |
| :--- | :---: | :---: | :---: |
| **Stone Age (Age 1)** | | | |
| ➔ Clubman | 15 Gold | 40 XP | 10 XP |
| ➔ Slingshot Man | 25 Gold | 50 XP | 12 XP |
| ➔ Dino Rider / Mammoth Rider | 100 Gold | 200 XP | 50 XP |
| **Medieval Age (Age 2)** | | | |
| ➔ Sword Man | 50 Gold | 100 XP | 25 XP |
| ➔ Archer | 75 Gold | 150 XP | 37 XP |
| ➔ Knight | 500 Gold | 1,000 XP | 250 XP |
| **Renaissance Age (Age 3)** | | | |
| ➔ Dueler | 200 Gold | 400 XP | 100 XP |
| ➔ Musketeer | 400 Gold | 800 XP | 200 XP |
| ➔ Cannoneer | 1,000 Gold | 2,000 XP | 500 XP |
| **Modern Age (Age 4)** | | | |
| ➔ Melee Infantry | 1,500 Gold | 3,000 XP | 750 XP |
| ➔ Infantry | 2,000 Gold | 4,000 XP | 1,000 XP |
| ➔ Tank | 7,000 Gold | 14,000 XP | 3,500 XP |
| **Future Age (Age 5)** | | | |
| ➔ Blaster Trooper | 5,000 Gold | 10,000 XP | 2,500 XP |
| ➔ Robotic Soldier | 6,000 Gold | 12,000 XP | 3,000 XP |
| ➔ Assault Mech / Super Soldier | 20,000 Gold | 40,000 XP | 10,000 XP |

### ⚙️ Difficulty Modifiers (Age of War 1)
Enemy units gain increased stats depending on the difficulty mode:
*   **Normal Mode**: Standard stats (1.0x HP & Damage).
*   **Harder Mode**: Enemy HP and Damage multiplied by **1.3x**.
*   **Impossible Mode**: Enemy HP and Damage multiplied by **2.0x**.

---

## ⚔️ Age of War 1 Database

Age of War 1 features **5 evolutionary ages**. Your base starts with **500 HP** and can host up to **4 turret slots** (which must be purchased).

### 1. Stone Age
The dawn of humanity. The base is a simple cave entrance.
*   **Evolve Cost**: 4,000 XP to Medieval Age.
*   **Special Attack**: *Meteor Shower* — Meteors rain down from the sky for 5 seconds (30s cooldown). Great for clearing early rushes and farming gold.

#### Units
| Unit | Cost | Kill XP | Death XP | Description / Role |
| :--- | :--- | :--- | :--- | :--- |
| **Club Man** | 15 Gold | 40 XP | 10 XP | Weak melee unit; high efficiency per cost ratio. |
| **Slingshot Man** | 25 Gold | 50 XP | 12 XP | Early ranged unit. Throws rocks at range. |
| **Dino Rider** | 100 Gold | 200 XP | 50 XP | Heavy melee unit. Mounted dinosaur rider with high HP. |

#### Turrets
| Turret | Cost | Damage | Range | Fire Rate | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Rock Slingshot** | 100 Gold | Low | Short | Medium | Basic rock projectile launcher. |
| **Egg Automatic** | 200 Gold | Low | Medium | High | Rapid-fire egg launcher. |
| **Primitive Catapult** | 500 Gold | Medium | Long | Low | Slow but powerful area damage. |

---

### 2. Medieval (Castle) Age
Based on the European Dark and Middle Ages. The base upgrades to a wooden fortress.
*   **Evolve Cost**: 14,000 XP to Renaissance Age.
*   **Special Attack**: *Arrow Rain* — A barrage of arrows sweeps across the battlefield, dealing high damage.

#### Units
| Unit | Cost | Kill XP | Death XP | Description / Role |
| :--- | :--- | :--- | :--- | :--- |
| **Sword Man** | 50 Gold | 100 XP | 25 XP | Standard melee infantry. Good balance of health and damage. |
| **Archer** | 75 Gold | 150 XP | 37 XP | Ranged unit. Fires arrows over distance. |
| **Knight** | 500 Gold | 1,000 XP | 250 XP | Heavy cavalry. Mounted knight with high health and devastating attack. |

#### Turrets
| Turret | Cost | Damage | Range | Fire Rate | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Catapult** | 500 Gold | Medium | Long | Low | Throws large stones over distance. |
| **Fire Catapult** | 750 Gold | High | Long | Low | Launches flaming boulders. |
| **Oil / Heated Tar** | 1,000 Gold | High | Very Short | Continuous | Pours hot oil on enemies directly under the base. |

---

### 3. Renaissance Age
Introducing gunpowder to the battlefield. The base becomes a stone castle.
*   **Evolve Cost**: 45,000 XP to Modern Age.
*   **Special Attack**: *Bomb Rain* — Heavy explosive artillery strikes cover the ground.

#### Units
| Unit | Cost | Kill XP | Death XP | Description / Role |
| :--- | :--- | :--- | :--- | :--- |
| **Dueler** | 200 Gold | 400 XP | 100 XP | Melee skirmisher wielding a rapier. Fast attacks. |
| **Musketeer** | 400 Gold | 800 XP | 200 XP | Gunpowder ranged unit. Fires musket rounds. |
| **Cannoneer** | 1,000 Gold | 2,000 XP | 500 XP | Heavy ranged unit. Slowly pushes and fires cannonballs. |

#### Turrets
| Turret | Cost | Damage | Range | Fire Rate | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Small Cannon** | 1,500 Gold | Medium | Long | Medium | Fires small iron cannonballs. |
| **Large Cannon** | 3,000 Gold | High | Long | Low | Devastating large cannonballs. |
| **Explosive Cannon** | 6,000 Gold | Very High | Long | Low | Cannonballs explode on impact, dealing splash. |

---

### 4. Modern Age
World War era technology. The base becomes a concrete military bunker.
*   **Evolve Cost**: 200,000 XP to Future Age.
*   **Special Attack**: *Air Support / Bombardment* — Jets fly over and carpet bomb the enemy army.

#### Units
| Unit | Cost | Kill XP | Death XP | Description / Role |
| :--- | :--- | :--- | :--- | :--- |
| **Melee Infantry** | 1,500 Gold | 3,000 XP | 750 XP | Close-quarters soldier armed with a combat knife. |
| **Infantry** | 2,000 Gold | 4,000 XP | 1,000 XP | Assault rifle-wielding soldier with ranged capabilities. |
| **Tank** | 7,000 Gold | 14,000 XP | 3,500 XP | Heavy armored vehicle. High health and heavy fire. |

#### Turrets
| Turret | Cost | Damage | Range | Fire Rate | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Single Turret** | 7,000 Gold | High | Long | Medium | Automated heavy machine gun outpost. |
| **Rocket Turret** | 9,000 Gold | Very High | Long | Low | Fires homing rockets. |
| **Double Turret** | 14,000 Gold | Extreme | Long | High | Double-barreled defense system. |

---

### 5. Future Age
Sci-Fi warfare. The base becomes a futuristic, neon shield dome.
*   **Evolve Cost**: Max Age reached.
*   **Special Attack**: *Shield/Shockwave* — Destroys all ground targets with futuristic orbital energy sweeps.

#### Units
| Unit | Cost | Kill XP | Death XP | Description / Role |
| :--- | :--- | :--- | :--- | :--- |
| **God's Blade** | 5,000 Gold | 10,000 XP | 2,500 XP | Cyborg wielding dual energy swords. Fast and deadly. |
| **Blaster** | 6,000 Gold | 12,000 XP | 3,000 XP | Ranged soldier firing plasma rifles. |
| **War Machine** | 20,000 Gold | 40,000 XP | 10,000 XP | Giant armored mech that fires heavy rockets and lasers. |
| **Super Soldier** | 150,000 Gold | 300,000 XP | 75,000 XP | Extremely expensive super-clone. Effectively guarantees victory if deployed. |

#### Turrets
| Turret | Cost | Damage | Range | Fire Rate | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Titanium Shooter** | 24,000 Gold | High | Medium | Very High | Rapid-fire laser gatling gun. |
| **Lazer Cannon** | 40,000 Gold | Very High | Long | Medium | Focussed energy beam turret. |
| **Ion Ray** | 100,000 Gold | Extreme | Long | Low | Massive orbital-style ion strike laser. |

---

## 🛡️ Age of War 2 Database

Age of War 2 expands the formula to **7 evolutionary ages**, adding the **Spartan** and **Egyptian** Eras. It also introduces population caps, unit toggles, and base building updates (such as having to buy specific buildings/research to unlock heavy units).

### 💰 Unit Upgrades & Unlocks
In AoW2, certain heavy or advanced units require building upgrades before they can be trained:
*   **Dino Hut** (400 Gold) — Unlocks *Assault Dino* (Stone Age).
*   **Armory** (600 Gold) — Unlocks *Armored Spartan* (Spartan Age).
*   **Temple** (750 Gold) — Unlocks *Priest* (Egyptian Age).
*   **Arena** (900 Gold) — Unlocks *Footman* (Medieval Age - PC version has this unlocked by default).
*   **Black Powder** (1,000 Gold) — Unlocks *Cannon* (Renaissance Age).
*   **Factory** (1,100 Gold) — Unlocks *Tank* (Modern Age).

---

### 🏛️ Evolution Costs & God Spells

| Age | Evolution Cost (XP) | Special Spell | Spell Cost (XP) | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Stone Age** | Start | *Meteorite Shower* | 2,000 XP | Falls meteors to kill units and farm gold. |
| **Spartan Age** | 7,000 XP | *Zeus' Anger* | 2,500 XP | Thunderstorm that strikes units across the map. |
| **Egyptian Age** | 8,000 XP | *Rage of the Desert* | 3,000 XP | Pyramids fire solar light balls to incinerate foes. |
| **Medieval Age** | 9,000 XP | *Arrow Storm* | 4,000 XP | Large volley of arrows, usually one-shots targets. |
| **Renaissance Age**| 10,000 XP | *Bomb Rain* | 5,000 XP | Rains down high-explosive bombs. |
| **Modern Age** | 11,000 XP | *Air Support* | 8,000 XP | Carpet bombs the map. |
| **Future Age** | 12,000 XP | *Orbital Strike* | 10,000 XP | Sweeping energy waves destroy ground enemies. |

---

### 👥 Detailed Age of War 2 Stats

#### 1. Stone Age
*   **Unique Feature**: Features the first female units in the series (*Speedy Dino*, *Assault Dino*).

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Clubman** | 100 | 200 XP | 50 XP | 1 | 25-35 | 0.67/s | 140 | 4.4m/s | 1s | Melee |
| **Slinger** | 125 | 250 XP | 62 XP | 1 | 15-35 | 0.51/s | 100 | 6.1m/s | 1.5s | 13m |
| **Speedy Dino** | 200 | 400 XP | 100 XP | 1 | 30-35 | 0.94/s | 175 | 7.0m/s | 2.5s | Melee |
| **Assault Dino** | 400 | 800 XP | 200 XP | 2 | 30-50 | 0.40/s | 600 | 4.0m/s | 4s | 20m (Ranged) |

**Turrets**
*   **Mammoth Catapult** (750 Gold): 8-16 Dmg, 25m Range, 0.71/s Fire Rate.
*   **Egg Rifle** (1,500 Gold): 5-15 Dmg, 27.5m Range, 2.6/s Fire Rate.
*   **Rock Slingshot** (2,300 Gold): 15-20 Dmg, 20m Range, 2.1/s Fire Rate.

---

#### 2. Spartan Age
*   **Strategy Note**: Buy Stone Age turrets before evolving, as Spartan Age has only one turret slot which is expensive.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Sword Spartan** | 100 | 200 XP | 50 XP | 1 | 20-35 | 0.72/s | 210 | 5.0m/s | 1s | Melee |
| **Spear Spartan** | 125 | 250 XP | 62 XP | 1 | 15-30 | 0.56/s | 140 | 3.7m/s | 1.5s | 13.5m |
| **Assault Spartan** | 200 | 400 XP | 100 XP | 1 | 35-40 | 0.90/s | 300 | 4.0m/s | 2.5s | Melee |
| **Armored Spartan** | 400 | 800 XP | 200 XP | 1 | 30-40 | 0.85/s | 400 | 11.0m/s | 4s | Melee |

**Turrets**
*   **Guard** (2,000 Gold): 18-25 Dmg, 23m Range, 1.5/s Fire Rate.

---

#### 3. Egyptian Age
*   **Unlock**: Requires Temple (750 Gold) for Priests.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Kopesh Warrior** | 100 | 200 XP | 50 XP | 1 | 35-45 | 0.51/s | 230 | 3.1m/s | 1s | Melee |
| **Priest** | 125 | 250 XP | 62 XP | 1 | 20-40 | 0.69/s | 200 | 6.1m/s | 1.5s | 13m |
| **Anubis Warrior** | 200 | 400 XP | 100 XP | 1 | 40-60 | 0.63/s | 350 | 4.0m/s | 2.5s | Melee |
| **Cart Warrior** | 400 | 800 XP | 200 XP | 1 | 30-45 | 0.76/s | 400 | 5.0m/s | 4s | 20m |

**Turrets**
*   **Golden Eagle** (1,500 Gold): 15-30 Dmg, 27.5m Range, 1.4/s Fire Rate.
*   **Big Bird** (2,100 Gold): 25-35 Dmg, 20m Range, 1.2/s Fire Rate.

---

#### 4. Medieval Age
*   **Unlock**: Requires Arena (900 Gold) to send Footmen on browser.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Footman** | 100 | 200 XP | 50 XP | 1 | 45-55 | 0.52/s | 350 | 4.0m/s | 1s | Melee |
| **Archer** | 125 | 250 XP | 62 XP | 1 | 25-40 | 0.57/s | 250 | 4.0m/s | 1.5s | 15m |
| **Mage** | 200 | 400 XP | 100 XP | 1 | 55-70 | 0.63/s | 210 | 5.0m/s | 2.5s | Melee |
| **Griffon Knight** | 400 | 800 XP | 200 XP | 1 | 50-85 | 0.56/s | 435 | 4.3m/s | 4s | Melee |

**Turrets**
*   **Crossbow** (1,000 Gold): 25-45 Dmg, 18m Range, 1.2/s Fire Rate.
*   **Rock Catapult** (2,000 Gold): 45-60 Dmg, 20m Range, 0.74/s Fire Rate.
*   **Metal Catapult** (3,000 Gold): 50-70 Dmg, 20m Range, 0.85/s Fire Rate.

---

#### 5. Renaissance Age
*   **Unlock**: Requires Black Powder research (1,000 Gold) for Cannons.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Swordman** | 100 | 200 XP | 50 XP | 1 | 50-65 | 0.60/s | 350 | 5.0m/s | 1s | Melee |
| **Rifleman** | 125 | 250 XP | 62 XP | 1 | 30-55 | 0.46/s | 250 | 5.5m/s | 1.5s | 15m |
| **Cannon** | 200 | 400 XP | 100 XP | 2 | 35-60 | 0.54/s | 280 | 5.0m/s | 2.5s | 20m |
| **Knight** | 400 | 800 XP | 200 XP | 1 | 60-80 | 0.71/s | 410 | 4.5m/s | 4s | Melee |

**Turrets**
*   **Small Cannon** (2,000 Gold): 55-70 Dmg, 20m Range, 0.75/s Fire Rate.
*   **Large Cannon** (3,500 Gold): 65-85 Dmg, 20m Range, 0.72/s Fire Rate.

---

#### 6. Modern Age
*   **Unlock**: Requires Factory (1,100 Gold) for Tanks.
*   **Special Attack notes**: Infantry fire 3-round bursts; Machine Gun infantry fire 4-round bursts. Tanks have long-range cannons and a secondary melee machine gun.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Infantry Soldier** | 100 | 200 XP | 50 XP | 1 | 45-65 | 0.61/s | 400 | 5.0m/s | 1s | 16.6m |
| **Machine Gun Soldier**| 125 | 250 XP | 62 XP | 1 | 25-55 | 0.91/s | 300 | 6.0m/s | 1.5s | 13m |
| **Grenade Soldier** | 200 | 400 XP | 100 XP | 1 | 40-60 | 0.64/s | 350 | 5.0m/s | 2.5s | 23m |
| **Tank** | 400 | 800 XP | 200 XP | 2 | 60-100| 0.57/s | 1,000 | 5.0m/s | 4s | 22.5m |

**Turrets**
*   **Machine Gun** (2,000 Gold): 10-14 Dmg, 25m Range, 4.9/s Fire Rate.
*   **Rocket Launcher** (3,000 Gold): 70-160 Dmg, 22m Range, 0.99/s Fire Rate.
*   **Double Rocket Launcher** (4,500 Gold): 70-90 (x2) Dmg, 20m Range, 0.99/s Fire Rate.

---

#### 7. Future Age
*   **Combat units**: Future Age features 5 standard units. *God's Wrath* is a massive boss-style unit that acts as an ultimate game finisher.

**Units**
| Unit | Cost | Kill XP | Death XP | Pop | Damage | Speed (Atk) | HP | Move Speed | Build Time | Range |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Spider Blade** | 200 | 400 XP | 100 XP | 1 | 60-75 | 0.68/s | 1,000 | 11.0m/s | 1s | Melee |
| **Cyborg** | 250 | 500 XP | 125 XP | 1 | 25-45 | 0.79/s | 700 | 5.0m/s | 1.5s | 17m |
| **Mad Scientist** | 400 | 800 XP | 200 XP | 1 | 50-55 | 1.40/s | 950 | 3.2m/s | 2.5s | 20m |
| **Armored Combat Suit**| 800 | 1,600 XP | 400 XP | 1 | 75-100 | 1.10/s | 1,350 | 3.2m/s | 4s | 15m |
| **God's Wrath** | 10,000 | 20,000 XP | 5,000 XP | 2 | 600-1,400| 0.32/s | 16,500 | 2.6m/s | 6s | Melee |

**Turrets**
*   **Ion Cannon** (2,500 Gold): 15-25 Dmg, 20m Range, 3.8/s Fire Rate.
*   **Plasma Cannon** (3,500 Gold): 45-90 Dmg, 27.5m Range, 0.99/s Fire Rate.
*   **Heavy Plasma Cannon** (5,000 Gold): 40-150 Dmg, 25m Range, 1.5/s Fire Rate. (Stacking 4 of these offers impenetrable defense).

---

## 🦕 Army of Ages (Spin-off Overview)

Army of Ages is the third entry in the series, featuring **5 ages** (Stone, Medieval, Renaissance, Modern, Future). It shifts mechanics toward resource collection and unit specializations (Biological vs. Mechanical, Ground vs. Air). 

### Major Mechanics
*   **Gatherers**: Special units that extract Water/Oil and Gold to fund unit production.
*   **Ages & Unit Types**: Units are classified as Light, Medium, or Heavy, and have specialized attack targets (Ground only, Air only, or Air & Ground).
*   **Medieval Special (Arrow Rain)**: The only special attack capable of targeting Air units. Keep this in mind when evolving, as later special attacks (such as *Shockwave* or *Bombardment*) can only strike ground units.

---

## 💡 Tactical Strategies & Tips

### Age of War 1 Strategies
1.  **The Spell Start Strategy**: At the start of a match, do not immediately buy units. Wait for the enemy to queue up at least 5 units. Once they get near your base, activate the *Meteor Shower* spell. The spell will kill all of them, netting you a massive gold boost that you can instantly invest in an **Egg Automatic** turret.
2.  **Queue Pausing**: If you pause the game while units are training, the queue progress and spells will continue loading in the background. Use this trick to prepare troops safely during high-intensity pushes.
3.  **Turret Height**: Defensive turrets placed at the bottom slots of your base tower actually shoot slightly farther than those at the top. Put your shorter-range high-dps turrets at the bottom and long-range catapults/rockets at the top.

### Age of War 2 Strategies
1.  **Pre-evolution Turret Stacking**: Evolving into the *Spartan Age* removes the ability to build multiple cheap turrets (you only get 1 guard slot). Make sure to purchase all your Stone Age turrets (*Egg Rifles*, *Mammoth Catapults*) *before* you evolve. They will stay active on your base even in the Spartan Age!
2.  **Spartan Shield Composition**: Create a mixed defensive wall by training a high-HP *Armored Spartan* or *Footman* at the front, and following immediately with 2-3 *Spear Spartans* behind them. The spear units can strike over the shoulder of the front units, creating a high-DPS frontline death stack.
3.  **Four Heavy Plasmas**: In the final Future Age, building **four Heavy Plasma Cannons** is widely considered the ultimate defense. They can clean up standard enemy waves before they can even touch your units.
