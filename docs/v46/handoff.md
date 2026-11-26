# 0.46 handoff: multiplayer fixes, healthkits, weapon drop, game modes

Build: `builds/windows/Interior.exe` + `Interior.pck` (0.46.0). Share `builds/windows/Sleep-0.46.0-windows.zip`.
Nothing is committed.

## Fixed

**"Everyone dies in the mart, even invulnerable".** The store last stand was run for 150 s with the debug toggle
on (`tests/coop_store_survival.gd`). No health was lost from the infected. Two things could still wipe the squad:
- **Grenade blasts ignored the debug toggle.** The toggle only stopped infected hits; frag blasts went straight
  through. One frag could down the whole squad: 160 damage within 1.6 m and up to 130 within 8 m. That happens
  when it bounces back off the doorway into the sandbag horseshoe. When everyone is down, the mission fails at
  once ("The whole team is down").
  - The toggle now covers blasts. It is called "Team invulnerable (infected and blasts)".
  - In co-op, one frag takes at most 85 HP from the thrower and at most 45 from a teammate.
- **The toggle was forgotten between games.** It lived on the mission, which is rebuilt for every game, but the
  checkbox stayed ticked. A second game looked invulnerable but wasn't. The setting now lives on the session, and
  the checkbox shows its real state.
- When a mission fails, the console logs `INTERIOR_COOP_FAILED stage .. guide .. team [[id, hp]..]`.

**Texture flicker inside the mart** (owner's screenshot, left end of the sandbags). The two side walls of the
sandbag horseshoe ran into the back wall's end bags at the same heights. Their coplanar faces z-fought. The side
walls now stop short of the back wall and sit 1.8 cm higher (street.gd).

**Healthkits did nothing visible.** H only worked when hurt, and nothing told you so. That is replaced below.

**Ammo readout cut off.** The bottom-right readout grew to the right, past the screen edge. Anything after "AUTO"
(frags, healthkits) was invisible. It now grows to the left (gun.gd).

## New

**Healthkits** (mission.gd `start_heal` / `stop_heal` / `heal_tick`, host side):
- Hold **F** to use one on yourself. It takes 3 s, and you can only shuffle slowly meanwhile. Let go early and
  the kit is kept.
- Hold **E** on a hurt or downed teammate to patch them up. It takes 3 s, they cannot move meanwhile, and you have
  to stay within 3 m.
- A kit heals a random 40–70 HP. A downed teammate comes up with that much.
- You carry 3 at most. A fourth stays on the ground with a message.
- The count shows next to the ammunition ("2 kits"). The prompt shows a progress bar while healing.
- The squad AI use the same 3-second patch-up.
- Debug menu (co-op host): **Healthkits: 3 each**, **Healthkit: +1 me**, **Hurt me 40**. "Team: full health"
  now gives 3 kits.

**Hold G to drop the weapon in your hands** (0.6 s; a tap of G still draws or holsters the Glock).
- It lands in front of you as its own model, lying on its side, with its magazine, chamber and spare rounds.
- E picks it up with "Take rifle (100 rounds)". If you already carry that weapon, you take its rounds instead.
- The next weapon you carry comes up.
- F and G are taken in co-op by `session._input` before the player (F inspect) and the gun (G holster) see them.

**Game modes**: the host picks one in the room (MODE: EASY / NORMAL / HARD). Everyone sees it in the room header.

| Mode | Each survivor starts with |
|---|---|
| Easy | rifle (100 rounds), Glock (60), 1 frag grenade, 1 healthkit |
| Normal | Glock (65), 1 healthkit |
| Hard | Glock (50) |

- Rounds count the loaded magazine.
- The squad AI get the same guns and kits.
- Before 0.46 everyone started with a Glock (86 rounds), 3 frags and 1 kit.

**Grenades lying about** (`Mission.GRENADE_SPOTS`). Each is a pouch with two frags on it and gives one grenade (E):
- by the ammo boxes in the mart;
- inside the sandbag horseshoe;
- at the Store Road checkpoint;
- behind the soldiers' sandbags at the ramp;
- on Jonna's desk;
- by the dead soldier in the backstreets.

**Leaving the mart behind** (`mission._leave_behind`). This runs on every peer once everyone still standing is
through the service gate. It hides and stops everything wholly outside the backstreets:
- the solo world, the canal, Store Road and the ramp;
- the bodies back there, which are freed;
- the infected left back there, which are dropped.

In the test it hid 648 nodes. Their lights, shadows, draw calls and physics bodies are all off.

## Tests

- `tests/coop_kits_modes.gd`, 35 checks. It covers modes, F/E healing, the kit cap, G drop and pick-up,
  grenades, invulnerability against blasts, and the cleanup. `-- --shots=<dir>` saves frames.
- `tests/coop_store_survival.gd`: the last stand with the debug toggle on. Nobody may go down and the mission may
  not fail. `STORE_SECONDS` sets the length (default 150).

## Not verified

- No real two-PC game was played. The client paths (F/G/E over RPC, mode sync to joiners, cleanup from synced
  positions) went through the same functions in the host test, not through a second window.
- I could not reproduce a squad wipe with the toggle on. If it happens again, the `INTERIOR_COOP_FAILED` line in
  the console says what each survivor's health was.

## Screenshots sent

| File | Shows |
|---|---|
| work/v46/screens/01-dropped-rifle.jpg | A dropped rifle on the mart floor, "Take rifle (100 rounds)", a patch-up result |
| work/v46/screens/04-backstreets-after-cleanup.jpg | The backstreets after the world behind was put away |
| work/v46/exe/lobby_room.png | EXE: the MODE picker in the room |
| work/v46/exe/mission_chat.png | EXE: a Normal start, "18 / 47   1 kit" |
