# 0.42 — Olivar Family Mart: real stock, a wrecked store, its dead

Owner's request (2026-11-18): the inside of the convenience store looked cheap and its made-up Filipino products
were corny. Stock it with real grocery items (chips, soft drinks in the fridges, cans, at least 20 kinds), make it
messy like a fight happened there, add dead bodies in different positions (one inside the counter), make it creepy.
Mid-task: rename the store "Olivar Family Mart", tagline "Pang-pamilya ang presyo, Garantisado!". Build the game.

## Stock (56 real products)
- `tools/store_goods.py` (`python -I tools/store_goods.py`) draws each label at its shape's real proportions into
  one 4096 px atlas (8 x 8 cells of 512) plus 16 flat swatches for lids, caps and bottle shoulders:
  `game/assets/coop/goods/atlas.png` (VRAM-compressed, mipmapped: set by hand in its .import), `goods.json`
  (name -> cell, shape, size in metres, swatches, material, label repeats), `hole.png`, `crack.png`.
- Brands, picked from what a Davao convenience store carries (Pepsi-Cola PH's line at 7-Eleven; Century Pacific's
  canned fish/meat brands): Coca-Cola, Coke Zero, Pepsi, Sprite, Mountain Dew, 7UP, Royal, Red Bull, Monster, San
  Miguel Pale Pilsen, Red Horse, Heineken (cans); Coca-Cola, Sprite, Pepsi 1.5 L, Gatorade, Pocari Sweat, C2,
  Wilkins, Minute Maid Pulpy, Cobra (bottles); Pringles x3; Lay's, Doritos, Cheetos, Piattos, Nova, Oishi Prawn
  Crackers, Ruffles, Lucky Me! Pancit Canton, M&M's (bags); Spam, Century Tuna, Argentina Corned Beef, 555, Ligo,
  Libby's Vienna Sausage, Del Monte Fruit Cocktail, Campbell's (cans); Nissin Cup Noodles x2; Oreo, Kellogg's Corn
  Flakes, Milo, Nescafé 3in1, Tide, Colgate, Safeguard, Kit Kat, Snickers, Hershey's, Marlboro, SkyFlakes, a
  24-can Coke case. The logos are lettering and colour schemes drawn with Windows fonts, not the trademark art.
- `scripts/coop/store_goods.gd` builds them: cans/tins, PET bottles (body, shoulder, neck, cap), tubes, tapered
  cups, pillowed chip bags with crimped ends, cartons; `panel()` for posters. Everything goes into three meshes
  (metal, plastic, paper) on layers 1|8 (the blood decals reach them). Front of an item = local +Z.

## The store (scripts/coop/street.gd)
- Names: fascia OLIVAR FAMILY MART, the tagline on a lit valance at the canopy's edge, pylon OLIVAR / FAMILY MART
  (red now), category bands and aisle boards in English (CANNED GOODS, BEVERAGES, SNACKS, HOUSEHOLD...). Mission
  objective/intro/hint text updated (mission.gd, session.gd).
- Gondolas faced in blocks (pantry x2, snacks x2, household shoved askew), `shelves(c, theme, mess, yaw)`: emptied
  blocks, things knocked over on the shelf and onto the floor. End caps: Pringles, chips, noodles. Wall shelving:
  Milo, Nescafé, Corn Flakes, SkyFlakes, Oreo. Fridges are hollow now (they were solid boxes: anything inside was
  hidden) and stocked: Coke/Sprite, Pepsi/7UP/Dew/Royal/water, sports and energy drinks, beer; one hanging open and
  emptied over the floor, one with a round through its glass. Counter: the till knocked off and emptied (coins,
  notes), candy rack (Snickers, Kit Kat, Hershey's, M&M's), cigarette rack of Marlboro.
- Mess: ~400 items on the floor (on their side, face down, cans stepped flat), cola/sports-drink pools, receipts,
  dropped baskets, a burst Coke case display, 160 brass casings, cracked front panes and bullet holes (front, side
  walls, end caps), a toppled wet-floor sign.
- Dead (`STORE_DEAD`, spawned in mission `_victims` as ragdolls from a clip held part-way): the cashier slumped
  behind the counter against the cigarette rack, a customer over (or fallen off) the counter, the soldier behind
  the sandbags, one face down in the aisle, one against the open fridge, one over a freezer chest, one under the
  window bar, one in the staff-room doorway (door now open), an infected the soldiers dropped at the door, one at the
  counter's end. Blood pool under each, spatter, smears on the counter and walls.
- Creepy: most tubes dead or flickering (8 of 12), one troffer hanging on its wires sparking with an arc buzz and
  shadows, pendants half dead, a green EXIT sign, flies over the dead, a drip by the open fridge, a phone on the
  floor by the counter that lights up in rings every ~19 s.

## Tests
- `tests/coop_street_review.gd` pass (16 checks); new `store_photos()` (store_door, fridges, cashier, counter,
  pantry, snacks, household, freezer, wall, staff, name) and `-- --store` for only those; notes list where each
  body settled.
- `coop_integration` 25/25. `coop_squad_integration` 27/27 run alone (run with coop_integration in parallel it
  fails at once: two hosts on UDP 25108); one run of three missed "went over away from the gun" (0.11 m, a ragdoll
  direction on the street), the next two passed.

## Open
- Ragdoll results vary run to run (the customer lands on the counter or slides off it).
- The sari-sari store's snack strips now use the same goods (Lucky Me, Piattos, Nova).
