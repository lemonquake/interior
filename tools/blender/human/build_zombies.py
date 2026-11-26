"""Interior 0.44: 27 uniquely dressed, creepy infected townspeople built on models/generic_body_rigged.glb.

  blender -b --factory-startup --python tools/blender/human/build_zombies.py -- [export] [preview] [clips] [only=<name>]

  export    game/assets/characters/zombies/z_<name>.glb (mesh + rig, no clips) and zombie_anims.glb (rig + clips)
  preview   front + close-up renders of each variant -> work/v44/zombies/<name>_front.png, <name>_q.png
  clips     frames of the clips the game may use     -> work/v44/zombies/clip_<clip>_<k>.png

First 7 entries preserve the original townsperson names & order (tambay, obrero, tanod, kuya, nanay, dalaga,
estudyante) for full backwards compatibility with tests, co-op victims, and build_survivors.py. Twenty additional
uniquely dressed horror variants (indices 7..26) give 27 distinct silhouettes, outfits, accessories, hairstyles,
and decay/gore profiles so crowds never look like clones.
"""
import json
import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)
import build_human as bh
import crawl_clips
import hair_kit

ROOT = bh.ROOT
OUT_DIR = os.path.join(ROOT, "game", "assets", "characters", "zombies")
WORK = os.path.join(ROOT, "work", "v44", "zombies")
SIZE = 1024
GEAR_SIZE = 512

CLIPS = ["idle", "idle_look", "idle_hurt", "walk", "walk_hurt", "run", "run_hurt", "hero_run", "fem_walk", "fem_run",
         "fem_idle", "turn_l", "turn_r", "hit_light", "hit_heavy", "hit_front", "hit_back", "hit_left", "hit_right",
         "stagger_small", "stagger_heavy", "knockback", "knockdown", "getup", "death", "death_back", "death_fwd",
         "death_crumple", "devour", "alert", "taunt", "war_cry", "boss_roar", "boss_sweep", "boss_slam", "dual_1",
         "dual_2", "dual_3", "dual_heavy", "special_attack", "wall_impact", "launch"]
MADE_CLIPS = ["crouch_walk", "crawl", "down_idle", "sit_hurt"]
CLIP_SHEET = ["crouch_walk", "crawl", "down_idle", "dual_1", "dual_2", "dual_heavy", "boss_sweep", "devour", "war_cry",
              "boss_roar", "taunt", "special_attack", "stagger_heavy", "walk_hurt", "run_hurt", "idle_hurt", "getup",
              "knockdown", "alert"]

UV_NAME = ["UVMap"]
BLOOD = np.array((0.30, 0.018, 0.016), np.float32)
DRIED = np.array((0.15, 0.028, 0.022), np.float32)
BILE = np.array((0.06, 0.055, 0.035), np.float32)
DIRT = np.array((0.16, 0.125, 0.088), np.float32)
SOOT = np.array((0.05, 0.048, 0.046), np.float32)

# 27 distinct zombie variants: indices 0..6 keep the original 7 names & order; indices 7..26 add 20 brand-new outfits.
VARIANTS = [
    # 0. Tambay (original 0) - pot-bellied lounger in torn bloody white sando & blue/yellow basketball shorts, barefoot
    dict(name="tambay", sex="m", seed=11,
         shapes={"belly": 0.78, "cheeks": 0.55, "nose_wide": 0.5},
         tone=(0.76, 0.80, 0.68), hair="textured_crop", hair_col=(0.028, 0.024, 0.022),
         horror=dict(decay="bloated", eye_style="milky", face_gore="neck_bite", veins=1.0),
         top=dict(kind="sando", color=(0.76, 0.74, 0.68), blood=0.95, ragged=True),
         bottom=dict(kind="shorts", z0=0.46, loose=0.024, color=(0.08, 0.13, 0.42), color2=(0.86, 0.80, 0.18),
                     pattern="side_stripe", blood=0.45)),

    # 1. Obrero (original 1) - muscular construction laborer, orange hi-vis shirt, dark work pants, boots, utility belt
    dict(name="obrero", sex="m", seed=23,
         shapes={"build": 0.62, "muscle": 0.58, "jaw_wide": 0.62, "brow_heavy": 0.65},
         tone=(0.72, 0.74, 0.72), hair="textured_spiky", hair_col=(0.032, 0.028, 0.024),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="ripped_cheek", veins=0.95),
         top=dict(kind="shirt", sleeve=0.66, torn_sleeve="R", color=(0.76, 0.32, 0.07), color2=(0.70, 0.72, 0.68),
                  pattern="hivis", blood=0.7),
         bottom=dict(kind="pants", color=(0.10, 0.12, 0.18), pattern="denim", blood=0.38),
         shoes=dict(style="boot", color=(0.11, 0.075, 0.045)),
         gear=dict(belt=dict(color=(0.14, 0.10, 0.06), pouches=True))),

    # 2. Tanod (original 2) - barangay watchman, black/gold duty shirt, khaki trousers, boots, utility belt
    dict(name="tanod", sex="m", seed=37,
         shapes={"belly": 0.36, "cheeks": 0.75, "brow_heavy": 0.88, "chin_long": 0.4},
         tone=(0.68, 0.70, 0.76), hair="slick_back", hair_col=(0.14, 0.14, 0.14), grey_mix=0.55,
         horror=dict(decay="cyanotic", eye_style="hollow", face_gore="chin_drip", veins=1.1),
         top=dict(kind="shirt", sleeve=0.36, color=(0.04, 0.04, 0.048), color2=(0.78, 0.62, 0.08),
                  pattern="chest_band", blood=0.55),
         bottom=dict(kind="pants", color=(0.24, 0.21, 0.16), blood=0.48),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.055)),
         gear=dict(belt=dict(color=(0.06, 0.06, 0.065), pouches=True))),

    # 3. Kuya (original 3) - neighborhood older brother, striped polo with torn sleeve, jeans, beat-up sneakers
    dict(name="kuya", sex="m", seed=41,
         shapes={"muscle": 0.30, "ears_out": 0.58, "nose_long": 0.48, "lips_full": 0.4},
         tone=(0.80, 0.78, 0.69), hair="side_part", hair_col=(0.028, 0.024, 0.020),
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="black_bile", veins=0.9),
         top=dict(kind="shirt", sleeve=0.38, torn_sleeve="L", color=(0.60, 0.64, 0.70), color2=(0.18, 0.28, 0.50),
                  pattern="stripes_h", blood=0.8),
         bottom=dict(kind="pants", color=(0.15, 0.21, 0.35), pattern="denim", blood=0.45),
         shoes=dict(style="sneaker", color=(0.48, 0.46, 0.44))),

    # 4. Nanay (original 4) - mother in faded tattered floral duster dress, barefoot, bun hair
    dict(name="nanay", sex="f", seed=53,
         shapes={"female": 1.0, "belly": 0.48, "rear": 0.52, "cheeks": 0.55},
         tone=(0.74, 0.76, 0.72), hair="high_bun", hair_col=(0.045, 0.040, 0.036), grey_mix=0.25,
         horror=dict(decay="ashen", eye_style="milky", face_gore="eye_bleed", veins=1.0),
         top=dict(kind="shirt", sleeve=0.30, hem=0.99, color=(0.60, 0.28, 0.40), color2=(0.86, 0.80, 0.52),
                  pattern="floral", blood=0.75),
         skirt=dict(z0=0.40, flare=0.075, ragged=True, color=(0.60, 0.28, 0.40), color2=(0.86, 0.80, 0.52),
                    pattern="floral", blood=0.75)),

    # 5. Dalaga (original 5) - young woman in torn faded mustard tee & denim cutoffs, long dark hair, barefoot
    dict(name="dalaga", sex="f", seed=67,
         shapes={"female": 1.0, "lips_full": 0.55, "eyes_pop": 0.35},
         tone=(0.78, 0.78, 0.74), hair="long_straight", hair_col=(0.025, 0.022, 0.020),
         horror=dict(decay="morgue", eye_style="asymmetric", face_gore="neck_bite", veins=1.05),
         top=dict(kind="shirt", sleeve=0.33, ragged=True, color=(0.76, 0.68, 0.42), blood=0.92),
         bottom=dict(kind="shorts", z0=0.69, loose=0.008, color=(0.18, 0.27, 0.44), pattern="denim", blood=0.38)),

    # 6. Estudyante (original 6) - student in bloody white blouse, pleated plaid skirt, backpack, school shoes, bob hair
    dict(name="estudyante", sex="f", seed=79,
         shapes={"female": 0.92, "build": -0.22, "chin_long": 0.28},
         tone=(0.74, 0.78, 0.78), hair="chin_bob", hair_col=(0.024, 0.022, 0.022),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="black_bile", veins=1.0),
         top=dict(kind="shirt", sleeve=0.33, hem=1.0, color=(0.82, 0.81, 0.78), pattern="button_placket", blood=0.88),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.07, 0.10, 0.24), color2=(0.18, 0.24, 0.44),
                    pattern="plaid", blood=0.45),
         shoes=dict(style="dress", color=(0.04, 0.04, 0.045)),
         gear=dict(backpack=dict(color=(0.38, 0.10, 0.12)))),

    # ---------------- 20 BRAND-NEW UNIQUELY DRESSED CREEPY ZOMBIES (indices 7..26) ----------------

    # 7. Doktor - blood-drenched open white lab coat over teal scrubs, stethoscope, crooked glasses, thinning grey hair
    dict(name="doktor", sex="m", seed=101,
         shapes={"build": -0.15, "cheeks": -0.35, "nose_long": 0.45, "chin_long": 0.35},
         tone=(0.74, 0.78, 0.80), hair="thinning_receding", hair_col=(0.18, 0.18, 0.18), grey_mix=0.75,
         horror=dict(decay="morgue", eye_style="hollow", face_gore="chin_drip", veins=1.2),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=(0.82, 0.83, 0.80), under_color=(0.16, 0.46, 0.48),
                  blood=1.05),
         bottom=dict(kind="pants", color=(0.12, 0.14, 0.17), blood=0.55),
         shoes=dict(style="dress", color=(0.07, 0.06, 0.055)),
         gear=dict(coat_tail=dict(z0=0.44, open_front=True, color=(0.82, 0.83, 0.80), blood=1.05, ragged=True),
                   stethoscope=dict(color=(0.08, 0.09, 0.11)),
                   glasses=dict(color=(0.14, 0.14, 0.16), tilt=0.11))),

    # 8. Nars - infected hospital nurse in teal scrubs, blood-soaked surgical mask, ponytail, clinic sneakers
    dict(name="nars", sex="f", seed=113,
         shapes={"female": 1.0, "build": -0.1, "eyes_pop": 0.4},
         tone=(0.78, 0.80, 0.66), hair="ponytail", hair_col=(0.032, 0.026, 0.022),
         horror=dict(decay="jaundiced", eye_style="bloodshot", face_gore="eye_bleed", veins=1.05),
         top=dict(kind="shirt", sleeve=0.36, color=(0.14, 0.52, 0.54), color2=(0.10, 0.40, 0.42),
                  pattern="button_placket", blood=1.0),
         bottom=dict(kind="pants", color=(0.13, 0.48, 0.50), blood=0.65),
         shoes=dict(style="sneaker", color=(0.74, 0.74, 0.72)),
         gear=dict(face_mask=dict(color=(0.56, 0.74, 0.76), blood=1.25, hanging=False))),

    # 9. Pasyente - escaped hospital patient, pale patterned hospital gown, bare bruised legs, bloody head bandage over eye
    dict(name="pasyente", sex="m", seed=127,
         shapes={"build": -0.55, "cheeks": -0.65, "muscle": -0.4, "eyes_pop": 0.55},
         tone=(0.70, 0.74, 0.80), hair="patchy_rotted", hair_col=(0.05, 0.045, 0.04),
         horror=dict(decay="gaunt", eye_style="asymmetric", face_gore="black_bile", veins=1.35, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.40, hem=0.98, color=(0.64, 0.74, 0.78), color2=(0.40, 0.52, 0.60),
                  pattern="hospital", blood=0.95),
         skirt=dict(z0=0.46, flare=0.055, ragged=True, color=(0.64, 0.74, 0.78), color2=(0.40, 0.52, 0.60),
                    pattern="hospital", blood=0.90),
         gear=dict(head_bandage=dict(color=(0.78, 0.75, 0.68), eye_cover=True, blood=1.35))),

    # 10. Matadero - burly wet-market butcher, bald veined scarred scalp, gore-drenched apron, tall rubber boots
    dict(name="matadero", sex="m", seed=139,
         shapes={"belly": 0.65, "build": 0.75, "muscle": 0.55, "jaw_wide": 0.75, "brow_heavy": 0.85},
         tone=(0.74, 0.70, 0.68), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="bloated", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.25),
         top=dict(kind="shirt", sleeve=0.35, color=(0.24, 0.23, 0.22), blood=1.15),
         bottom=dict(kind="pants", color=(0.14, 0.14, 0.16), blood=0.85),
         shoes=dict(style="boot", color=(0.09, 0.11, 0.10)),
         gear=dict(apron=dict(color=(0.76, 0.73, 0.66), blood=1.55))),

    # 11. Pulis - turned patrolman/security guard, dark navy uniform shirt, tactical cap, utility belt, torn right sleeve
    dict(name="pulis", sex="m", seed=151,
         shapes={"build": 0.35, "muscle": 0.40, "jaw_wide": 0.5, "brow_heavy": 0.7},
         tone=(0.68, 0.72, 0.76), hair="buzz_fade", hair_col=(0.03, 0.028, 0.026),
         horror=dict(decay="cyanotic", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.0),
         top=dict(kind="shirt", sleeve=0.40, torn_sleeve="R", color=(0.07, 0.11, 0.22), color2=(0.75, 0.65, 0.22),
                  pattern="button_placket", blood=0.75),
         bottom=dict(kind="pants", color=(0.05, 0.07, 0.13), blood=0.45),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(cap=dict(color=(0.05, 0.08, 0.18), backwards=False, blood=0.4),
                   belt=dict(color=(0.05, 0.05, 0.055), pouches=True))),

    # 12. Pari - infected parish priest in full-length black tattered cassock, stark white clerical collar, weeping hollow eyes
    dict(name="pari", sex="m", seed=163,
         shapes={"build": -0.25, "cheeks": -0.5, "chin_long": 0.45, "nose_long": 0.4},
         tone=(0.74, 0.76, 0.80), hair="thinning_receding", hair_col=(0.28, 0.28, 0.28), grey_mix=0.85,
         horror=dict(decay="morgue", eye_style="hollow", face_gore="eye_bleed", veins=1.15),
         top=dict(kind="shirt", sleeve=0.69, hem=1.0, color=(0.045, 0.045, 0.052), pattern="button_placket", blood=0.70),
         bottom=dict(kind="pants", color=(0.04, 0.04, 0.045), blood=0.3),
         shoes=dict(style="dress", color=(0.04, 0.04, 0.042)),
         gear=dict(coat_tail=dict(z0=0.18, open_front=False, color=(0.045, 0.045, 0.052), blood=0.75, ragged=True),
                   clerical_collar=dict(color=(0.04, 0.04, 0.045)))),

    # 13. Tindera - market vendor / carinderia cook in patterned green blouse, checkered apron, dark skirt, woven salakot hat
    dict(name="tindera", sex="f", seed=179,
         shapes={"female": 1.0, "belly": 0.55, "rear": 0.55, "cheeks": 0.65},
         tone=(0.76, 0.78, 0.66), hair="high_bun", hair_col=(0.04, 0.036, 0.032), grey_mix=0.3,
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="chin_drip", veins=0.95),
         top=dict(kind="shirt", sleeve=0.34, hem=0.98, color=(0.20, 0.46, 0.26), color2=(0.82, 0.80, 0.56),
                  pattern="floral", blood=0.70),
         skirt=dict(z0=0.36, flare=0.07, color=(0.14, 0.12, 0.11), blood=0.55),
         gear=dict(apron=dict(color=(0.74, 0.24, 0.20), color2=(0.86, 0.84, 0.78), pattern="check", blood=0.95),
                   salakot=dict(color=(0.56, 0.43, 0.24), pattern="woven", blood=0.35))),

    # 14. Drayber - jeepney/tricycle driver, backwards baseball cap, faded maroon unbuttoned shirt, cargo shorts, ONE missing shoe!
    dict(name="drayber", sex="m", seed=191,
         shapes={"build": -0.10, "muscle": 0.25, "ears_out": 0.45, "nose_wide": 0.45},
         tone=(0.74, 0.72, 0.66), hair="wavy_shag", hair_col=(0.032, 0.026, 0.022),
         horror=dict(decay="ashen", eye_style="milky", face_gore="neck_bite", veins=1.0),
         top=dict(kind="open_jacket", sleeve=0.38, hem=0.93, color=(0.44, 0.12, 0.14), under_color=(0.72, 0.70, 0.64),
                  blood=0.80),
         bottom=dict(kind="shorts", z0=0.45, loose=0.018, color=(0.30, 0.26, 0.19), blood=0.50),
         shoes=dict(style="sneaker", side="L", color=(0.24, 0.24, 0.26)),
         gear=dict(cap=dict(color=(0.52, 0.14, 0.12), backwards=True, blood=0.45))),

    # 15. Mekaniko - oil-blackened auto mechanic in dark navy coveralls with ripped left pant leg, knit beanie, work boots
    dict(name="mekaniko", sex="m", seed=211,
         shapes={"build": 0.45, "muscle": 0.60, "jaw_wide": 0.55},
         tone=(0.64, 0.65, 0.64), hair="buzz_fade", hair_col=(0.03, 0.028, 0.026),
         horror=dict(decay="charred", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.1),
         top=dict(kind="coveralls", sleeve=0.62, torn_sleeve="L", color=(0.10, 0.15, 0.24), color2=(0.56, 0.16, 0.10),
                  pattern="chest_band", grease=True, blood=0.85),
         bottom=dict(kind="pants", torn_leg="L", color=(0.10, 0.15, 0.24), grease=True, blood=0.65),
         shoes=dict(style="boot", color=(0.12, 0.09, 0.06)),
         gear=dict(beanie=dict(color=(0.16, 0.17, 0.19), blood=0.4))),

    # 16. Opisina - corporate office worker in torn pale blue dress shirt, loose bloody red necktie, charcoal slacks, crooked glasses
    dict(name="opisina", sex="m", seed=223,
         shapes={"build": -0.15, "belly": 0.25, "nose_long": 0.35},
         tone=(0.76, 0.79, 0.70), hair="side_part", hair_col=(0.035, 0.030, 0.025),
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="neck_bite", veins=1.05),
         top=dict(kind="shirt", sleeve=0.68, torn_sleeve="R", color=(0.64, 0.74, 0.84), color2=(0.50, 0.60, 0.72),
                  pattern="button_placket", blood=1.05),
         bottom=dict(kind="pants", color=(0.12, 0.13, 0.15), blood=0.45),
         shoes=dict(style="dress", color=(0.05, 0.045, 0.045)),
         gear=dict(necktie=dict(color=(0.52, 0.08, 0.10), color2=(0.78, 0.66, 0.26), pattern="stripes_h", blood=1.1),
                   glasses=dict(color=(0.06, 0.06, 0.07), tilt=-0.10))),

    # 17. Bumbero - scorched firefighter / welder in charcoal high-vis turnout coat, cracked red-yellow hardhat, CHARRED skin!
    dict(name="bumbero", sex="m", seed=239,
         shapes={"build": 0.50, "muscle": 0.48, "brow_heavy": 0.75},
         tone=(0.42, 0.40, 0.39), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="charred", eye_style="milky", face_gore="ripped_cheek", veins=1.2),
         top=dict(kind="hoodie", sleeve=0.70, hem=0.88, color=(0.09, 0.095, 0.105), color2=(0.76, 0.82, 0.14),
                  pattern="hivis", scorch=True, blood=0.75),
         bottom=dict(kind="pants", loose=0.015, color=(0.09, 0.095, 0.105), color2=(0.76, 0.82, 0.14),
                     pattern="side_stripe", scorch=True, blood=0.55),
         shoes=dict(style="boot", color=(0.06, 0.06, 0.065)),
         gear=dict(hardhat=dict(color=(0.74, 0.14, 0.08), blood=0.55, scorch=True))),

    # 18. Sundalo - infected checkpoint soldier in woodland camo fatigues, tactical vest, utility belt, head bandage, combat boots
    dict(name="sundalo", sex="m", seed=251,
         shapes={"build": 0.42, "muscle": 0.62, "jaw_wide": 0.55, "brow_heavy": 0.6},
         tone=(0.70, 0.73, 0.72), hair="buzz_fade", hair_col=(0.028, 0.026, 0.024),
         horror=dict(decay="cyanotic", eye_style="hollow", face_gore="bruised_jaw", veins=1.15),
         top=dict(kind="shirt", sleeve=0.68, torn_sleeve="L", color=(0.24, 0.30, 0.18), color2=(0.14, 0.17, 0.10),
                  pattern="camo", blood=0.85),
         bottom=dict(kind="pants", loose=0.014, color=(0.22, 0.28, 0.17), color2=(0.13, 0.16, 0.10),
                     pattern="camo", blood=0.55),
         shoes=dict(style="boot", color=(0.07, 0.065, 0.055)),
         gear=dict(vest=dict(color=(0.14, 0.17, 0.12), blood=0.8),
                   belt=dict(color=(0.10, 0.11, 0.08), pouches=True),
                   head_bandage=dict(color=(0.72, 0.68, 0.60), eye_cover=False, blood=1.15))),

    # 19. Atleta - street basketball player, red/black jersey, matching athletic shorts, headband, curly hair, high-top sneakers
    dict(name="atleta", sex="m", seed=263,
         shapes={"muscle": 0.65, "build": 0.18, "belly": -0.25},
         tone=(0.74, 0.72, 0.74), hair="curly_afro", hair_col=(0.024, 0.022, 0.022),
         horror=dict(decay="cyanotic", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.1),
         top=dict(kind="sando", color=(0.64, 0.10, 0.12), color2=(0.08, 0.08, 0.09), pattern="jersey", blood=0.80),
         bottom=dict(kind="shorts", z0=0.48, loose=0.022, color=(0.09, 0.09, 0.10), color2=(0.64, 0.10, 0.12),
                     pattern="side_stripe", blood=0.45),
         shoes=dict(style="sneaker", color=(0.72, 0.14, 0.14)),
         gear=dict(headband=dict(color=(0.82, 0.80, 0.76), blood=0.85))),

    # 20. Lola - frail elderly grandmother in tattered pale lavender vintage nightgown, silver-white bun hair, gaunt morgue face
    dict(name="lola", sex="f", seed=277,
         shapes={"female": 1.0, "build": -0.48, "cheeks": -0.60, "chin_long": 0.35},
         tone=(0.74, 0.76, 0.82), hair="high_bun", hair_col=(0.55, 0.55, 0.56), grey_mix=0.92,
         horror=dict(decay="gaunt", eye_style="milky", face_gore="eye_bleed", veins=1.3),
         top=dict(kind="shirt", sleeve=0.52, hem=0.99, color=(0.56, 0.50, 0.64), color2=(0.76, 0.74, 0.80),
                  pattern="floral", blood=0.85),
         skirt=dict(z0=0.26, flare=0.085, ragged=True, color=(0.56, 0.50, 0.64), color2=(0.76, 0.74, 0.80),
                    pattern="floral", blood=0.85)),

    # 21. Lolo - frail elderly grandfather in torn bloodstained ivory Filipino Barong Tagalog, dark formal slacks, receding white hair
    dict(name="lolo", sex="m", seed=293,
         shapes={"build": -0.40, "cheeks": -0.55, "ears_size": 0.5, "nose_long": 0.45},
         tone=(0.76, 0.75, 0.72), hair="thinning_receding", hair_col=(0.58, 0.58, 0.56), grey_mix=0.95,
         horror=dict(decay="gaunt", eye_style="yellowed", face_gore="black_bile", veins=1.35),
         top=dict(kind="shirt", sleeve=0.68, hem=0.89, ragged=True, color=(0.82, 0.77, 0.64), color2=(0.66, 0.58, 0.42),
                  pattern="barong", blood=0.95),
         bottom=dict(kind="pants", color=(0.10, 0.10, 0.11), blood=0.45),
         shoes=dict(style="dress", side="R", color=(0.12, 0.08, 0.05))),

    # 22. Bata Hoodie - eerie street youth with tattered olive/charcoal HOOD UP shadowing dead pale eyes, ripped jeans
    dict(name="bata_hoodie", sex="m", seed=307,
         shapes={"build": -0.30, "cheeks": -0.35, "eyes_pop": 0.45},
         tone=(0.70, 0.74, 0.78), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="morgue", eye_style="milky", face_gore="black_bile", veins=1.15),
         top=dict(kind="hoodie", sleeve=0.70, hem=0.90, ragged=True, color=(0.16, 0.20, 0.15), blood=0.85),
         bottom=dict(kind="pants", torn_leg="R", color=(0.11, 0.13, 0.18), pattern="denim", blood=0.55),
         shoes=dict(style="sneaker", color=(0.15, 0.15, 0.17)),
         gear=dict(hood_up=dict(color=(0.16, 0.20, 0.15), blood=0.70))),

    # 23. Tulog - Filipino "White Lady" / sleepwalker horror: tattered blood-drenched white nightgown, matted long hair over face!
    dict(name="tulog", sex="f", seed=317,
         shapes={"female": 1.0, "build": -0.35, "cheeks": -0.50, "eyes_pop": 0.50},
         tone=(0.78, 0.80, 0.85), hair="long_disheveled", hair_col=(0.018, 0.016, 0.016),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="eye_bleed", veins=1.4, torso_gore=True),
         top=dict(kind="sando", hem=0.99, ragged=True, color=(0.84, 0.83, 0.80), blood=1.35),
         skirt=dict(z0=0.28, flare=0.09, ragged=True, color=(0.84, 0.83, 0.80), blood=1.25)),

    # 24. Tindero Vest - road-crew / barangay sweeper in neon-lime hi-vis vest over grey long-sleeve, cap, hanging mask, boots
    dict(name="tindero_vest", sex="m", seed=331,
         shapes={"belly": 0.45, "cheeks": 0.45, "brow_heavy": 0.55},
         tone=(0.74, 0.77, 0.66), hair="curtain_part", hair_col=(0.04, 0.035, 0.03),
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="chin_drip", veins=1.0),
         top=dict(kind="shirt", sleeve=0.66, color=(0.32, 0.33, 0.34), blood=0.65),
         bottom=dict(kind="pants", color=(0.16, 0.20, 0.26), pattern="denim", blood=0.55),
         shoes=dict(style="boot", color=(0.16, 0.12, 0.07)),
         gear=dict(vest=dict(color=(0.66, 0.84, 0.10), color2=(0.78, 0.80, 0.82), pattern="hivis", blood=0.75),
                   cap=dict(color=(0.16, 0.26, 0.14), backwards=False, blood=0.45),
                   face_mask=dict(color=(0.24, 0.26, 0.28), blood=0.95, hanging=True))),

    # 25. Biker - tough street rider, open black leather jacket over BARE bloody scarred chest, ripped jeans, boots, undercut quiff
    dict(name="biker", sex="m", seed=349,
         shapes={"build": 0.38, "muscle": 0.55, "jaw_wide": 0.55, "brow_heavy": 0.65},
         tone=(0.72, 0.74, 0.76), hair="undercut_quiff", hair_col=(0.03, 0.025, 0.022),
         horror=dict(decay="ashen", eye_style="asymmetric", face_gore="ripped_cheek", veins=1.25, torso_gore=True),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.93, color=(0.06, 0.06, 0.068), bare_chest=True,
                  pattern="leather", blood=0.75),
         bottom=dict(kind="pants", torn_leg="R", color=(0.08, 0.085, 0.10), pattern="denim", blood=0.55),
         shoes=dict(style="boot", color=(0.05, 0.045, 0.045)),
         gear=dict(belt=dict(color=(0.07, 0.065, 0.065), pouches=False))),

    # 26. Pormal - tattered office/party woman in burgundy blazer blouse, dark fitted pencil skirt, crooked glasses, twin pigtails, one missing shoe!
    dict(name="pormal", sex="f", seed=367,
         shapes={"female": 1.0, "lips_full": 0.5, "chin_long": 0.25},
         tone=(0.76, 0.77, 0.80), hair="twin_pigtails", hair_col=(0.06, 0.032, 0.024),
         horror=dict(decay="cyanotic", eye_style="bloodshot", face_gore="neck_bite", veins=1.1),
         top=dict(kind="shirt", sleeve=0.62, torn_sleeve="L", hem=0.98, color=(0.36, 0.08, 0.14), color2=(0.78, 0.74, 0.70),
                  pattern="button_placket", blood=0.90),
         skirt=dict(z0=0.50, flare=0.025, ragged=True, color=(0.08, 0.08, 0.10), blood=0.55),
         shoes=dict(style="dress", side="L", color=(0.06, 0.04, 0.05)),
         gear=dict(glasses=dict(color=(0.34, 0.08, 0.12), tilt=0.12))),

    # ---------------- 30 MORE BRAND-NEW UNIQUELY DRESSED CREEPY ZOMBIES (indices 27..56) ----------------

    # 27. Kusinero - infected restaurant chef in double-breasted white chef coat, checkered kitchen pants, tall chef toque hat!
    dict(name="kusinero", sex="m", seed=383,
         shapes={"belly": 0.62, "cheeks": 0.60, "jaw_wide": 0.45},
         tone=(0.76, 0.78, 0.70), hair="buzz_fade", hair_col=(0.03, 0.028, 0.026),
         horror=dict(decay="bloated", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.1),
         top=dict(kind="shirt", sleeve=0.64, hem=0.90, color=(0.86, 0.85, 0.82), color2=(0.12, 0.12, 0.13),
                  pattern="button_placket", blood=1.25),
         bottom=dict(kind="pants", color=(0.14, 0.14, 0.15), color2=(0.78, 0.78, 0.76), pattern="check", blood=0.65),
         shoes=dict(style="boot", color=(0.07, 0.07, 0.08)),
         gear=dict(chefs_hat=dict(color=(0.88, 0.87, 0.84), blood=0.75),
                   neck_scarf=dict(color=(0.58, 0.08, 0.10), blood=0.9))),

    # 28. Rider - food/parcel delivery courier in bright magenta/teal delivery jacket, cracked moto helmet, sling bag!
    dict(name="rider", sex="m", seed=397,
         shapes={"build": 0.12, "muscle": 0.28, "nose_wide": 0.4},
         tone=(0.72, 0.74, 0.72), hair="textured_crop", hair_col=(0.03, 0.025, 0.022),
         horror=dict(decay="ashen", eye_style="milky", face_gore="black_bile", veins=1.05),
         top=dict(kind="hoodie", sleeve=0.69, hem=0.92, color=(0.74, 0.12, 0.40), color2=(0.12, 0.14, 0.18),
                  pattern="delivery", blood=0.80),
         bottom=dict(kind="pants", color=(0.13, 0.17, 0.28), pattern="denim", blood=0.45),
         shoes=dict(style="sneaker", color=(0.18, 0.18, 0.20)),
         gear=dict(moto_helmet=dict(color=(0.12, 0.13, 0.15), color2=(0.78, 0.14, 0.42), blood=0.6),
                   sling_bag=dict(color=(0.10, 0.12, 0.14), blood=0.5))),

    # 29. Nobya - terrifying dead bride in tattered blood-drenched ivory lace gown & draping bridal veil!
    dict(name="nobya", sex="f", seed=409,
         shapes={"female": 1.0, "build": -0.28, "cheeks": -0.45, "eyes_pop": 0.45},
         tone=(0.80, 0.82, 0.86), hair="long_disheveled", hair_col=(0.024, 0.020, 0.018),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="eye_bleed", veins=1.35, torso_gore=True),
         top=dict(kind="sando", hem=0.99, ragged=True, color=(0.88, 0.86, 0.82), color2=(0.78, 0.75, 0.70),
                  pattern="barong", blood=1.35),
         skirt=dict(z0=0.18, flare=0.12, ragged=True, color=(0.88, 0.86, 0.82), blood=1.30),
         gear=dict(veil=dict(color=(0.86, 0.84, 0.80), z0=0.88, blood=0.85))),

    # 30. Guro - schoolteacher in open olive cardigan over cream blouse, pleated skirt, crooked glasses, crossbody sling bag
    dict(name="guro", sex="f", seed=421,
         shapes={"female": 1.0, "belly": 0.25, "cheeks": 0.2, "chin_long": 0.3},
         tone=(0.76, 0.79, 0.68), hair="high_bun", hair_col=(0.05, 0.042, 0.036), grey_mix=0.40,
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="neck_bite", veins=1.0),
         top=dict(kind="open_jacket", sleeve=0.64, hem=0.96, color=(0.34, 0.38, 0.20), under_color=(0.84, 0.80, 0.70),
                  blood=0.85),
         skirt=dict(z0=0.42, flare=0.06, pleats=True, color=(0.24, 0.18, 0.14), blood=0.50),
         shoes=dict(style="dress", color=(0.14, 0.10, 0.08)),
         gear=dict(glasses=dict(color=(0.18, 0.12, 0.08), tilt=-0.11),
                   sling_bag=dict(color=(0.36, 0.22, 0.12), blood=0.4))),

    # 31. Mangingisda - drowned coastal fisherman in soaked bright yellow raincoat, bucket hat, green rubber rain boots!
    dict(name="mangingisda", sex="m", seed=433,
         shapes={"build": 0.28, "muscle": 0.35, "brow_heavy": 0.65, "cheeks": 0.3},
         tone=(0.62, 0.68, 0.78), hair="wavy_shag", hair_col=(0.04, 0.038, 0.035), grey_mix=0.35,
         horror=dict(decay="cyanotic", eye_style="hollow", face_gore="black_bile", veins=1.3),
         top=dict(kind="hoodie", sleeve=0.69, hem=0.90, color=(0.80, 0.66, 0.09), blood=0.75),
         bottom=dict(kind="pants", color=(0.14, 0.16, 0.18), blood=0.55),
         shoes=dict(style="boot", color=(0.12, 0.24, 0.14)),
         gear=dict(coat_tail=dict(z0=0.54, open_front=True, color=(0.80, 0.66, 0.09), blood=0.85, ragged=True),
                   bucket_hat=dict(color=(0.76, 0.62, 0.10), blood=0.50))),

    # 32. Karpintero - carpenter / foreman in red/black flannel plaid shirt (torn sleeve), denim jeans, yellow hardhat, tool belt
    dict(name="karpintero", sex="m", seed=449,
         shapes={"build": 0.45, "muscle": 0.52, "jaw_wide": 0.60},
         tone=(0.74, 0.73, 0.68), hair="side_part", hair_col=(0.04, 0.034, 0.028),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.1),
         top=dict(kind="shirt", sleeve=0.68, torn_sleeve="L", color=(0.56, 0.10, 0.10), color2=(0.08, 0.08, 0.09),
                  pattern="plaid", blood=0.85),
         bottom=dict(kind="pants", color=(0.16, 0.22, 0.34), pattern="denim", blood=0.55),
         shoes=dict(style="boot", color=(0.24, 0.15, 0.08)),
         gear=dict(hardhat=dict(color=(0.86, 0.70, 0.08), blood=0.65),
                   belt=dict(color=(0.26, 0.16, 0.08), pouches=True))),

    # 33. Negosyante - banker / lawyer in tattered charcoal pinstripe suit, gold-striped necktie, dress shoes, slicked hair
    dict(name="negosyante", sex="m", seed=461,
         shapes={"belly": 0.32, "cheeks": 0.45, "nose_long": 0.4},
         tone=(0.74, 0.77, 0.80), hair="slick_back", hair_col=(0.035, 0.032, 0.030), grey_mix=0.30,
         horror=dict(decay="morgue", eye_style="milky", face_gore="neck_bite", veins=1.1),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.89, color=(0.10, 0.11, 0.14), color2=(0.36, 0.38, 0.42),
                  under_color=(0.82, 0.83, 0.84), pattern="pinstripe", blood=0.95),
         bottom=dict(kind="pants", color=(0.10, 0.11, 0.14), color2=(0.36, 0.38, 0.42), pattern="pinstripe", blood=0.45),
         shoes=dict(style="dress", color=(0.04, 0.04, 0.045)),
         gear=dict(necktie=dict(color=(0.10, 0.16, 0.38), color2=(0.82, 0.68, 0.22), pattern="stripes_h", blood=1.0))),

    # 34. Jogger - early-morning runner in neon-coral striped track jacket, dark leggings, bright sneakers, headband, ponytail
    dict(name="jogger", sex="f", seed=479,
         shapes={"female": 1.0, "build": -0.18, "muscle": 0.25},
         tone=(0.76, 0.74, 0.74), hair="ponytail", hair_col=(0.04, 0.03, 0.024),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="chin_drip", veins=1.0),
         top=dict(kind="shirt", sleeve=0.68, color=(0.82, 0.26, 0.24), color2=(0.88, 0.88, 0.86),
                  pattern="track_stripe", blood=0.85),
         bottom=dict(kind="pants", color=(0.08, 0.09, 0.11), color2=(0.86, 0.86, 0.84), pattern="side_stripe", blood=0.40),
         shoes=dict(style="sneaker", color=(0.20, 0.72, 0.66)),
         gear=dict(headband=dict(color=(0.88, 0.30, 0.26), blood=0.6))),

    # 35. Boxer - SHIRTLESS muscular street fighter with deep torso claw slashes, boxing shorts, bloody head bandage, barefoot!
    dict(name="boxer", sex="m", seed=491,
         shapes={"muscle": 0.88, "build": 0.48, "belly": -0.35, "jaw_wide": 0.65, "brow_heavy": 0.7},
         tone=(0.74, 0.70, 0.68), hair="curly_afro", hair_col=(0.025, 0.022, 0.020),
         horror=dict(decay="cyanotic", eye_style="asymmetric", face_gore="ripped_cheek", veins=1.35, torso_gore=True),
         top=dict(kind="shirtless"),
         bottom=dict(kind="shorts", z0=0.49, loose=0.026, color=(0.68, 0.08, 0.10), color2=(0.88, 0.74, 0.18),
                     pattern="side_stripe", blood=0.85),
         gear=dict(head_bandage=dict(color=(0.82, 0.80, 0.74), eye_cover=False, blood=1.35))),

    # 36. Madre - terrifying infected nun in full black habit, white bib collar & dark veil framing hollow weeping eyes!
    dict(name="madre", sex="f", seed=503,
         shapes={"female": 1.0, "build": -0.25, "cheeks": -0.55, "chin_long": 0.35},
         tone=(0.76, 0.78, 0.84), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="eye_bleed", veins=1.25),
         top=dict(kind="shirt", sleeve=0.69, hem=1.0, color=(0.05, 0.05, 0.06), color2=(0.86, 0.86, 0.84),
                  pattern="chest_band", blood=0.75),
         shoes=dict(style="dress", color=(0.04, 0.04, 0.045)),
         gear=dict(coat_tail=dict(z0=0.18, open_front=False, color=(0.05, 0.05, 0.06), blood=0.70, ragged=True),
                   clerical_collar=dict(color=(0.84, 0.83, 0.80)),
                   veil=dict(color=(0.05, 0.05, 0.065), z0=1.08, blood=0.45))),

    # 37. Guwardiya - mall/bank security guard in crisp pale-blue uniform shirt, dark slacks, cap, utility belt, torn sleeve
    dict(name="guwardiya", sex="m", seed=521,
         shapes={"belly": 0.38, "build": 0.35, "jaw_wide": 0.50},
         tone=(0.74, 0.75, 0.70), hair="buzz_fade", hair_col=(0.03, 0.028, 0.026),
         horror=dict(decay="jaundiced", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.0),
         top=dict(kind="shirt", sleeve=0.38, torn_sleeve="L", color=(0.54, 0.68, 0.82), color2=(0.08, 0.12, 0.24),
                  pattern="button_placket", blood=0.80),
         bottom=dict(kind="pants", color=(0.07, 0.09, 0.16), blood=0.45),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(cap=dict(color=(0.07, 0.10, 0.22), backwards=False, blood=0.35),
                   belt=dict(color=(0.05, 0.05, 0.055), pouches=True))),

    # 38. Turista - lost tourist in loud teal/orange tropical batik open shirt, khaki cargo shorts, bucket hat, crooked glasses, 1 shoe!
    dict(name="turista", sex="m", seed=541,
         shapes={"belly": 0.55, "cheeks": 0.5, "ears_out": 0.4},
         tone=(0.80, 0.74, 0.68), hair="curtain_part", hair_col=(0.24, 0.16, 0.09),
         horror=dict(decay="bloated", eye_style="yellowed", face_gore="chin_drip", veins=0.95),
         top=dict(kind="open_jacket", sleeve=0.38, hem=0.92, color=(0.12, 0.56, 0.56), color2=(0.88, 0.44, 0.14),
                  under_color=(0.82, 0.80, 0.74), pattern="batik", blood=0.85),
         bottom=dict(kind="shorts", z0=0.46, loose=0.020, color=(0.48, 0.42, 0.30), blood=0.45),
         shoes=dict(style="sneaker", side="R", color=(0.70, 0.68, 0.64)),
         gear=dict(bucket_hat=dict(color=(0.48, 0.44, 0.34), blood=0.45),
                   glasses=dict(color=(0.06, 0.06, 0.06), tilt=0.14))),

    # 39. Janitor - building custodian in olive-grey utility coveralls, backwards cap, hanging surgical mask, rubber boots
    dict(name="janitor", sex="m", seed=557,
         shapes={"build": -0.25, "cheeks": -0.40, "nose_long": 0.45},
         tone=(0.74, 0.78, 0.66), hair="thinning_receding", hair_col=(0.16, 0.16, 0.15), grey_mix=0.65,
         horror=dict(decay="gaunt", eye_style="yellowed", face_gore="black_bile", veins=1.2),
         top=dict(kind="coveralls", sleeve=0.66, color=(0.26, 0.30, 0.25), color2=(0.56, 0.58, 0.48),
                  pattern="chest_band", grease=True, blood=0.85),
         bottom=dict(kind="pants", color=(0.26, 0.30, 0.25), grease=True, blood=0.60),
         shoes=dict(style="boot", color=(0.08, 0.09, 0.08)),
         gear=dict(cap=dict(color=(0.20, 0.24, 0.20), backwards=True, blood=0.4),
                   face_mask=dict(color=(0.60, 0.72, 0.74), blood=0.95, hanging=True))),

    # 40. Panadero - neighborhood baker in flour/blood-coated apron over pale tee, striped pants, knit beanie, bloated face
    dict(name="panadero", sex="m", seed=569,
         shapes={"belly": 0.70, "cheeks": 0.70, "build": 0.30},
         tone=(0.80, 0.80, 0.74), hair="buzz_fade", hair_col=(0.04, 0.036, 0.032),
         horror=dict(decay="bloated", eye_style="milky", face_gore="chin_drip", veins=1.0),
         top=dict(kind="shirt", sleeve=0.35, color=(0.82, 0.80, 0.76), blood=0.90),
         bottom=dict(kind="pants", color=(0.22, 0.26, 0.34), color2=(0.76, 0.76, 0.74), pattern="stripes_v", blood=0.55),
         shoes=dict(style="sneaker", color=(0.64, 0.62, 0.58)),
         gear=dict(apron=dict(color=(0.86, 0.84, 0.78), blood=1.25),
                   beanie=dict(color=(0.76, 0.74, 0.70), blood=0.55))),

    # 41. Labandera - laundrywoman in faded teal polka-dot blouse, knee-length wrap skirt, headband, high bun, barefoot
    dict(name="labandera", sex="f", seed=587,
         shapes={"female": 1.0, "belly": 0.35, "rear": 0.45},
         tone=(0.72, 0.75, 0.74), hair="high_bun", hair_col=(0.03, 0.028, 0.025), grey_mix=0.20,
         horror=dict(decay="ashen", eye_style="asymmetric", face_gore="neck_bite", veins=1.1),
         top=dict(kind="shirt", sleeve=0.32, hem=0.98, color=(0.18, 0.46, 0.50), color2=(0.86, 0.84, 0.76),
                  pattern="polka", blood=0.80),
         skirt=dict(z0=0.46, flare=0.05, ragged=True, color=(0.36, 0.18, 0.24), color2=(0.74, 0.62, 0.44),
                    pattern="batik", blood=0.65),
         gear=dict(headband=dict(color=(0.74, 0.24, 0.22), blood=0.55))),

    # 42. Kolehiyala - female college student in oversized burgundy HOOD UP, short plaid skirt, backpack, white sneakers!
    dict(name="kolehiyala", sex="f", seed=601,
         shapes={"female": 1.0, "build": -0.20, "lips_full": 0.45},
         tone=(0.74, 0.76, 0.80), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="morgue", eye_style="bloodshot", face_gore="black_bile", veins=1.1),
         top=dict(kind="hoodie", sleeve=0.68, hem=0.94, ragged=True, color=(0.42, 0.10, 0.16), blood=0.85),
         skirt=dict(z0=0.56, flare=0.07, pleats=True, color=(0.12, 0.12, 0.16), color2=(0.56, 0.18, 0.22),
                    pattern="plaid", blood=0.50),
         shoes=dict(style="sneaker", color=(0.78, 0.77, 0.74)),
         gear=dict(hood_up=dict(color=(0.42, 0.10, 0.16), blood=0.65),
                   backpack=dict(color=(0.12, 0.14, 0.18), blood=0.45))),

    # 43. Skater - street punk in black/white striped skate tee, baggy torn khaki shorts, beanie + wavy shag, red sneakers
    dict(name="skater", sex="m", seed=613,
         shapes={"build": -0.25, "belly": -0.20, "ears_out": 0.45},
         tone=(0.74, 0.76, 0.74), hair="wavy_shag", hair_col=(0.06, 0.035, 0.025),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.05),
         top=dict(kind="shirt", sleeve=0.44, ragged=True, color=(0.08, 0.08, 0.09), color2=(0.82, 0.82, 0.80),
                  pattern="stripes_h", blood=0.85),
         bottom=dict(kind="shorts", z0=0.44, loose=0.032, color=(0.42, 0.36, 0.26), blood=0.55),
         shoes=dict(style="sneaker", color=(0.68, 0.10, 0.12)),
         gear=dict(beanie=dict(color=(0.52, 0.12, 0.12), blood=0.45))),

    # 44. Barbero - neighborhood barber in crisp white button shirt, vintage suspenders, dark slacks, crooked glasses, throat bite
    dict(name="barbero", sex="m", seed=631,
         shapes={"build": 0.10, "nose_long": 0.35, "chin_long": 0.35},
         tone=(0.76, 0.78, 0.74), hair="side_part", hair_col=(0.05, 0.045, 0.04), grey_mix=0.45,
         horror=dict(decay="morgue", eye_style="milky", face_gore="neck_bite", veins=1.15),
         top=dict(kind="shirt", sleeve=0.46, color=(0.84, 0.83, 0.79), pattern="button_placket", blood=1.15),
         bottom=dict(kind="pants", color=(0.14, 0.12, 0.12), color2=(0.28, 0.26, 0.25), pattern="pinstripe", blood=0.45),
         shoes=dict(style="dress", color=(0.14, 0.09, 0.06)),
         gear=dict(suspenders=dict(color=(0.48, 0.10, 0.12), blood=0.85),
                   glasses=dict(color=(0.12, 0.12, 0.12), tilt=0.09))),

    # 45. Magsasaka - rice/farm laborer in faded brown torn long-sleeve shirt, ripped muddy pant leg, salakot hat, neck scarf, barefoot
    dict(name="magsasaka", sex="m", seed=647,
         shapes={"build": -0.15, "muscle": 0.42, "cheeks": -0.35},
         tone=(0.68, 0.64, 0.56), hair="textured_crop", hair_col=(0.03, 0.026, 0.022), grey_mix=0.35,
         horror=dict(decay="gaunt", eye_style="yellowed", face_gore="chin_drip", veins=1.2),
         top=dict(kind="shirt", sleeve=0.68, torn_sleeve="R", ragged=True, color=(0.42, 0.32, 0.22), blood=0.80),
         bottom=dict(kind="pants", torn_leg="L", color=(0.22, 0.19, 0.15), blood=0.65),
         gear=dict(salakot=dict(color=(0.54, 0.42, 0.22), pattern="woven", blood=0.45),
                   neck_scarf=dict(color=(0.56, 0.14, 0.12), pattern="check", blood=0.75))),

    # 46. Pulis SWAT - heavy tactical responder in all-black fatigues, heavy vest, utility belt, black tactical helmet, bloody mask!
    dict(name="pulis_swat", sex="m", seed=659,
         shapes={"build": 0.60, "muscle": 0.68, "jaw_wide": 0.65, "brow_heavy": 0.75},
         tone=(0.64, 0.66, 0.68), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="charred", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.2),
         top=dict(kind="shirt", sleeve=0.69, color=(0.06, 0.065, 0.075), blood=0.75),
         bottom=dict(kind="pants", loose=0.016, color=(0.055, 0.06, 0.07), blood=0.55),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(vest=dict(color=(0.09, 0.095, 0.105), blood=0.90),
                   belt=dict(color=(0.05, 0.05, 0.055), pouches=True),
                   hardhat=dict(color=(0.06, 0.065, 0.075), blood=0.65),
                   face_mask=dict(color=(0.08, 0.08, 0.09), blood=1.1, hanging=False))),

    # 47. Mayaman - wealthy party socialite in tattered deep emerald evening gown, long chestnut hair, gouged eye, 1 lost shoe!
    dict(name="mayaman", sex="f", seed=673,
         shapes={"female": 1.0, "build": -0.18, "lips_full": 0.6},
         tone=(0.78, 0.80, 0.84), hair="long_straight", hair_col=(0.14, 0.075, 0.045),
         horror=dict(decay="morgue", eye_style="asymmetric", face_gore="eye_bleed", veins=1.15),
         top=dict(kind="sando", hem=0.99, color=(0.06, 0.36, 0.24), blood=0.95),
         skirt=dict(z0=0.20, flare=0.10, ragged=True, color=(0.06, 0.36, 0.24), blood=0.90),
         shoes=dict(style="dress", side="R", color=(0.68, 0.56, 0.24))),

    # 48. Tricycle - night dispatcher wearing neon-orange hi-vis safety vest over SHIRTLESS scarred torso, denim shorts, cap, barefoot!
    dict(name="tricycle", sex="m", seed=691,
         shapes={"belly": 0.45, "muscle": 0.35, "cheeks": 0.45},
         tone=(0.70, 0.72, 0.76), hair="buzz_fade", hair_col=(0.03, 0.028, 0.025),
         horror=dict(decay="cyanotic", eye_style="milky", face_gore="neck_bite", veins=1.25, torso_gore=True),
         top=dict(kind="shirtless"),
         bottom=dict(kind="shorts", z0=0.47, loose=0.015, color=(0.16, 0.22, 0.34), pattern="denim", blood=0.55),
         gear=dict(vest=dict(color=(0.86, 0.34, 0.06), color2=(0.80, 0.82, 0.82), pattern="hivis", blood=0.85),
                   cap=dict(color=(0.10, 0.14, 0.22), backwards=False, blood=0.4))),

    # 49. Kargador - muscular port/market porter, SHIRTLESS rotting bruised chest, draped neck towel/scarf, ripped muddy pants, boots!
    dict(name="kargador", sex="m", seed=709,
         shapes={"muscle": 0.78, "build": 0.55, "jaw_wide": 0.6, "brow_heavy": 0.65},
         tone=(0.68, 0.66, 0.62), hair="textured_spiky", hair_col=(0.028, 0.025, 0.022),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.3, torso_gore=True),
         top=dict(kind="shirtless"),
         bottom=dict(kind="pants", torn_leg="R", color=(0.18, 0.17, 0.14), blood=0.65),
         shoes=dict(style="boot", color=(0.10, 0.08, 0.06)),
         gear=dict(neck_scarf=dict(color=(0.76, 0.74, 0.68), blood=1.15))),

    # 50. Pasyente F - female ICU escapee in torn pale-mint hospital gown, bloody forehead bandage, patchy rotted hair, barefoot!
    dict(name="pasyente_f", sex="f", seed=727,
         shapes={"female": 1.0, "build": -0.52, "cheeks": -0.62, "eyes_pop": 0.55},
         tone=(0.72, 0.78, 0.82), hair="patchy_rotted", hair_col=(0.03, 0.026, 0.024),
         horror=dict(decay="gaunt", eye_style="hollow", face_gore="eye_bleed", veins=1.4, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.38, hem=0.98, color=(0.64, 0.80, 0.74), color2=(0.42, 0.60, 0.54),
                  pattern="hospital", blood=1.10),
         skirt=dict(z0=0.45, flare=0.06, ragged=True, color=(0.64, 0.80, 0.74), color2=(0.42, 0.60, 0.54),
                    pattern="hospital", blood=1.05),
         gear=dict(head_bandage=dict(color=(0.80, 0.78, 0.72), eye_cover=False, blood=1.35))),

    # 51. Estudyante M - male high-school student in bloody white school polo, navy slacks, backpack, curtain-part hair, black bile
    dict(name="estudyante_m", sex="m", seed=743,
         shapes={"build": -0.28, "belly": -0.20, "chin_long": 0.25},
         tone=(0.74, 0.78, 0.78), hair="curtain_part", hair_col=(0.025, 0.022, 0.020),
         horror=dict(decay="morgue", eye_style="milky", face_gore="black_bile", veins=1.05),
         top=dict(kind="shirt", sleeve=0.36, color=(0.84, 0.83, 0.80), pattern="button_placket", blood=1.0),
         bottom=dict(kind="pants", color=(0.08, 0.11, 0.22), blood=0.40),
         shoes=dict(style="dress", color=(0.04, 0.04, 0.045)),
         gear=dict(backpack=dict(color=(0.14, 0.24, 0.42), blood=0.55))),

    # 52. Tinderong Isda - wet-market fishmonger in green striped shirt, soaked navy rubber butcher apron, tall yellow rain boots, bald!
    dict(name="tinderong_isda", sex="m", seed=757,
         shapes={"belly": 0.52, "build": 0.35, "nose_wide": 0.55},
         tone=(0.74, 0.78, 0.64), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="chin_drip", veins=1.2),
         top=dict(kind="shirt", sleeve=0.35, color=(0.24, 0.48, 0.30), color2=(0.78, 0.80, 0.72),
                  pattern="stripes_h", blood=0.95),
         bottom=dict(kind="shorts", z0=0.46, loose=0.020, color=(0.14, 0.16, 0.20), blood=0.60),
         shoes=dict(style="boot", color=(0.80, 0.66, 0.10)),
         gear=dict(apron=dict(color=(0.10, 0.18, 0.34), blood=1.35))),

    # 53. Musikero - street rocker in open dark purple/black jacket over graphic tee, ripped black jeans, combat boots, long wild hair, scarf
    dict(name="musikero", sex="m", seed=773,
         shapes={"build": -0.22, "cheeks": -0.35, "chin_long": 0.35},
         tone=(0.74, 0.74, 0.78), hair="long_disheveled", hair_col=(0.028, 0.022, 0.024),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="ripped_cheek", veins=1.2),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=(0.16, 0.08, 0.20), under_color=(0.12, 0.12, 0.14),
                  pattern="leather", blood=0.80),
         bottom=dict(kind="pants", torn_leg="L", color=(0.07, 0.07, 0.08), pattern="denim", blood=0.55),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.055)),
         gear=dict(neck_scarf=dict(color=(0.48, 0.10, 0.16), pattern="stripes_h", blood=0.75))),

    # 54. Mananahi - seamstress / tailor in vintage red/cream plaid dress, crooked glasses, yellow measuring tape around neck, grey chin bob
    dict(name="mananahi", sex="f", seed=787,
         shapes={"female": 1.0, "belly": 0.30, "cheeks": 0.35},
         tone=(0.74, 0.76, 0.76), hair="chin_bob", hair_col=(0.12, 0.11, 0.10), grey_mix=0.55,
         horror=dict(decay="ashen", eye_style="milky", face_gore="eye_bleed", veins=1.1),
         top=dict(kind="shirt", sleeve=0.54, hem=0.99, color=(0.56, 0.16, 0.18), color2=(0.82, 0.76, 0.62),
                  pattern="plaid", blood=0.85),
         skirt=dict(z0=0.38, flare=0.075, color=(0.56, 0.16, 0.18), color2=(0.82, 0.76, 0.62), pattern="plaid", blood=0.75),
         shoes=dict(style="dress", color=(0.14, 0.10, 0.08)),
         gear=dict(glasses=dict(color=(0.28, 0.18, 0.10), tilt=-0.12),
                   stethoscope=dict(color=(0.86, 0.74, 0.14), measure_tape=True))),

    # 55. Bombero F - EMS paramedic woman in royal-blue hi-vis EMS jacket, dark cargo pants, utility belt, stethoscope, ponytail!
    dict(name="bombero_f", sex="f", seed=809,
         shapes={"female": 1.0, "muscle": 0.35, "build": 0.10},
         tone=(0.70, 0.72, 0.74), hair="ponytail", hair_col=(0.032, 0.026, 0.022),
         horror=dict(decay="cyanotic", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.15),
         top=dict(kind="shirt", sleeve=0.68, color=(0.08, 0.22, 0.56), color2=(0.80, 0.86, 0.16),
                  pattern="hivis", blood=0.95),
         bottom=dict(kind="pants", loose=0.012, color=(0.07, 0.10, 0.18), blood=0.55),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.055)),
         gear=dict(belt=dict(color=(0.06, 0.06, 0.07), pouches=True),
                   stethoscope=dict(color=(0.14, 0.16, 0.22)))),

    # 56. Biktima Sunog - house-fire burn victim in shredded soot-blackened rags, singed patchy hair, severely CHARRED blistered skin!
    dict(name="biktima_sunog", sex="m", seed=823,
         shapes={"build": -0.38, "cheeks": -0.58, "eyes_pop": 0.65},
         tone=(0.36, 0.33, 0.32), hair="patchy_rotted", hair_col=(0.04, 0.035, 0.03),
         horror=dict(decay="charred", eye_style="milky", face_gore="ripped_cheek", veins=1.4, torso_gore=True),
         top=dict(kind="sando", hem=0.96, ragged=True, color=(0.14, 0.13, 0.12), scorch=True, blood=1.15),
         bottom=dict(kind="pants", torn_leg="R", color=(0.12, 0.11, 0.10), scorch=True, blood=0.85)),

    # ---------------- 0.50: Prof. Ivan Lawrence College of Science and Technology (PILCST) students ----------------
    # One uniform for all: white PILCST polo / blouse with the maroon-and-gold crest, maroon necktie, navy slacks or
    # navy pleated skirt, black school shoes. Senior high and college, 16 to 21. What differs is the person.

    # 57. M1 - thin STEM boy, curtain fringe, glasses knocked crooked, navy backpack, black bile down the chin
    dict(name="pilcst_m1", sex="m", seed=1201,
         shapes={"build": -0.34, "belly": -0.25, "chin_long": 0.30},
         tone=(0.74, 0.77, 0.78), hair="curtain_part", hair_col=(0.024, 0.021, 0.020),
         horror=dict(decay="morgue", eye_style="milky", face_gore="black_bile", veins=1.05),
         top=dict(kind="shirt", sleeve=0.36, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=0.95),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.45),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.9),
                   glasses=dict(color=(0.08, 0.08, 0.09), tilt=0.14),
                   backpack=dict(color=(0.10, 0.16, 0.34), blood=0.5))),

    # 58. M2 - varsity player, buzz cut, sleeve torn off, cheek ripped open, soaked to the waist
    dict(name="pilcst_m2", sex="m", seed=1217,
         shapes={"build": 0.25, "muscle": 0.55, "jaw_wide": 0.40},
         tone=(0.70, 0.70, 0.68), hair="buzz_fade", hair_col=(0.03, 0.026, 0.024),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.2),
         top=dict(kind="shirt", sleeve=0.36, torn_sleeve="R", ragged=True, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.05),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.7),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=1.2))),

    # 59. M3 - heavyset ICT boy, neat side part, sling bag still across him, bitten at the neck
    dict(name="pilcst_m3", sex="m", seed=1229,
         shapes={"belly": 0.55, "build": 0.30, "cheeks": 0.55, "nose_wide": 0.35},
         tone=(0.70, 0.75, 0.80), hair="side_part", hair_col=(0.03, 0.025, 0.022),
         horror=dict(decay="cyanotic", eye_style="yellowed", face_gore="neck_bite", veins=1.15),
         top=dict(kind="shirt", sleeve=0.36, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.05),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.5),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.8),
                   sling_bag=dict(color=(0.08, 0.08, 0.09), blood=0.6))),

    # 60. M4 - lanky senior, undercut quiff, left trouser leg torn open, bleeding from the eyes, gaunt
    dict(name="pilcst_m4", sex="m", seed=1237,
         shapes={"build": -0.20, "cheeks": -0.50, "nose_long": 0.40, "chin_long": 0.40},
         tone=(0.72, 0.74, 0.72), hair="undercut_quiff", hair_col=(0.035, 0.028, 0.024),
         horror=dict(decay="gaunt", eye_style="hollow", face_gore="eye_bleed", veins=1.25),
         top=dict(kind="shirt", sleeve=0.36, ragged=True, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=0.9),
         bottom=dict(kind="pants", torn_leg="L", color=(0.06, 0.08, 0.18), blood=0.6),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.7))),

    # 61. M5 - spiky-haired freshman, jaw caved in, one shoe gone, shirt torn open over a bitten chest
    dict(name="pilcst_m5", sex="m", seed=1249,
         shapes={"build": -0.10, "ears_out": 0.40, "brow_heavy": 0.30},
         tone=(0.74, 0.72, 0.62), hair="textured_spiky", hair_col=(0.028, 0.024, 0.021),
         horror=dict(decay="jaundiced", eye_style="asymmetric", face_gore="bruised_jaw", veins=1.3, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.36, torn_sleeve="L", ragged=True, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=0.95),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), blood=0.55),
         shoes=dict(style="dress", side="R", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=1.0))),

    # 62. F1 - long straight hair over the face, eyes bleeding, backpack, plaid skirt soaked dark
    dict(name="pilcst_f1", sex="f", seed=1301,
         shapes={"female": 0.95, "build": -0.25, "chin_long": 0.20},
         tone=(0.76, 0.79, 0.80), hair="long_straight", hair_col=(0.022, 0.019, 0.018),
         horror=dict(decay="morgue", eye_style="hollow", face_gore="eye_bleed", veins=1.1),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.0),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.6),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.9),
                   backpack=dict(color=(0.36, 0.08, 0.12), blood=0.45))),

    # 63. F2 - ponytail, glasses, cheek torn, the class president's neat blouse ruined
    dict(name="pilcst_f2", sex="f", seed=1319,
         shapes={"female": 1.0, "build": -0.15, "lips_full": 0.30},
         tone=(0.72, 0.72, 0.70), hair="ponytail", hair_col=(0.03, 0.024, 0.02),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.15),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.2),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.7),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=1.1),
                   glasses=dict(color=(0.30, 0.12, 0.14), tilt=-0.10))),

    # 64. F3 - short bob, sling bag, bitten at the neck, blue-lipped
    dict(name="pilcst_f3", sex="f", seed=1327,
         shapes={"female": 0.9, "belly": 0.15, "cheeks": 0.30},
         tone=(0.70, 0.76, 0.82), hair="chin_bob", hair_col=(0.026, 0.022, 0.02),
         horror=dict(decay="cyanotic", eye_style="milky", face_gore="neck_bite", veins=1.2),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.05),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.55),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.8),
                   sling_bag=dict(color=(0.55, 0.50, 0.44), blood=0.7))),

    # 65. F4 - hair up in a bun, thin and yellowed, black bile, sleeve torn
    dict(name="pilcst_f4", sex="f", seed=1361,
         shapes={"female": 1.0, "build": -0.45, "cheeks": -0.45, "eyes_pop": 0.35},
         tone=(0.74, 0.74, 0.64), hair="high_bun", hair_col=(0.03, 0.025, 0.021),
         horror=dict(decay="gaunt", eye_style="yellowed", face_gore="black_bile", veins=1.3),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, torn_sleeve="L", ragged=True, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=0.95),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, ragged=True, color=(0.045, 0.055, 0.13), blood=0.65),
         shoes=dict(style="dress", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.9))),

    # 66. F5 - long tangled hair, jaw broken, one shoe lost on the stairs, chest torn
    dict(name="pilcst_f5", sex="f", seed=1373,
         shapes={"female": 0.95, "build": -0.05, "jaw_wide": 0.25},
         tone=(0.78, 0.78, 0.80), hair="long_disheveled", hair_col=(0.02, 0.018, 0.018),
         horror=dict(decay="morgue", eye_style="asymmetric", face_gore="bruised_jaw", veins=1.2, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, ragged=True, color=(0.86, 0.85, 0.82), pattern="pilcst", blood=1.3),
         skirt=dict(z0=0.52, flare=0.06, pleats=True, color=(0.045, 0.055, 0.13), blood=0.8),
         shoes=dict(style="dress", side="L", color=(0.035, 0.035, 0.04)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=1.2))),

    # ---------------- 0.51: PILCST faculty and staff ----------------
    # The teachers kept their classes in the rooms when the suspension memo came round; the maintenance staff were
    # the ones sent to check the noise. Faculty wear the school's maroon (the women's blazer, the men's tie).

    # 67. Teacher M1 - Sir Abad, math: pale blue long sleeves rolled, maroon tie, grey slacks, glasses, thinning grey
    dict(name="teacher_m1", sex="m", seed=1401,
         shapes={"belly": 0.50, "build": 0.10, "cheeks": 0.30},
         tone=(0.72, 0.74, 0.70), hair="thinning_receding", hair_col=(0.06, 0.055, 0.05), grey_mix=0.50,
         horror=dict(decay="ashen", eye_style="milky", face_gore="neck_bite", veins=1.1),
         top=dict(kind="shirt", sleeve=0.66, color=(0.62, 0.72, 0.84), pattern="button_placket", blood=1.0),
         bottom=dict(kind="pants", color=(0.26, 0.26, 0.28), blood=0.5),
         shoes=dict(style="dress", color=(0.06, 0.04, 0.03)),
         gear=dict(necktie=dict(color=(0.40, 0.05, 0.08), blood=0.9),
                   glasses=dict(color=(0.12, 0.10, 0.08), tilt=0.08))),

    # 68. Teacher M2 - Sir Villaflor, Filipino: Monday barong torn open at the shoulder, black slacks, slick hair
    dict(name="teacher_m2", sex="m", seed=1409,
         shapes={"build": -0.10, "chin_long": 0.30, "nose_long": 0.25},
         tone=(0.74, 0.72, 0.66), hair="slick_back", hair_col=(0.03, 0.026, 0.022), grey_mix=0.20,
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="ripped_cheek", veins=1.2),
         top=dict(kind="shirt", sleeve=0.68, hem=0.89, ragged=True, torn_sleeve="L", color=(0.84, 0.80, 0.68),
                  color2=(0.68, 0.60, 0.44), pattern="barong", blood=1.2),
         bottom=dict(kind="pants", color=(0.07, 0.07, 0.08), blood=0.55),
         shoes=dict(style="dress", color=(0.05, 0.04, 0.03))),

    # 69. Teacher M3 - Coach Dimaculangan, P.E.: maroon track jacket with gold stripes, navy track pants, buzz cut
    dict(name="teacher_m3", sex="m", seed=1423,
         shapes={"build": 0.35, "muscle": 0.45, "belly": 0.25, "jaw_wide": 0.35},
         tone=(0.70, 0.70, 0.66), hair="buzz_fade", hair_col=(0.03, 0.026, 0.024), grey_mix=0.25,
         horror=dict(decay="gaunt", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.25, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.68, ragged=True, color=(0.40, 0.06, 0.09), color2=(0.78, 0.62, 0.20),
                  pattern="track_stripe", blood=1.0),
         bottom=dict(kind="pants", color=(0.06, 0.08, 0.18), color2=(0.78, 0.62, 0.20), pattern="side_stripe", blood=0.6),
         shoes=dict(style="sneaker", color=(0.86, 0.86, 0.84))),

    # 70. Teacher F1 - Ma'am Teves's co-adviser: maroon faculty blazer over a cream blouse, pencil skirt, bun, glasses
    dict(name="teacher_f1", sex="f", seed=1433,
         shapes={"female": 1.0, "belly": 0.20, "cheeks": 0.20},
         tone=(0.76, 0.76, 0.72), hair="high_bun", hair_col=(0.04, 0.032, 0.028), grey_mix=0.25,
         horror=dict(decay="morgue", eye_style="milky", face_gore="neck_bite", veins=1.1),
         top=dict(kind="open_jacket", sleeve=0.66, hem=0.94, color=(0.40, 0.06, 0.09), under_color=(0.86, 0.82, 0.72),
                  blood=0.95),
         skirt=dict(z0=0.42, flare=0.03, color=(0.12, 0.10, 0.10), blood=0.6),
         shoes=dict(style="dress", color=(0.05, 0.035, 0.03)),
         gear=dict(glasses=dict(color=(0.30, 0.12, 0.14), tilt=-0.12))),

    # 71. Teacher F2 - Ma'am Ocampo, chemistry: lab coat over the faculty blouse, long hair, burns of black bile
    dict(name="teacher_f2", sex="f", seed=1447,
         shapes={"female": 0.95, "build": -0.20, "chin_long": 0.25},
         tone=(0.74, 0.76, 0.78), hair="long_disheveled", hair_col=(0.03, 0.025, 0.022),
         horror=dict(decay="cyanotic", eye_style="hollow", face_gore="black_bile", veins=1.3),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.80, ragged=True, color=(0.86, 0.86, 0.84), under_color=(0.40, 0.06, 0.09),
                  blood=1.15),
         bottom=dict(kind="pants", color=(0.10, 0.10, 0.12), blood=0.5),
         shoes=dict(style="dress", color=(0.05, 0.035, 0.03))),

    # 72. Teacher F3 - Mrs. Lacsamana, guidance: older, short grey bob, floral blouse under a cardigan, pleated skirt
    dict(name="teacher_f3", sex="f", seed=1459,
         shapes={"female": 1.0, "belly": 0.40, "cheeks": 0.35},
         tone=(0.76, 0.75, 0.70), hair="chin_bob", hair_col=(0.30, 0.29, 0.28), grey_mix=0.85,
         horror=dict(decay="jaundiced", eye_style="asymmetric", face_gore="eye_bleed", veins=1.15),
         top=dict(kind="open_jacket", sleeve=0.64, hem=0.96, color=(0.30, 0.34, 0.44), under_color=(0.80, 0.62, 0.66),
                  blood=0.9),
         skirt=dict(z0=0.38, flare=0.07, pleats=True, ragged=True, color=(0.18, 0.16, 0.20), blood=0.7),
         shoes=dict(style="dress", side="R", color=(0.10, 0.07, 0.05))),

    # 73. Janitor S1 - Kuya Boy, maintenance: navy coveralls with the reflective band, rubber boots, cap, rag in hand
    dict(name="janitor_s1", sex="m", seed=1471,
         shapes={"build": 0.05, "cheeks": -0.20, "nose_wide": 0.35},
         tone=(0.70, 0.72, 0.64), hair="textured_crop", hair_col=(0.05, 0.045, 0.04), grey_mix=0.40,
         horror=dict(decay="gaunt", eye_style="yellowed", face_gore="chin_drip", veins=1.2),
         top=dict(kind="coveralls", sleeve=0.66, color=(0.10, 0.14, 0.28), color2=(0.78, 0.80, 0.62),
                  pattern="chest_band", grease=True, blood=1.0),
         bottom=dict(kind="pants", color=(0.10, 0.14, 0.28), grease=True, blood=0.7),
         shoes=dict(style="boot", color=(0.10, 0.10, 0.10)),
         gear=dict(cap=dict(color=(0.40, 0.06, 0.09), blood=0.5))),

    # 74. Janitor S2 - Ate Marites, utility: grey-blue polo, black pants, hair net bun, face mask down her chin
    dict(name="janitor_s2", sex="f", seed=1483,
         shapes={"female": 0.95, "belly": 0.30, "build": 0.10},
         tone=(0.74, 0.74, 0.66), hair="high_bun", hair_col=(0.04, 0.034, 0.03), grey_mix=0.35,
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="neck_bite", veins=1.15),
         top=dict(kind="shirt", sleeve=0.36, color=(0.44, 0.52, 0.60), color2=(0.78, 0.80, 0.62),
                  pattern="chest_band", blood=1.05),
         bottom=dict(kind="pants", color=(0.06, 0.06, 0.07), blood=0.6),
         shoes=dict(style="boot", color=(0.10, 0.10, 0.10)),
         gear=dict(face_mask=dict(color=(0.60, 0.72, 0.74), blood=0.8, hanging=True))),

    # ---------------- 0.68: the hospital's staff and patients (indices 75..86) ----------------

    # 75. Lab surgeon M - sterile green surgical gown and pants, surgical cap, mask soaked through
    dict(name="lab_surgeon_m", sex="m", seed=1501,
         shapes={"build": 0.10, "cheeks": -0.25, "nose_long": 0.35, "brow_heavy": 0.45},
         tone=(0.72, 0.74, 0.78), hair="buzz_fade", hair_col=(0.03, 0.026, 0.024),
         horror=dict(decay="morgue", eye_style="bloodshot", face_gore="chin_drip", veins=1.25, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.69, hem=0.96, color=(0.28, 0.46, 0.40), color2=(0.22, 0.38, 0.33),
                  pattern="button_placket", blood=1.35),
         bottom=dict(kind="pants", color=(0.26, 0.44, 0.38), blood=0.95),
         shoes=dict(style="sneaker", color=(0.70, 0.72, 0.70)),
         gear=dict(beanie=dict(color=(0.30, 0.48, 0.42), blood=0.5),
                   face_mask=dict(color=(0.36, 0.56, 0.50), blood=1.45, hanging=False))),

    # 76. Lab surgeon F - ceil-blue gown, cap over a bun, mask hanging off one ear
    dict(name="lab_surgeon_f", sex="f", seed=1511,
         shapes={"female": 1.0, "build": -0.10, "chin_long": 0.20},
         tone=(0.74, 0.76, 0.80), hair="high_bun", hair_col=(0.03, 0.025, 0.022),
         horror=dict(decay="cyanotic", eye_style="hollow", face_gore="eye_bleed", veins=1.3),
         top=dict(kind="shirt", sleeve=0.69, hem=0.98, color=(0.46, 0.62, 0.74), color2=(0.38, 0.52, 0.64),
                  pattern="button_placket", blood=1.25),
         bottom=dict(kind="pants", color=(0.44, 0.60, 0.72), blood=0.85),
         shoes=dict(style="sneaker", color=(0.66, 0.70, 0.74)),
         gear=dict(beanie=dict(color=(0.46, 0.62, 0.74), blood=0.3),
                   face_mask=dict(color=(0.56, 0.70, 0.78), blood=0.9, hanging=True))),

    # 77. Lab scientist M - long white lab coat over a pale blue shirt and dark tie, cracked glasses, grey temples
    dict(name="lab_scientist_m", sex="m", seed=1523,
         shapes={"build": -0.20, "belly": 0.25, "cheeks": -0.20, "chin_long": 0.30},
         tone=(0.74, 0.76, 0.80), hair="side_part", hair_col=(0.10, 0.09, 0.085), grey_mix=0.45,
         horror=dict(decay="gaunt", eye_style="milky", face_gore="neck_bite", veins=1.25),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=(0.90, 0.91, 0.90), under_color=(0.58, 0.68, 0.80),
                  blood=1.1),
         bottom=dict(kind="pants", color=(0.18, 0.18, 0.20), blood=0.5),
         shoes=dict(style="dress", color=(0.06, 0.05, 0.045)),
         gear=dict(coat_tail=dict(z0=0.40, open_front=True, color=(0.90, 0.91, 0.90), blood=1.0, ragged=True),
                   necktie=dict(color=(0.10, 0.12, 0.22), blood=0.6),
                   glasses=dict(color=(0.10, 0.10, 0.11), tilt=-0.16))),

    # 78. Lab scientist F - lab coat over a black turtleneck, long hair over the face, bile down the coat
    dict(name="lab_scientist_f", sex="f", seed=1531,
         shapes={"female": 1.0, "build": -0.25, "cheeks": -0.30, "eyes_pop": 0.35},
         tone=(0.76, 0.78, 0.80), hair="long_disheveled", hair_col=(0.025, 0.021, 0.019),
         horror=dict(decay="morgue", eye_style="asymmetric", face_gore="black_bile", veins=1.35),
         top=dict(kind="open_jacket", sleeve=0.69, hem=0.92, color=(0.88, 0.89, 0.88), under_color=(0.05, 0.05, 0.055),
                  blood=0.95),
         bottom=dict(kind="pants", color=(0.08, 0.08, 0.09), blood=0.4),
         shoes=dict(style="dress", color=(0.05, 0.04, 0.035)),
         gear=dict(coat_tail=dict(z0=0.40, open_front=True, color=(0.88, 0.89, 0.88), blood=0.95, ragged=True),
                   glasses=dict(color=(0.22, 0.22, 0.24), tilt=0.0))),

    # 79. Lab hazmat - yellow chemical suit, hood up, black respirator, goggles, black boots, the suit split open
    dict(name="lab_hazmat", sex="m", seed=1543,
         shapes={"build": 0.30, "muscle": 0.20, "jaw_wide": 0.40},
         tone=(0.70, 0.72, 0.74), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="cyanotic", eye_style="bloodshot", face_gore="ripped_cheek", veins=1.3),
         top=dict(kind="coveralls", sleeve=0.69, ragged=True, color=(0.80, 0.66, 0.10), color2=(0.10, 0.10, 0.10),
                  pattern="chest_band", blood=1.0),
         bottom=dict(kind="pants", color=(0.80, 0.66, 0.10), blood=0.7),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.05)),
         gear=dict(hood_up=dict(color=(0.80, 0.66, 0.10), blood=0.6),
                   face_mask=dict(color=(0.08, 0.08, 0.09), blood=0.5, hanging=False),
                   glasses=dict(color=(0.06, 0.06, 0.07), tilt=0.05))),

    # 80. Lab cleanroom - white coverall and hood, white mask, white boots; the only colour on it is blood
    dict(name="lab_cleanroom", sex="f", seed=1553,
         shapes={"female": 0.9, "build": -0.15},
         tone=(0.76, 0.78, 0.82), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="morgue", eye_style="milky", face_gore="eye_bleed", veins=1.2),
         top=dict(kind="coveralls", sleeve=0.69, color=(0.88, 0.90, 0.92), color2=(0.70, 0.74, 0.80),
                  pattern="button_placket", blood=1.3),
         bottom=dict(kind="pants", color=(0.88, 0.90, 0.92), blood=1.0),
         shoes=dict(style="boot", color=(0.82, 0.84, 0.86)),
         gear=dict(hood_up=dict(color=(0.88, 0.90, 0.92), blood=0.7),
                   face_mask=dict(color=(0.90, 0.92, 0.94), blood=1.3, hanging=False))),

    # 81. Paramedic - dark green crew shirt with the reflective band, cargo pants with the side stripe, boots, belt
    dict(name="lab_paramedic", sex="m", seed=1567,
         shapes={"build": 0.40, "muscle": 0.45, "jaw_wide": 0.50},
         tone=(0.70, 0.72, 0.70), hair="textured_crop", hair_col=(0.03, 0.026, 0.024),
         horror=dict(decay="ashen", eye_style="bloodshot", face_gore="bruised_jaw", veins=1.1),
         top=dict(kind="shirt", sleeve=0.40, torn_sleeve="L", color=(0.10, 0.20, 0.16), color2=(0.82, 0.84, 0.70),
                  pattern="chest_band", blood=1.0),
         bottom=dict(kind="pants", color=(0.10, 0.16, 0.14), color2=(0.82, 0.84, 0.70), pattern="side_stripe", blood=0.6),
         shoes=dict(style="boot", color=(0.05, 0.05, 0.05)),
         gear=dict(belt=dict(color=(0.05, 0.05, 0.055), pouches=True))),

    # 82. Hospital guard - pale grey-blue uniform shirt, black trousers, black cap, utility belt, throat torn open
    dict(name="lab_guard", sex="m", seed=1579,
         shapes={"belly": 0.45, "cheeks": 0.40, "brow_heavy": 0.60},
         tone=(0.70, 0.72, 0.74), hair="buzz_fade", hair_col=(0.04, 0.035, 0.03), grey_mix=0.30,
         horror=dict(decay="jaundiced", eye_style="yellowed", face_gore="neck_bite", veins=1.15),
         top=dict(kind="shirt", sleeve=0.38, color=(0.62, 0.68, 0.76), color2=(0.10, 0.12, 0.18),
                  pattern="button_placket", blood=1.1),
         bottom=dict(kind="pants", color=(0.05, 0.05, 0.06), blood=0.5),
         shoes=dict(style="boot", color=(0.04, 0.04, 0.045)),
         gear=dict(cap=dict(color=(0.05, 0.05, 0.06), backwards=False, blood=0.2),
                   belt=dict(color=(0.04, 0.04, 0.045), pouches=True))),

    # 83. Patient F - faded rose hospital gown, barefoot, hair matted
    dict(name="lab_patient_f", sex="f", seed=1583,
         shapes={"female": 1.0, "build": -0.45, "cheeks": -0.55, "eyes_pop": 0.50},
         tone=(0.72, 0.74, 0.80), hair="long_disheveled", hair_col=(0.03, 0.026, 0.022),
         horror=dict(decay="gaunt", eye_style="hollow", face_gore="black_bile", veins=1.4, torso_gore=True),
         top=dict(kind="shirt", sleeve=0.36, hem=0.98, color=(0.78, 0.62, 0.66), color2=(0.56, 0.42, 0.50),
                  pattern="hospital", blood=1.0),
         skirt=dict(z0=0.50, flare=0.05, ragged=True, color=(0.78, 0.62, 0.66), color2=(0.56, 0.42, 0.50),
                    pattern="hospital", blood=0.9)),

    # 84. Burn ward - bandaged from the scalp down, one eye covered, the gauze black where it has wept through
    dict(name="lab_burned", sex="m", seed=1597,
         shapes={"build": -0.30, "cheeks": -0.60, "muscle": -0.20},
         tone=(0.62, 0.52, 0.48), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="charred", eye_style="milky", face_gore="ripped_cheek", veins=0.8),
         top=dict(kind="shirt", sleeve=0.69, ragged=True, color=(0.80, 0.76, 0.66), color2=(0.66, 0.60, 0.50),
                  pattern="stripes_h", scorch=True, blood=1.1),
         bottom=dict(kind="shorts", z0=0.50, loose=0.01, color=(0.78, 0.74, 0.64), scorch=True, blood=0.8),
         gear=dict(head_bandage=dict(color=(0.80, 0.76, 0.66), eye_cover=True, blood=1.4))),

    # 85. Head nurse - white uniform dress, stethoscope, bun, white shoes; the white is mostly red now
    dict(name="lab_head_nurse", sex="f", seed=1601,
         shapes={"female": 1.0, "belly": 0.35, "cheeks": 0.25},
         tone=(0.76, 0.76, 0.72), hair="high_bun", hair_col=(0.06, 0.05, 0.045), grey_mix=0.50,
         horror=dict(decay="ashen", eye_style="milky", face_gore="chin_drip", veins=1.15),
         top=dict(kind="shirt", sleeve=0.34, hem=1.0, color=(0.90, 0.90, 0.88), pattern="button_placket", blood=1.2),
         skirt=dict(z0=0.42, flare=0.04, color=(0.90, 0.90, 0.88), blood=0.95),
         shoes=dict(style="dress", color=(0.86, 0.86, 0.84)),
         gear=dict(stethoscope=dict(color=(0.08, 0.09, 0.11)))),

    # 86. Morgue attendant - dark green scrubs under a long black rubber apron, tall boots, mask round the neck
    dict(name="lab_morgue", sex="m", seed=1613,
         shapes={"build": 0.55, "belly": 0.40, "jaw_wide": 0.60, "brow_heavy": 0.75},
         tone=(0.68, 0.70, 0.72), hair="bald", hair_col=(0.02, 0.02, 0.02),
         horror=dict(decay="bloated", eye_style="hollow", face_gore="black_bile", veins=1.3),
         top=dict(kind="shirt", sleeve=0.36, color=(0.12, 0.24, 0.20), blood=0.9),
         bottom=dict(kind="pants", color=(0.10, 0.20, 0.17), blood=0.6),
         shoes=dict(style="boot", color=(0.05, 0.06, 0.05)),
         gear=dict(apron=dict(color=(0.06, 0.06, 0.065), blood=1.2),
                   face_mask=dict(color=(0.56, 0.70, 0.74), blood=0.6, hanging=True))),
]


# ---------------------------------------------------------------- 3D value noise (numpy)

def _hash(ix, iy, iz, seed):
    n = ix * 374761393 + iy * 668265263 + iz * 1274126177 + seed * 1442695
    n = (n ^ (n >> 13)) * 1274126177
    return ((n ^ (n >> 16)) & 0xFFFF).astype(np.float32) / 65535.0


def vnoise(p, freq, seed=0):
    q = p * freq
    i = np.floor(q).astype(np.int64)
    f = (q - i).astype(np.float32)
    f = f * f * (3.0 - 2.0 * f)
    out = np.zeros(len(p), np.float32)
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out += w * _hash(i[:, 0] + dx, i[:, 1] + dy, i[:, 2] + dz, seed)
    return out


def fbm(p, freq, seed=0, octaves=4):
    total = np.zeros(len(p), np.float32)
    amp, norm = 1.0, 0.0
    for k in range(octaves):
        total += amp * vnoise(p, freq * 2 ** k, seed + 17 * k)
        norm += amp
        amp *= 0.5
    return total / norm


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def mix(c, target, m):
    if np.ndim(m) == 0:
        return c + (np.asarray(target, np.float32) - c) * float(np.clip(m, 0.0, 1.0))
    return c + (np.asarray(target, np.float32) - c) * np.clip(m, 0.0, 1.0)[:, None]


# ---------------------------------------------------------------- horror skin, cloth, shoe & gear painters

def paint_wounds(c, p, wounds, cloth):
    for centre, radius in wounds:
        d = np.linalg.norm(p - centre, axis=1)
        if cloth:
            c = mix(c, DRIED * 0.78, smooth(radius * 3.4, radius * 1.15, d) * 0.92)
            c = mix(c, (0.04, 0.008, 0.008), smooth(radius * 1.1, radius * 0.4, d) * 0.7)
        else:
            c = mix(c, BLOOD, smooth(radius * 2.2, radius * 1.05, d) * 0.9)
            c = mix(c, (0.045, 0.003, 0.003), smooth(radius * 1.0, radius * 0.42, d))
        dx = np.hypot(p[:, 0] - centre[0], p[:, 1] - centre[1])
        below = centre[2] - p[:, 2]
        run = smooth(radius * 1.45, radius * 0.25, dx) * smooth(0.0, 0.018, below) * smooth(0.38, 0.04, below)
        run *= 0.42 + 0.58 * (vnoise(p * np.array((1.0, 1.0, 0.07), np.float32), 165.0, 5) > 0.40)
        c = mix(c, DRIED if cloth else BLOOD * 0.75, run * 0.85)
    return c


def paint_skin(p, base, v):
    seed = v["seed"]
    horror = v.get("horror", {})
    decay = horror.get("decay", "ashen")
    eye_style = horror.get("eye_style", "milky")
    face_gore = horror.get("face_gore", "chin_drip")
    vein_str = float(horror.get("veins", 0.95))

    lum = base @ np.array((0.3, 0.59, 0.11), np.float32)
    desat = 0.65 if decay in ("morgue", "gaunt", "ashen") else 0.55
    c = (base + (lum[:, None] - base) * desat) * np.asarray(v["tone"], np.float32)

    # Decay-specific subcutaneous discoloration & mottling.
    blotch = smooth(0.45, 0.72, fbm(p, 6.5, seed))
    c *= (1.0 - 0.34 * blotch)[:, None]
    livor = smooth(0.46, 0.74, fbm(p, 4.2, seed + 3))
    if decay == "jaundiced":
        c = mix(c, c * np.array((0.86, 0.92, 0.52), np.float32), livor * 0.78)
    elif decay == "cyanotic":
        c = mix(c, c * np.array((0.54, 0.50, 0.86), np.float32), livor * 0.82)
    elif decay == "morgue":
        c = mix(c, np.array((0.64, 0.67, 0.70), np.float32) * (0.65 + 0.35 * lum[:, None]), 0.42)
        c = mix(c, c * np.array((0.68, 0.60, 0.78), np.float32), livor * 0.65)
    elif decay == "charred":
        ash = smooth(0.32, 0.70, fbm(p, 7.0, seed + 4))
        c = mix(c, SOOT * 1.4, ash * 0.85)
        blister = smooth(0.64, 0.80, fbm(p, 16.0, seed + 14))
        c = mix(c, (0.26, 0.04, 0.03), blister * 0.75)
    elif decay == "gaunt":
        # Sunken cheek hollows, temple shadows, and bony clavicle/rib shadows.
        c = mix(c, c * np.array((0.62, 0.58, 0.72), np.float32), livor * 0.75)
        cheek_h = smooth(0.055, 0.015, np.abs(np.abs(p[:, 0]) - 0.052)) * smooth(0.04, 0.01, np.abs(p[:, 2] - 1.615)) * (p[:, 1] < -0.05)
        c *= (1.0 - 0.45 * cheek_h)[:, None]
    else:  # ashen / bloated
        c = mix(c, c * np.array((0.70, 0.58, 0.82), np.float32), livor * 0.72)

    # Branching dark blue-black necrotic veins across neck, face, forearms, chest, and scalp.
    v1 = smooth(0.062, 0.0, np.abs(vnoise(p, 24.0, seed + 5) * 2.0 - 1.0)) * smooth(0.32, 0.58, vnoise(p, 5.5, seed + 6))
    v2 = smooth(0.045, 0.0, np.abs(vnoise(p, 48.0, seed + 15) * 2.0 - 1.0)) * smooth(0.40, 0.65, vnoise(p, 8.0, seed + 16))
    vein = np.clip((v1 * 0.72 + v2 * 0.45) * vein_str, 0.0, 1.0)
    c = mix(c, (0.14, 0.13, 0.24), vein * 0.68)

    # Scalp lividity & lesions (visible on bald / thinning / patchy zombies!).
    scalp = smooth(1.69, 1.77, p[:, 2]) * smooth(0.55, 0.80, fbm(p, 12.0, seed + 22))
    c = mix(c, (0.28, 0.16, 0.18), scalp * 0.55)

    # Creepy eye rendering (5 distinct horror eye styles!).
    for idx_e, eye in enumerate(v["eyes"]):
        d = np.linalg.norm(p - eye, axis=1)
        # Deep dark sunken orbital bruising around every zombie eye.
        sock_dark = 0.22 if eye_style == "hollow" else 0.30
        c *= (sock_dark + (1.0 - sock_dark) * smooth(0.010, 0.040, d))[:, None]
        c = mix(c, (0.14, 0.07, 0.12), smooth(0.036, 0.016, d) * 0.55)
        if eye_style == "hollow":
            c = mix(c, (0.025, 0.018, 0.022), smooth(0.015, 0.008, d) * 0.95)
        elif eye_style == "bloodshot":
            c = mix(c, (0.62, 0.10, 0.09), smooth(0.0115, 0.008, d))
            c = mix(c, (0.85, 0.82, 0.72), smooth(0.0055, 0.0038, d))
            c = mix(c, (0.08, 0.04, 0.04), smooth(0.0024, 0.0012, d))
        elif eye_style == "yellowed":
            c = mix(c, (0.76, 0.72, 0.38), smooth(0.011, 0.0075, d))
            c = mix(c, (0.08, 0.07, 0.04), smooth(0.0042, 0.0022, d))
        elif eye_style == "asymmetric" and idx_e == 0:
            # Gouged bloody empty socket on left eye!
            c = mix(c, (0.04, 0.004, 0.004), smooth(0.015, 0.007, d))
            c = mix(c, BLOOD * 0.9, smooth(0.028, 0.013, d) * 0.85)
            # Blood streak running down the cheek from the gouged eye!
            below_e = eye[2] - p[:, 2]
            edx = np.abs(p[:, 0] - eye[0])
            tear = smooth(0.016, 0.004, edx) * smooth(0.0, 0.012, below_e) * smooth(0.11, 0.02, below_e) * (p[:, 1] < eye[1] + 0.03)
            c = mix(c, BLOOD * 0.85, tear * 0.92)
        else:  # milky cataract eye
            c = mix(c, (0.82, 0.83, 0.76), smooth(0.011, 0.0075, d))
            c = mix(c, (0.34, 0.34, 0.30), smooth(0.0038, 0.0018, d) * 0.75)

    # Creepy mouth / jaw / face horror (6 distinct face_gore styles!).
    m = v["mouth"]
    front = p[:, 1] < m[1] + 0.042
    d_m = np.hypot(p[:, 0] - m[0], (p[:, 2] - m[2]) * 1.45)
    mouth_col = BILE if face_gore == "black_bile" else BLOOD * 0.78
    c = mix(c, mouth_col, smooth(0.052, 0.014, d_m) * front * (0.55 + 0.45 * vnoise(p, 62.0, seed + 8)))
    drip = smooth(0.044, 0.010, np.abs(p[:, 0] - m[0])) * smooth(m[2] - 0.16, m[2] - 0.015, p[:, 2]) * (p[:, 2] < m[2]) * front
    drip *= vnoise(p * np.array((1.0, 1.0, 0.045), np.float32), 155.0, seed + 9) > 0.40
    c = mix(c, mouth_col * 0.9, drip * 0.92)

    if face_gore == "ripped_cheek":
        # Jagged torn right cheek wound with dark hollow & pale exposed tooth-like ridges!
        ck = np.array((-0.036, m[1] + 0.014, m[2] + 0.008), np.float32)
        dc = np.hypot((p[:, 0] - ck[0]) * 0.85, (p[:, 2] - ck[2]) * 1.65)
        c = mix(c, BLOOD * 0.9, smooth(0.036, 0.018, dc) * front * 0.92)
        c = mix(c, (0.04, 0.003, 0.004), smooth(0.019, 0.010, dc) * front)
        teeth = smooth(0.014, 0.007, dc) * front * (np.sin(p[:, 0] * 380.0) > 0.25) * (np.abs(p[:, 2] - ck[2]) < 0.008)
        c = mix(c, (0.76, 0.70, 0.54), teeth * 0.85)
    elif face_gore == "eye_bleed":
        for eye in v["eyes"]:
            below_e = eye[2] - p[:, 2]
            edx = np.abs(p[:, 0] - eye[0] * 0.85)
            tear = smooth(0.013, 0.003, edx) * smooth(0.0, 0.01, below_e) * smooth(0.11, 0.015, below_e) * front
            tear *= 0.55 + 0.45 * vnoise(p, 90.0, seed + 19)
            c = mix(c, BLOOD * 0.72, tear * 0.90)
    elif face_gore == "neck_bite":
        nb = np.array((0.042, -0.045, 1.505), np.float32)
        dn = np.linalg.norm(p - nb, axis=1)
        c = mix(c, BLOOD, smooth(0.055, 0.024, dn) * 0.92)
        c = mix(c, (0.045, 0.003, 0.003), smooth(0.025, 0.011, dn))
        below_n = nb[2] - p[:, 2]
        nrun = smooth(0.045, 0.008, np.abs(p[:, 0] - nb[0])) * smooth(0.0, 0.015, below_n) * smooth(0.22, 0.03, below_n) * (p[:, 1] < 0.02)
        c = mix(c, BLOOD * 0.78, nrun * 0.88)
    elif face_gore == "bruised_jaw":
        jaw = smooth(0.08, 0.02, np.hypot(p[:, 0] + 0.03, (p[:, 2] - (m[2] - 0.01)) * 1.4)) * front
        c = mix(c, (0.16, 0.07, 0.16), jaw * 0.82)

    # Exposed scarred / slashed / rib-bruised torso for shirtless, open-jacket, or nightgown horror zombies.
    if horror.get("torso_gore"):
        chest_f = (p[:, 2] > 1.08) & (p[:, 2] < 1.44) & (p[:, 1] < -0.02) & (np.abs(p[:, 0]) < 0.18)
        ribs = np.sin(p[:, 2] * 78.0) * smooth(0.16, 0.03, np.abs(p[:, 0]))
        c = mix(c, c * np.array((0.62, 0.56, 0.66), np.float32), (ribs > 0.25) * chest_f * 0.45)
        # Diagonal claw slash across sternum!
        slash_d = np.abs((p[:, 2] - 1.28) - (p[:, 0] * 0.75))
        slash = smooth(0.018, 0.004, slash_d) * chest_f * (np.abs(p[:, 0]) < 0.11)
        c = mix(c, BLOOD * 0.9, slash * 0.92)
        c = mix(c, (0.04, 0.003, 0.003), smooth(0.006, 0.002, slash_d) * chest_f * (np.abs(p[:, 0]) < 0.10))

    # Blood-caked grabbing hands/forearms & mud-filthy bare feet/ankles.
    hands = smooth(0.62, 0.74, np.abs(p[:, 0])) * (p[:, 2] > 1.28) * (0.38 + 0.62 * fbm(p, 30.0, seed + 11))
    c = mix(c, BLOOD * 0.58, hands * 0.90)
    c = mix(c, DIRT * 0.75, smooth(0.14, 0.015, p[:, 2]) * 0.82)
    c = mix(c, DIRT, smooth(0.56, 0.80, fbm(p, 9.0, seed + 13)) * 0.40)
    return paint_wounds(c, p, v["wounds"], False)


def paint_cloth(p, spec, v, salt):
    seed = v["seed"] + salt
    n = len(p)
    c = np.tile(np.asarray(spec["color"], np.float32), (n, 1))
    c2 = np.asarray(spec.get("color2", spec["color"]), np.float32)
    pattern = spec.get("pattern", "")

    if pattern == "stripes_h":
        c = mix(c, c2, (np.floor(p[:, 2] / 0.028) % 3 == 0).astype(np.float32))
    elif pattern == "stripes_v":
        ang = np.arctan2(p[:, 0], p[:, 1] + 0.02)
        c = mix(c, c2, (np.floor(ang * 14.0) % 2 == 0).astype(np.float32) * 0.65)
    elif pattern == "check":
        c = mix(c, c2, ((np.floor(p[:, 2] / 0.03) + np.floor(np.arctan2(p[:, 0], p[:, 1] + 0.02) * 9.0)) % 2).astype(np.float32) * 0.82)
    elif pattern == "plaid":
        h_bar = ((np.floor(p[:, 2] / 0.036) % 2 == 0).astype(np.float32) * 0.55)
        v_bar = ((np.floor(np.arctan2(p[:, 0], p[:, 1] + 0.02) * 11.0) % 2 == 0).astype(np.float32) * 0.55)
        c = mix(c, c2, np.clip(h_bar + v_bar, 0.0, 0.88))
        pin = ((np.abs((p[:, 2] % 0.072) - 0.036) < 0.004).astype(np.float32))
        c = mix(c, (0.72, 0.16, 0.16), pin * 0.65)
    elif pattern == "floral":
        cell = p / 0.055
        centre = np.floor(cell) + 0.5
        jitter = np.stack([_hash(*(centre.astype(np.int64).T), seed + k) for k in range(3)], axis=1) - 0.5
        d = np.linalg.norm(cell - centre - jitter * 0.5, axis=1)
        keep = _hash(*(centre.astype(np.int64).T), seed + 7) > 0.35
        c = mix(c, c2, smooth(0.34, 0.22, d) * keep)
        c = mix(c, (0.20, 0.42, 0.38), smooth(0.11, 0.07, d) * keep)
    elif pattern == "chest_band":
        c = mix(c, c2, ((p[:, 2] > 1.25) & (p[:, 2] < 1.325)).astype(np.float32))
    elif pattern == "side_stripe":
        c = mix(c, c2, smooth(0.03, 0.018, np.abs(p[:, 1] - 0.005)) * (np.abs(p[:, 0]) > 0.11))
    elif pattern == "hivis":
        # Two reflective horizontal silver-grey bands + twin vertical shoulder bands!
        h1 = ((p[:, 2] > 1.07) & (p[:, 2] < 1.125)) | ((p[:, 2] > 1.24) & (p[:, 2] < 1.295))
        v1 = (np.abs(np.abs(p[:, 0]) - 0.095) < 0.022) & (p[:, 2] > 1.24)
        c = mix(c, c2, (h1 | v1).astype(np.float32) * 0.92)
    elif pattern == "camo":
        # 4-tone woodland military camouflage.
        n1 = fbm(p, 7.5, seed + 11, octaves=3)
        n2 = fbm(p, 9.5, seed + 23, octaves=3)
        c = mix(c, c2, (n1 > 0.52).astype(np.float32))
        c = mix(c, (0.34, 0.28, 0.17), (n2 > 0.60).astype(np.float32) * 0.9)
        c = mix(c, (0.08, 0.09, 0.07), ((n1 > 0.63) & (n2 < 0.48)).astype(np.float32) * 0.9)
    elif pattern == "hospital":
        # Faded institutional diamond print.
        dx = np.abs(((p[:, 0] * 14.0) % 1.0) - 0.5)
        dz = np.abs(((p[:, 2] * 14.0) % 1.0) - 0.5)
        c = mix(c, c2, ((dx + dz) < 0.24).astype(np.float32) * 0.62)
    elif pattern == "jersey":
        # Bold horizontal chest band + vertical side trim + number-block motif.
        band = ((p[:, 2] > 1.23) & (p[:, 2] < 1.32)).astype(np.float32)
        trim = ((np.abs(p[:, 0]) > 0.15) & (p[:, 2] < 1.28)).astype(np.float32)
        c = mix(c, c2, np.clip(band + trim, 0.0, 1.0))
        num_box = ((np.abs(p[:, 0]) < 0.048) & (p[:, 2] > 1.13) & (p[:, 2] < 1.22) & (p[:, 1] < -0.05)).astype(np.float32)
        c = mix(c, (0.88, 0.86, 0.82), num_box * 0.88)
    elif pattern == "button_placket":
        front_c = (np.abs(p[:, 0]) < 0.016) & (p[:, 1] < -0.02) & (p[:, 2] > 0.95) & (p[:, 2] < 1.46)
        c = mix(c, c * 0.82, front_c.astype(np.float32))
        btn = (np.abs(p[:, 0]) < 0.007) & (p[:, 1] < -0.02) & (np.abs((p[:, 2] % 0.065) - 0.032) < 0.006)
        c = mix(c, (0.10, 0.10, 0.11), btn.astype(np.float32))
        pocket = (p[:, 0] > 0.055) & (p[:, 0] < 0.13) & (p[:, 2] > 1.22) & (p[:, 2] < 1.31) & (p[:, 1] < -0.02)
        c = mix(c, c * 0.88, pocket.astype(np.float32))
    elif pattern == "pilcst":
        # 0.50: the Prof. Ivan Lawrence College of Science and Technology uniform: white, button placket, a pocket
        # with the maroon-and-gold crest on the left chest.
        front_c = (np.abs(p[:, 0]) < 0.016) & (p[:, 1] < -0.02) & (p[:, 2] > 0.95) & (p[:, 2] < 1.46)
        c = mix(c, c * 0.84, front_c.astype(np.float32))
        btn = (np.abs(p[:, 0]) < 0.007) & (p[:, 1] < -0.02) & (np.abs((p[:, 2] % 0.065) - 0.032) < 0.006)
        c = mix(c, (0.10, 0.10, 0.11), btn.astype(np.float32))
        crest_d = np.sqrt((p[:, 0] - 0.092) ** 2 + (p[:, 2] - 1.285) ** 2)
        front = (p[:, 1] < -0.02).astype(np.float32)
        c = mix(c, (0.42, 0.05, 0.08), ((crest_d < 0.030).astype(np.float32)) * front)
        c = mix(c, (0.78, 0.62, 0.20), ((np.abs(crest_d - 0.030) < 0.005).astype(np.float32)) * front)
        c = mix(c, (0.78, 0.62, 0.20), ((crest_d < 0.009).astype(np.float32)) * front)
    elif pattern == "barong":
        # Filipino embroidered vertical front panel (callado/embroidery U-shield!).
        panel = (np.abs(p[:, 0]) < 0.085) & (p[:, 2] > 1.06) & (p[:, 2] < 1.46) & (p[:, 1] < -0.02)
        emb = np.sin(p[:, 0] * 170.0) * np.sin(p[:, 2] * 140.0)
        c = mix(c, c2, panel.astype(np.float32) * (0.35 + 0.55 * (emb > 0.15)))
        c = mix(c, c * 0.86, ((np.abs(np.abs(p[:, 0]) - 0.085) < 0.008) & (p[:, 2] > 1.06) & (p[:, 1] < -0.02)).astype(np.float32))
    elif pattern == "denim":
        twill = np.sin((p[:, 0] + p[:, 2]) * 420.0) * 0.5 + 0.5
        c *= (0.86 + 0.20 * twill)[:, None]
        # Faded knees & thighs.
        fade = smooth(0.24, 0.06, np.abs(p[:, 2] - 0.58)) * (p[:, 1] < 0.0) * 0.22
        c = mix(c, c * 1.45 + 0.08, fade)
    elif pattern == "leather":
        grain = vnoise(p, 260.0, seed + 17)
        c *= (0.82 + 0.34 * grain)[:, None]
        scuff = smooth(0.58, 0.78, fbm(p, 11.0, seed + 18))
        c = mix(c, c * 1.7 + 0.06, scuff * 0.35)
    elif pattern == "woven":
        w1 = np.sin(p[:, 0] * 160.0 + p[:, 1] * 160.0) > 0.0
        w2 = np.sin((p[:, 0] - p[:, 1]) * 160.0) > 0.0
        c *= np.where(w1 ^ w2, 0.86, 1.12)[:, None]
    elif pattern == "pinstripe":
        pin = (np.abs((p[:, 0] * 48.0) % 1.0 - 0.5) < 0.10).astype(np.float32)
        c = mix(c, c2, pin * 0.72)
    elif pattern == "batik":
        n1 = fbm(p, 11.0, seed + 19, octaves=3)
        n2 = np.sin(p[:, 0] * 45.0 + n1 * 8.0) * np.cos(p[:, 2] * 45.0 - n1 * 6.0)
        c = mix(c, c2, (n2 > 0.22).astype(np.float32) * 0.85)
        c = mix(c, (0.86, 0.80, 0.24), (n2 < -0.52).astype(np.float32) * 0.65)
    elif pattern == "polka":
        cell = p / 0.042
        centre = np.floor(cell) + 0.5
        d = np.linalg.norm(cell - centre, axis=1)
        c = mix(c, c2, smooth(0.28, 0.18, d) * 0.88)
    elif pattern == "track_stripe":
        arm_s = (np.abs(p[:, 0]) > 0.22) & (np.abs(p[:, 1] + 0.01) < 0.022) & (p[:, 2] > 1.38)
        chest_s = (p[:, 2] > 1.24) & (p[:, 2] < 1.28)
        c = mix(c, c2, (arm_s | chest_s).astype(np.float32) * 0.92)
    elif pattern == "delivery":
        # Two-tone delivery courier jacket with dark shoulders/sleeves & bright chest/back reflective stripe.
        sh = (p[:, 2] > 1.38) | (np.abs(p[:, 0]) > 0.34)
        c = mix(c, c2, sh.astype(np.float32) * 0.90)
        ref_b = (p[:, 2] > 1.18) & (p[:, 2] < 1.225)
        c = mix(c, (0.84, 0.86, 0.88), ref_b.astype(np.float32) * 0.92)

    # Fabric weave & natural fade.
    c *= (0.90 + 0.20 * vnoise(p, 420.0, seed))[:, None]
    lum = c @ np.array((0.3, 0.59, 0.11), np.float32)
    c = c + (lum[:, None] - c) * (0.26 * fbm(p, 8.0, seed + 1))[:, None]

    # Dirt & mud, heavier near bottom hems.
    c = mix(c, DIRT, smooth(0.50, 0.78, fbm(p, 5.0, seed + 2)) * 0.62)
    c = mix(c, DIRT * 0.75, smooth(0.32, 0.06, p[:, 2]) * 0.55)

    if spec.get("grease"):
        gr = smooth(0.42, 0.70, fbm(p, 6.0, seed + 27))
        c = mix(c, (0.04, 0.04, 0.042), gr * 0.80)
    if spec.get("scorch"):
        sc = smooth(0.38, 0.72, fbm(p, 5.5, seed + 33))
        c = mix(c, SOOT, sc * 0.82)

    # Blood soak & arterial streaks (stronger on high-blood horror outfits like butcher/nightgown/doctor).
    b_amt = float(spec.get("blood", 0.5))
    if b_amt > 0.01:
        stain = smooth(max(0.28, 0.60 - 0.14 * b_amt), 0.72, fbm(p, 3.6, seed + 4)) * min(b_amt, 1.4)
        c = mix(c, DRIED * (0.65 + 0.55 * vnoise(p, 40.0, seed + 5))[:, None], np.clip(stain * 1.25, 0, 1))
        # Extra fresh arterial splatter on front chest/apron for heavily bloodied variants!
        if b_amt >= 0.9:
            splat = smooth(0.54, 0.74, fbm(p, 8.5, seed + 9)) * (p[:, 1] < 0.02) * min(1.0, (b_amt - 0.5) * 1.1)
            c = mix(c, BLOOD * 0.78, splat * 0.85)

    return paint_wounds(c, p, v["wounds"], True)


def paint_shoe(p, spec, v):
    c = np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
    sole_col = (0.14, 0.13, 0.12) if spec.get("style") in ("boot", "dress") else (0.56, 0.53, 0.48)
    c = mix(c, sole_col, (p[:, 2] < 0.024).astype(np.float32) * 0.72)
    return mix(c, DIRT, smooth(0.38, 0.74, fbm(p, 14.0, v["seed"] + 31)) * 0.75)


# ---------------------------------------------------------------- body & landmarks

def load(keep):
    bpy.ops.import_scene.gltf(filepath=bh.SRC)
    arm = body = None
    for ob in list(bpy.data.objects):
        if ob.type == "ARMATURE":
            arm = ob
        elif ob.type == "MESH" and ob.parent is not None:
            body = ob
        else:
            bpy.data.objects.remove(ob)
    for track in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(track)
    for act in list(bpy.data.actions):
        if act.name in keep:
            act.use_fake_user = True
        else:
            bpy.data.actions.remove(act)
    me = body.data
    while len(me.uv_layers) > 1:
        me.uv_layers.remove(me.uv_layers[-1])
    for attr in list(me.color_attributes):
        me.color_attributes.remove(attr)
    UV_NAME[0] = me.uv_layers[0].name
    return arm, body


def shape_body(body, v):
    """Applies shape keys, records exact anatomical landmarks, and bakes vertex positions."""
    keys = body.data.shape_keys.key_blocks
    basis = np.array([d.co[:] for d in keys[0].data])

    def moved(name):
        delta = np.linalg.norm(np.array([d.co[:] for d in keys[name].data]) - basis, axis=1)
        return np.where(delta > max(delta.max() * 0.35, 1e-5))[0]

    eye_idx = moved("eyes_pop")
    mouth_idx = moved("mouth_wide")
    co = basis.copy()
    for k in keys[1:]:
        value = v["shapes"].get(k.name, 0.0)
        if value != 0.0:
            co += value * (np.array([d.co[:] for d in k.data]) - basis)
    body.shape_key_clear()
    body.data.vertices.foreach_set("co", co.astype(np.float32).ravel())
    body.data.update()

    eyes = [co[eye_idx][co[eye_idx][:, 0] > 0].mean(axis=0), co[eye_idx][co[eye_idx][:, 0] < 0].mean(axis=0)]
    for e in eyes:
        e[1] -= 0.004
    mouth = co[mouth_idx].mean(axis=0)
    mouth[0] = 0.0
    mouth[1] = co[mouth_idx][:, 1].min()
    v["eyes"], v["mouth"] = eyes, mouth

    # Detailed anatomical landmarks for precision-fitted headgear, glasses, masks, belts, ties, etc.
    head = co[(co[:, 2] > 1.56) & (np.abs(co[:, 0]) < 0.14)]
    crown_z = float(head[:, 2].max())
    upper = head[head[:, 2] > crown_z - 0.14]
    nose_band = head[(head[:, 2] > mouth[2] + 0.015) & (head[:, 2] < eyes[0][2]) & (np.abs(head[:, 0]) < 0.025)]
    nose = nose_band[np.argmin(nose_band[:, 1])] if len(nose_band) else np.array((0.0, float(head[:, 1].min()), (mouth[2] + eyes[0][2]) * 0.5), np.float32)
    waist = co[(co[:, 2] > 0.97) & (co[:, 2] < 1.05) & (np.abs(co[:, 0]) < 0.26)]
    neck = co[(co[:, 2] > 1.48) & (co[:, 2] < 1.54) & (np.abs(co[:, 0]) < 0.10)]
    v["lm"] = {
        "crown_z": crown_z,
        "head_c": np.array((0.0, float((upper[:, 1].min() + upper[:, 1].max()) * 0.5), crown_z - 0.105), np.float32),
        "head_rx": float(np.abs(upper[:, 0]).max()),
        "head_ymin": float(upper[:, 1].min()),
        "head_ymax": float(upper[:, 1].max()),
        "nose": nose,
        "waist_rx": float(np.abs(waist[:, 0]).max()),
        "waist_ymin": float(waist[:, 1].min()),
        "waist_ymax": float(waist[:, 1].max()),
        "neck_rx": float(np.abs(neck[:, 0]).max()),
        "neck_cy": float((neck[:, 1].min() + neck[:, 1].max()) * 0.5),
        "neck_ry": float((neck[:, 1].max() - neck[:, 1].min()) * 0.5),
    }

    rng = random.Random(v["seed"])
    pool = [c for c in co if (0.3 < c[2] < 1.45 or 1.56 < c[2] < 1.74) and abs(c[0]) < 0.6]
    v["wounds"] = [(np.array(rng.choice(pool), np.float32), rng.uniform(0.015, 0.038)) for _ in range(rng.randint(4, 7))]


def tag(kind):
    name = "gid:" + kind
    return bpy.data.materials.get(name) or bpy.data.materials.new(name)


def bind_single_bone(ob, bone_name):
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    g = ob.vertex_groups.new(name=bone_name)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")


def bind_z_blend(ob, stops):
    """Deterministic vertical bone-weight blending: stops = [(z_val, {bone: weight}), ...] sorted ascending by z."""
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)
    groups = {}
    for v in ob.data.vertices:
        z = v.co.z
        if z <= stops[0][0]:
            wmap = stops[0][1]
        elif z >= stops[-1][0]:
            wmap = stops[-1][1]
        else:
            wmap = stops[0][1]
            for i in range(len(stops) - 1):
                z0, m0 = stops[i]
                z1, m1 = stops[i + 1]
                if z0 <= z <= z1:
                    t = (z - z0) / max(z1 - z0, 1e-6)
                    wmap = {}
                    for k in set(m0) | set(m1):
                        wmap[k] = m0.get(k, 0.0) * (1.0 - t) + m1.get(k, 0.0) * t
                    break
        tot = sum(wmap.values())
        for k, val in wmap.items():
            if val > 1e-4:
                if k not in groups:
                    groups[k] = ob.vertex_groups.new(name=k)
                groups[k].add([v.index], val / max(tot, 1e-6), "REPLACE")


def limit_groups(ob, allowed, fallback):
    """Keeps only the named bones' weights on a transferred mesh."""
    names = {g.index: g.name for g in ob.vertex_groups}
    groups = {g.name: g for g in ob.vertex_groups}
    for vert in ob.data.vertices:
        kept = [(names[g.group], g.weight) for g in vert.groups if names[g.group] in allowed and g.weight > 1e-4]
        total = sum(w for _, w in kept)
        for g in list(vert.groups):
            groups[names[g.group]].remove([vert.index])
        if total < 1e-4:
            kept, total = [(fallback, 1.0)], 1.0
        for nme, w in kept:
            groups[nme].add([vert.index], w / total, "REPLACE")


def grid(name, rows, closed, mat):
    """Lofted quad surface from rows of points, with clean [0..1] UVs."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new(UV_NAME[0])
    verts = [[bm.verts.new(p) for p in row] for row in rows]
    n = len(rows[0])
    for r in range(len(rows) - 1):
        for c in range(n if closed else n - 1):
            d = (c + 1) % n
            try:
                face = bm.faces.new((verts[r][c], verts[r][d], verts[r + 1][d], verts[r + 1][c]))
                face.smooth = True
                for loop, (cc, rr) in zip(face.loops, ((c, r), (c + 1, r), (c + 1, r + 1), (c, r + 1))):
                    loop[uv].uv = (cc / n if closed else cc / max(n - 1, 1), 1.0 - rr / max(len(rows) - 1, 1))
            except ValueError:
                pass
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob


def tube_uv(name, pts, radius, closed, mat, ring=8, ref_center=None):
    """Round tube through `pts` with proper [0..1] UV coordinates."""
    n = len(pts)
    rows = []
    center = Vector(ref_center) if ref_center is not None else sum(pts, Vector()) / max(n, 1)
    for k in range(n):
        a = pts[k - 1] if (closed or k > 0) else pts[k]
        b = pts[(k + 1) % n] if (closed or k < n - 1) else pts[k]
        t = (b - a)
        t = t.normalized() if t.length > 1e-6 else Vector((0, 0, -1))
        out = pts[k] - center
        out = out - t * out.dot(t)
        if out.length < 1e-5:
            out = t.cross(Vector((0, 0, 1)))
            if out.length < 1e-5:
                out = Vector((1, 0, 0))
        out.normalize()
        up = t.cross(out).normalized()
        r_now = radius[k] if isinstance(radius, (list, tuple)) else radius
        row = [tuple(pts[k] + (out * math.cos(r / ring * math.tau) + up * math.sin(r / ring * math.tau)) * r_now)
               for r in range(ring)]
        rows.append(row)
    if closed:
        rows.append(rows[0])
    return grid(name, rows, True, mat)


# ---------------------------------------------------------------- primary body-shell garments (atlas)

def _rag_offset(co, seed, amp=0.025):
    return amp * math.sin(co.x * 29.0 + seed) * math.cos(co.y * 23.0 + seed * 0.7)


def top(body, v):
    spec = v.get("top")
    if not spec or spec.get("kind") == "shirtless":
        return None
    kind = spec["kind"]
    hem = spec.get("hem", 0.93)
    ragged = bool(spec.get("ragged", False))
    torn_s = spec.get("torn_sleeve", "")
    seed = v["seed"]
    ob = bh.duplicate(body, "Top")

    if kind == "sando":
        def drop(co):
            if abs(co.x) > 0.15 and co.z > 1.29:
                return True
            if co.z > 1.37 and abs(co.x) < 0.07:
                return True
            if ragged and co.z < hem + 0.03 + _rag_offset(co, seed, 0.028):
                return True
            return False
        bh.cut(ob, [((0, 0, 1.47), (0, 0, 1)), ((0, 0, hem - (0.02 if ragged else 0.0)), (0, 0, -1)),
                    ((0.19, 0, 0), (1, 0, 0)), ((-0.19, 0, 0), (-1, 0, 0))], drop)
        spec["covers"] = lambda co: hem + 0.04 < co.z < 1.27 and abs(co.x) < 0.18
    elif kind == "open_jacket":
        sx = spec.get("sleeve", 0.68)
        bare = bool(spec.get("bare_chest", False))
        split_w = 0.068 if bare else 0.056

        def drop_j(co):
            if co.z > 1.44 and bh.neck_r(co) < 0.092:
                return True
            # Open front split exposing bare scarred chest (or undershirt painted below)!
            if co.y < -0.02 and abs(co.x) < split_w and co.z < 1.46:
                return True
            if torn_s == "L" and co.x > 0.30:
                return True
            if torn_s == "R" and co.x < -0.30:
                return True
            return False
        bh.cut(ob, [((0, 0, 1.56), (0, 0, 1)), ((0, 0, hem), (0, 0, -1)), ((sx, 0, 0), (1, 0, 0)), ((-sx, 0, 0), (-1, 0, 0))],
               drop_j)
        if bare:
            # Leave chest skin exposed down the front opening!
            spec["covers"] = lambda co: hem + 0.04 < co.z < 1.53 and abs(co.x) < sx - 0.05 and not (co.y < 0.0 and abs(co.x) < split_w + 0.03) and not (co.z > 1.38 and bh.neck_r(co) < 0.14)
        else:
            # Keep an inner shirt shell across the opening via second inner layer? Even cleaner: keep body front chest painted as undershirt!
            spec["covers"] = lambda co: False
    else:
        # shirt / hoodie / coveralls upper
        sx = spec.get("sleeve", 0.36)
        lx = 0.28 if torn_s == "L" else sx
        rx = 0.28 if torn_s == "R" else sx

        def drop_s(co):
            if co.z > 1.43 and bh.neck_r(co) < 0.092:
                return True
            if torn_s == "L" and co.x > lx + _rag_offset(co, seed, 0.025):
                return True
            if torn_s == "R" and co.x < -rx - _rag_offset(co, seed, 0.025):
                return True
            if ragged and co.z < hem + 0.03 + _rag_offset(co, seed, 0.03):
                return True
            return False
        bh.cut(ob, [((0, 0, 1.57), (0, 0, 1)), ((0, 0, hem - (0.02 if ragged else 0.0)), (0, 0, -1)),
                    ((sx, 0, 0), (1, 0, 0)), ((-sx, 0, 0), (-1, 0, 0))], drop_s)
        spec["covers"] = lambda co: hem + 0.04 < co.z < 1.55 and (-rx + 0.05) < co.x < (lx - 0.05) and not (co.z > 1.37 and bh.neck_r(co) < 0.15)

    thick_base = 0.020 if kind in ("hoodie", "open_jacket") else (0.016 if kind == "coveralls" else 0.013)

    def off(co, n):
        d = thick_base
        if abs(co.x) > 0.22:
            d += 0.008
        if co.z < hem + 0.12:
            d += 0.012 * (1.0 - max(0.0, (co.z - hem) / 0.12))
        return d
    bh.inflate(ob, off, smooth_iters=2, wrinkle=0.0045)
    bh.set_material(ob, tag("top"))
    return ob


def bottom(body, v):
    spec = v["bottom"]
    z0 = spec.get("z0", 0.108)
    loose = spec.get("loose", 0.0)
    torn_leg = spec.get("torn_leg", "")
    seed = v["seed"]
    ob = bh.duplicate(body, "Bottom")

    def drop_b(co):
        if torn_leg == "L" and co.x > 0.01 and co.z < 0.48 + _rag_offset(co, seed + 3, 0.035):
            return True
        if torn_leg == "R" and co.x < -0.01 and co.z < 0.48 + _rag_offset(co, seed + 3, 0.035):
            return True
        return False

    bh.cut(ob, [((0, 0, 1.0), (0, 0, 1)), ((0, 0, z0), (0, 0, -1))], drop_b if torn_leg else None)
    if torn_leg == "L":
        spec["covers"] = lambda co: ((co.x <= 0.0 and z0 + 0.03 < co.z < 0.985) or (co.x > 0.0 and 0.53 < co.z < 0.985)) and abs(co.x) < 0.4
    elif torn_leg == "R":
        spec["covers"] = lambda co: ((co.x >= 0.0 and z0 + 0.03 < co.z < 0.985) or (co.x < 0.0 and 0.53 < co.z < 0.985)) and abs(co.x) < 0.4
    else:
        spec["covers"] = lambda co: z0 + 0.03 < co.z < 0.985 and abs(co.x) < 0.4

    def off(co, n):
        d = 0.014 + loose
        if co.z < z0 + 0.25:
            d += (0.012 + loose) * (1.0 - max(0.0, (co.z - z0) / 0.25))
        return d
    bh.inflate(ob, off, smooth_iters=2, wrinkle=0.003)
    bh.set_material(ob, tag("bottom"))
    return ob


def shoes(body, v):
    spec = v["shoes"]
    style = spec.get("style", "sneaker")
    side = spec.get("side", "")  # "" = both, "L" = left only (+X), "R" = right only (-X)
    z_top = 0.265 if style == "boot" else (0.110 if style == "dress" else 0.128)
    ob = bh.duplicate(body, "Shoes")
    drop = (lambda co: co.x < 0.0) if side == "L" else ((lambda co: co.x > 0.0) if side == "R" else None)
    bh.cut(ob, [((0, 0, z_top), (0, 0, 1))], drop)
    inflate_d = 0.017 if style == "boot" else (0.010 if style == "dress" else 0.013)
    bh.inflate(ob, lambda co, n: inflate_d + (0.006 if style == "boot" and co.z > 0.13 else 0.0), smooth_iters=3)
    bh.set_material(ob, tag("shoes"))
    if side == "L":
        spec["covers"] = lambda co: co.z < z_top - 0.03 and co.x > 0.0
    elif side == "R":
        spec["covers"] = lambda co: co.z < z_top - 0.03 and co.x < 0.0
    else:
        spec["covers"] = lambda co: co.z < z_top - 0.03
    return ob


# ---------------------------------------------------------------- layered gear & creepy accessories (gear atlas)

def skirt(body, v, arm):
    spec = v["skirt"]
    co = np.array([vert.co[:] for vert in body.data.vertices])
    co = co[np.abs(co[:, 0]) < 0.32]
    z1, z0 = 1.03, spec["z0"]
    ragged = bool(spec.get("ragged", False))
    rows = []
    levels = 10
    for r in range(levels):
        t = r / (levels - 1)
        z = z1 + (z0 - z1) * t
        near = co[np.abs(co[:, 2] - z) < 0.04]
        if len(near) < 4:
            near = co[np.abs(co[:, 2] - z) < 0.08]
        pad = 0.018 + spec["flare"] * (t ** 1.3)
        rx = float(np.abs(near[:, 0]).max()) + pad
        y_lo, y_hi = float(near[:, 1].min()) - pad, float(near[:, 1].max()) + pad
        cy, ry = (y_lo + y_hi) * 0.5, (y_hi - y_lo) * 0.5
        row = []
        for k in range(36):
            a = k / 36 * math.tau
            fold = 1.0 + (0.035 * t * (1 if k % 2 else -1) if spec.get("pleats") else 0.014 * t * math.sin(a * 5 + r))
            z_j = z + (0.045 * (t ** 2) * math.sin(a * 7 + v["seed"]) * math.cos(a * 3) if ragged else 0.0)
            row.append((math.sin(a) * rx * fold, cy - math.cos(a) * ry * fold, z_j))
        rows.append(row)
    ob = grid("Skirt", rows, True, tag("skirt"))
    bh.skin_to(ob, body, arm)
    limit_groups(ob, {"hips", "spine", "thigh.L", "thigh.R", "shin.L", "shin.R"}, "hips")
    spec["covers"] = lambda c: False
    return ob


def build_coat_tail(ref, arm, v, spec):
    """Long lower coat (open-front lab coat or full closed priest cassock) draped cleanly below the waist."""
    co = np.array([vert.co[:] for vert in ref.data.vertices])
    co = co[np.abs(co[:, 0]) < 0.34]
    z1, z0 = 1.04, spec.get("z0", 0.42)
    open_f = bool(spec.get("open_front", True))
    ragged = bool(spec.get("ragged", False))
    n_ang = 32
    levels = 11
    rows = []
    # Angle a = 0 is straight front (-Y); if open_front, leave gap [-0.36, +0.36] rad around a = 0.
    a_start = 0.36 if open_f else 0.0
    a_end = (math.tau - 0.36) if open_f else math.tau
    for r in range(levels):
        t = r / (levels - 1)
        z = z1 + (z0 - z1) * t
        near = co[np.abs(co[:, 2] - z) < 0.05]
        if len(near) < 4:
            near = co[np.abs(co[:, 2] - z) < 0.12]
        pad = 0.026 + 0.055 * (t ** 1.25)
        rx = float(np.abs(near[:, 0]).max()) + pad
        y_lo, y_hi = float(near[:, 1].min()) - pad, float(near[:, 1].max()) + pad
        cy, ry = (y_lo + y_hi) * 0.5, (y_hi - y_lo) * 0.5
        row = []
        for k in range(n_ang):
            u = k / (n_ang - 1) if open_f else k / n_ang
            a = a_start + (a_end - a_start) * u
            fold = 1.0 + 0.016 * t * math.sin(a * 6 + r * 0.7)
            z_j = z + (0.035 * (t ** 2) * math.sin(a * 9 + v["seed"]) if ragged else 0.0)
            row.append((math.sin(a) * rx * fold, cy - math.cos(a) * ry * fold, z_j))
        rows.append(row)
    ob = grid("CoatTail", rows, not open_f, tag("coat_tail"))
    bh.skin_to(ob, ref, arm)
    limit_groups(ob, {"hips", "spine", "thigh.L", "thigh.R", "shin.L", "shin.R"}, "hips")
    return ob


def build_vest(ref, arm, v, spec):
    """Outer tactical / hi-vis safety vest shell sitting cleanly outside the shirt."""
    ob = bh.duplicate(ref, "Vest")
    def drop(co):
        if abs(co.x) > 0.175 and co.z > 1.26:
            return True
        if co.z > 1.40 and abs(co.x) < 0.085:
            return True
        if co.y < -0.02 and abs(co.x) < 0.022 and co.z > 1.32:
            return True
        return False
    bh.cut(ob, [((0, 0, 1.49), (0, 0, 1)), ((0, 0, 0.96), (0, 0, -1)),
                ((0.22, 0, 0), (1, 0, 0)), ((-0.22, 0, 0), (-1, 0, 0))], drop)
    bh.inflate(ob, lambda co, n: 0.027 + (0.005 if co.z < 1.06 else 0.0), smooth_iters=2, wrinkle=0.003)
    bh.apply_modifiers(ob)
    bh.set_material(ob, tag("vest"))
    limit_groups(ob, {"chest", "spine", "hips", "neck", "shoulder.L", "shoulder.R"}, "chest")
    return ob


def build_apron(ref, arm, v, spec):
    """Butcher / market vendor apron: chest bib, neck strap, waist tie, and front draped skirt panel."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    z_top, z_bot = 1.37, 0.50
    rows = []
    for r in range(11):
        t = r / 10.0
        z = z_top + (z_bot - z_top) * t
        # Bib narrows at top chest, widens smoothly around waist & thighs.
        half_w = 0.105 if z > 1.15 else (0.105 + 0.095 * min(1.0, (1.15 - z) / 0.22))
        row = []
        for c in range(13):
            u = (c / 12.0) * 2.0 - 1.0
            x = u * half_w
            # Raycast forward (+Y) from in front of the body onto the front torso/legs!
            hit = tree.ray_cast(Vector((x, -0.5, z)), Vector((0, 1, 0)), 0.7)
            if hit[0] is not None:
                y = hit[0].y - (0.028 + 0.012 * t)
            else:
                y = v["lm"]["waist_ymin"] - (0.032 + 0.018 * t)
            # Curve edges back around the hips/waist.
            y += (u * u) * (0.045 if z < 1.15 else 0.015)
            row.append((x, y, z))
        rows.append(row)
    ap = grid("Apron", rows, False, tag("apron"))

    # Waist tie band wrapping around the back.
    lm = v["lm"]
    waist_pts = []
    for k in range(24):
        a = k / 24.0 * math.tau
        wx = math.sin(a) * (lm["waist_rx"] + 0.028)
        wy = (lm["waist_ymin"] + lm["waist_ymax"]) * 0.5 - math.cos(a) * ((lm["waist_ymax"] - lm["waist_ymin"]) * 0.5 + 0.028)
        waist_pts.append(Vector((wx, wy, 1.01)))
    tie = tube_uv("ApronTie", waist_pts, 0.008, True, tag("apron"), ring=6)

    # Neck strap loop from top bib corners around back of neck.
    nc_y = lm["neck_cy"]
    neck_pts = [
        Vector((-0.095, -0.115, 1.365)),
        Vector((-0.075, -0.08, 1.46)),
        Vector((-0.055, nc_y + 0.065, 1.505)),
        Vector((0.0, nc_y + 0.078, 1.515)),
        Vector((0.055, nc_y + 0.065, 1.505)),
        Vector((0.075, -0.08, 1.46)),
        Vector((0.095, -0.115, 1.365)),
    ]
    strap = tube_uv("ApronStrap", neck_pts, 0.006, False, tag("apron"), ring=6)

    for o in bpy.context.scene.objects:
        o.select_set(o in (ap, tie, strap))
    bpy.context.view_layer.objects.active = ap
    bpy.ops.object.join()
    bind_z_blend(ap, [(0.55, {"hips": 0.6, "thigh.L": 0.2, "thigh.R": 0.2}),
                      (0.95, {"hips": 0.8, "spine": 0.2}),
                      (1.18, {"spine": 0.6, "chest": 0.4}),
                      (1.42, {"chest": 0.85, "neck": 0.15}),
                      (1.52, {"neck": 0.7, "chest": 0.3})])
    return ap


def build_hood_up(ref, arm, v, spec):
    """Creepy tattered hood pulled up snugly over the skull, shadowing the face."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.020
    ry_b = (lm["head_ymax"] - hc.y) + 0.032
    ry_f = (hc.y - lm["head_ymin"]) + 0.032
    rz_top = (lm["crown_z"] - hc.z) + 0.026

    rows = []
    # Sweep from face opening rim (t=0) back over the skull to the shoulders/collar (t=1).
    n_u = 28
    n_t = 12
    for ti in range(n_t):
        t = ti / (n_t - 1)
        row = []
        for ui in range(n_u):
            # u around face opening: 0 = top brow center, pi = under chin
            a = (ui / n_u) * math.tau
            # Opening point (slightly forward of face!)
            ox = math.sin(a) * (rx * 0.92)
            oz = hc.z + math.cos(a) * (rz_top * 0.90) - 0.015 * (1.0 - math.cos(a))
            oy = hc.y - ry_f * (0.98 - 0.25 * (1.0 - math.cos(a)) * 0.5)
            # Back/collar sweep
            theta_back = t * math.pi * 0.88
            bx = math.sin(a) * (rx * (1.0 + 0.22 * t) + 0.03 * max(0.0, -math.cos(a)) * t)
            by = hc.y + math.sin(theta_back - 0.55) * ry_b * 1.08 + 0.025 * t
            bz = hc.z + math.cos(a) * rz_top * (1.0 - 0.28 * t) - 0.175 * (t ** 1.45)
            # Smoothly blend opening -> crown/back -> shoulder drape
            p = Vector((ox, oy, oz)).lerp(Vector((bx, by, bz)), t ** 0.75)
            # Slight eerie rumple
            p.x += 0.004 * math.sin(a * 4 + t * 5 + v["seed"])
            p.y += 0.004 * math.cos(a * 3 + t * 6)
            row.append(tuple(p))
        rows.append(row)
    ob = grid("HoodUp", rows, True, tag("hood_up"))
    bind_z_blend(ob, [(1.46, {"chest": 0.7, "neck": 0.3}),
                      (1.55, {"neck": 0.45, "head": 0.55}),
                      (1.63, {"head": 1.0})])
    return ob


def build_hardhat(ref, v, spec):
    """Construction / firefighter safety helmet with dome, central ridge, and front brim."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.022
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.024
    rz = (lm["crown_z"] - hc.z) + 0.028
    base_z = lm["crown_z"] - 0.088

    rows = []
    # Dome from crown down to rim + flared visor brim.
    for ri in range(11):
        t = ri / 10.0
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            front = max(0.0, math.cos(a))
            if ri <= 7:
                lat = (math.pi * 0.5) * (1.0 - (ri / 7.0) * 0.96)
                r_x = rx * math.cos(lat)
                r_y = ry * math.cos(lat)
                z = base_z + (rz + 0.014) * math.sin(lat)
                # Iconic center top reinforcing ridge!
                ridge = 0.011 * math.exp(-((math.sin(a) * r_x) / 0.022) ** 2) * math.sin(lat)
                z += ridge
                row.append((math.sin(a) * r_x, hc.y - math.cos(a) * r_y, z))
            else:
                # Brim extending out (longer at front visor!).
                bt = (ri - 7) / 3.0
                ext = 0.014 + 0.036 * (front ** 1.6)
                r_x = rx + ext * bt * 0.75
                r_y = ry + ext * bt
                z = base_z - 0.008 * bt
                row.append((math.sin(a) * r_x, hc.y - math.cos(a) * r_y, z))
        rows.append(row)
    ob = grid("Hardhat", rows, True, tag("hardhat"))
    # Slight crooked tilt for worn zombie look.
    rot = Matrix.Translation(hc) @ Euler((0.06, 0.07, 0.04)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    ob.data.transform(rot)
    bind_single_bone(ob, "head")
    return ob


def build_cap(ref, v, spec):
    """Baseball / security guard / driver cap (forward or backwards!)."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.014
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.016
    rz = (lm["crown_z"] - hc.z) + 0.020
    base_z = lm["crown_z"] - 0.086
    back = bool(spec.get("backwards", False))

    # Crown dome
    rows = []
    for ri in range(8):
        lat = (math.pi * 0.5) * (1.0 - (ri / 7.0) * 0.94)
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            row.append((math.sin(a) * rx * math.cos(lat), hc.y - math.cos(a) * ry * math.cos(lat), base_z + rz * math.sin(lat)))
        rows.append(row)
    dome = grid("CapDome", rows, True, tag("cap"))

    # Curved front (or rear) visor bill
    brows = []
    for ri in range(5):
        bt = ri / 4.0
        row = []
        for ai in range(15):
            a = -0.95 + (ai / 14.0) * 1.90
            ext = (0.078 * math.cos(a * 0.85)) * bt
            bx = math.sin(a) * (rx + ext * 0.45)
            by = hc.y - math.cos(a) * (ry + ext)
            bz = base_z - 0.010 * bt - 0.012 * (math.sin(a) ** 2) * bt
            row.append((bx, by, bz))
        brows.append(row)
    bill = grid("CapBill", brows, False, tag("cap"))

    for o in bpy.context.scene.objects:
        o.select_set(o in (dome, bill))
    bpy.context.view_layer.objects.active = dome
    bpy.ops.object.join()
    yaw = math.pi + 0.08 if back else 0.05
    rot = Matrix.Translation(hc) @ Euler((0.05 if not back else -0.08, 0.04, yaw)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    dome.data.transform(rot)
    bind_single_bone(dome, "head")
    return dome


def build_beanie(ref, v, spec):
    """Snug ribbed knit watch-cap / beanie with rolled bottom cuff."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.014
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.016
    rz = (lm["crown_z"] - hc.z) + 0.026
    base_z = lm["crown_z"] - 0.092
    rows = []
    for ri in range(10):
        t = ri / 9.0
        lat = (math.pi * 0.5) * (1.0 - t * 0.96)
        cuff = 0.008 if ri >= 7 else 0.0
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            rib = 1.0 + 0.012 * math.sin(a * 14)
            row.append((math.sin(a) * (rx * math.cos(lat) + cuff) * rib,
                        hc.y - math.cos(a) * (ry * math.cos(lat) + cuff) * rib,
                        base_z + rz * math.sin(lat)))
        rows.append(row)
    ob = grid("Beanie", rows, True, tag("beanie"))
    rot = Matrix.Translation(hc) @ Euler((-0.14, 0.03, 0.0)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    ob.data.transform(rot)
    bind_single_bone(ob, "head")
    return ob


def build_salakot(ref, v, spec):
    """Iconic wide conical Filipino woven sun hat (salakot), tilted rakishly on the head."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    apex_z = lm["crown_z"] + 0.088
    rim_z = lm["crown_z"] - 0.048
    rows = []
    for ri in range(8):
        t = ri / 7.0
        rad = 0.006 + 0.235 * (t ** 0.95)
        z = apex_z + (rim_z - apex_z) * (t ** 0.85)
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            wob = 0.005 * t * math.sin(a * 5 + v["seed"])
            row.append((math.sin(a) * rad, hc.y - math.cos(a) * rad, z + wob))
        rows.append(row)
    ob = grid("Salakot", rows, True, tag("salakot"))
    rot = Matrix.Translation(hc) @ Euler((-0.16, 0.12, 0.08)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    ob.data.transform(rot)
    bind_single_bone(ob, "head")
    return ob


def build_head_bandage(ref, v, spec):
    """Thick layered blood-soaked medical gauze wrapped tightly onto the skull via BVH projection."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    z_mid = lm["crown_z"] - 0.070
    eye_cov = bool(spec.get("eye_cover", False))
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    bmesh.ops.delete(bm_tmp, geom=[vert for vert in bm_tmp.verts if vert.co.z < 1.50 or abs(vert.co.x) > 0.18], context="VERTS")
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    rows = []
    for ri in range(7):
        t = (ri / 6.0) * 2.0 - 1.0
        row = []
        for ai in range(32):
            a = ai / 32.0 * math.tau
            slant = -0.026 * math.sin(a + 0.35) if eye_cov else 0.005 * math.sin(a)
            z = z_mid + t * 0.030 + slant
            ray_d = Vector((math.sin(a), -math.cos(a), 0.0)).normalized()
            orig = Vector((0.0, hc.y, z))
            hit = tree.ray_cast(orig + ray_d * 0.30, -ray_d, 0.32)
            bulge = 0.0085 + 0.004 * (1.0 - t * t) + 0.0015 * math.sin(a * 3 + ri)
            if hit[0] is not None:
                p = hit[0] + ray_d * bulge
            else:
                p = orig + ray_d * (lm["head_rx"] + bulge)
            row.append(tuple(p))
        rows.append(row)
    ob = grid("HeadBandage", rows, True, tag("head_bandage"))
    bind_single_bone(ob, "head")
    return ob


def build_headband(ref, v, spec):
    """Athletic sweatband wrapped tightly around the forehead via BVH projection."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    z_mid = lm["crown_z"] - 0.072
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    bmesh.ops.delete(bm_tmp, geom=[vert for vert in bm_tmp.verts if vert.co.z < 1.50 or abs(vert.co.x) > 0.18], context="VERTS")
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()
    rows = []
    for ri in range(4):
        t = (ri / 3.0) * 2.0 - 1.0
        z = z_mid + t * 0.016
        row = []
        for ai in range(32):
            a = ai / 32.0 * math.tau
            ray_d = Vector((math.sin(a), -math.cos(a), 0.0)).normalized()
            orig = Vector((0.0, hc.y, z))
            hit = tree.ray_cast(orig + ray_d * 0.30, -ray_d, 0.32)
            p = (hit[0] + ray_d * 0.0075) if hit[0] is not None else (orig + ray_d * (lm["head_rx"] + 0.008))
            row.append(tuple(p))
        rows.append(row)
    ob = grid("Headband", rows, True, tag("headband"))
    bind_single_bone(ob, "head")
    return ob


def build_face_mask(ref, v, spec):
    """Blood-stained surgical mask over nose & mouth (or hanging crooked off chin/one ear!)."""
    lm = v["lm"]
    nose = Vector(lm["nose"])
    mouth = Vector(v["mouth"])
    hanging = bool(spec.get("hanging", False))
    rows = []
    z_hi = mouth.z - 0.010 if hanging else nose.z + 0.012
    z_lo = mouth.z - 0.075 if hanging else mouth.z - 0.042
    for ri in range(6):
        t = ri / 5.0
        z = z_hi + (z_lo - z_hi) * t
        row = []
        for ci in range(11):
            u = (ci / 10.0) * 2.0 - 1.0
            x = u * 0.072 + (0.018 * t if hanging else 0.0)
            y = min(nose.y, mouth.y) - 0.014 + (u * u) * 0.058 + 0.004 * math.sin(t * math.pi)
            row.append((x, y, z))
        rows.append(row)
    mask = grid("FaceMask", rows, False, tag("face_mask"))
    # Ear loop straps
    parts = [mask]
    hc = Vector(lm["head_c"])
    for side in (-1.0, 1.0):
        if hanging and side < 0:
            continue
        pts = [
            Vector((side * 0.070, min(nose.y, mouth.y) + 0.042, z_hi - 0.008)),
            Vector((side * (lm["head_rx"] + 0.008), hc.y + 0.005, mouth.z + 0.025)),
            Vector((side * 0.070, min(nose.y, mouth.y) + 0.044, z_lo + 0.012)),
        ]
        parts.append(tube_uv("MaskStrap", pts, 0.0022, False, tag("face_mask"), ring=5))
    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = mask
    bpy.ops.object.join()
    bind_single_bone(mask, "head")
    return mask


def build_glasses(ref, v, spec):
    """Crooked/askew eyeglasses resting snugly across the upper nose bridge & temples."""
    lm = v["lm"]
    eyes = v["eyes"]
    hc = Vector(lm["head_c"])
    eye_z = float((eyes[0][2] + eyes[1][2]) * 0.5)
    # Sit right in front of the eyes on the upper nose bridge (not out past the nose tip!).
    eye_y = float(min(eyes[0][1], eyes[1][1])) - 0.014
    parts = []
    for side in (-1.0, 1.0):
        cx = side * 0.032
        ring = [Vector((cx + math.cos(k / 14.0 * math.tau) * 0.019, eye_y,
                        eye_z + math.sin(k / 14.0 * math.tau) * 0.013)) for k in range(14)]
        parts.append(tube_uv("LensRim", ring, 0.0026, True, tag("glasses"), ring=5, ref_center=Vector((cx, eye_y, eye_z))))
        arm_pts = [
            Vector((cx + side * 0.019, eye_y + 0.002, eye_z + 0.003)),
            Vector((side * (lm["head_rx"] + 0.005), hc.y - 0.025, eye_z + 0.003)),
            Vector((side * (lm["head_rx"] + 0.004), hc.y + 0.028, eye_z - 0.008)),
        ]
        parts.append(tube_uv("TempleArm", arm_pts, 0.0020, False, tag("glasses"), ring=5))
    bridge = [Vector((-0.013, eye_y, eye_z + 0.003)), Vector((0.0, eye_y - 0.002, eye_z + 0.005)), Vector((0.013, eye_y, eye_z + 0.003))]
    parts.append(tube_uv("Bridge", bridge, 0.0024, False, tag("glasses"), ring=5))

    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    pivot = Vector((0.0, eye_y, eye_z))
    tilt = float(spec.get("tilt", 0.09))
    parts[0].data.transform(Matrix.Translation(pivot) @ Euler((0.03, tilt, 0.0)).to_matrix().to_4x4() @ Matrix.Translation(-pivot))
    bind_single_bone(parts[0], "head")
    return parts[0]


def build_necktie(ref, v, spec):
    """Loosened bloody office necktie knotted at the throat and hanging crooked down the chest."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    rows = []
    zs = [1.47, 1.44, 1.38, 1.30, 1.22, 1.14, 1.07, 1.02]
    ws = [0.018, 0.013, 0.016, 0.022, 0.028, 0.034, 0.032, 0.003]
    for i, (z, w) in enumerate(zip(zs, ws)):
        sway = 0.018 * math.sin(i * 0.45)  # slightly askew!
        hit = tree.ray_cast(Vector((sway, -0.5, z)), Vector((0, 1, 0)), 0.7)
        y = (hit[0].y if hit[0] is not None else -0.14) - 0.022
        rows.append([(sway - w, y + 0.004, z), (sway, y, z), (sway + w, y + 0.004, z)])
    ob = grid("Necktie", rows, False, tag("necktie"))
    bind_z_blend(ob, [(1.02, {"spine": 0.7, "hips": 0.3}), (1.24, {"chest": 0.85, "spine": 0.15}), (1.47, {"neck": 0.45, "chest": 0.55})])
    return ob


def build_clerical_collar(ref, v, spec):
    """Priest's dark stiff collar band with bright white front clerical tab."""
    lm = v["lm"]
    rx = lm["neck_rx"] + 0.014
    ry = lm["neck_ry"] + 0.015
    cy = lm["neck_cy"]
    rows = []
    for ri in range(4):
        z = 1.478 + (ri / 3.0) * 0.042
        row = [(math.sin(k / 24.0 * math.tau) * rx, cy - math.cos(k / 24.0 * math.tau) * ry, z) for k in range(24)]
        rows.append(row)
    ob = grid("ClericalCollar", rows, True, tag("clerical_collar"))
    bind_z_blend(ob, [(1.47, {"chest": 0.5, "neck": 0.5}), (1.52, {"neck": 0.85, "head": 0.15})])
    return ob


def build_stethoscope(ref, v, spec):
    """Medical stethoscope tubing draped around the doctor's neck and resting over the chest."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    lm = v["lm"]
    cy = lm["neck_cy"]
    raw = [
        Vector((-0.095, -0.15, 1.18)),
        Vector((-0.088, -0.14, 1.32)),
        Vector((-0.078, -0.09, 1.44)),
        Vector((-0.058, cy + 0.055, 1.495)),
        Vector((0.0, cy + 0.072, 1.505)),
        Vector((0.058, cy + 0.055, 1.495)),
        Vector((0.078, -0.09, 1.44)),
        Vector((0.092, -0.14, 1.32)),
        Vector((0.095, -0.15, 1.21)),
    ]
    pts = []
    for p in raw:
        if p.y < -0.10:
            hit = tree.ray_cast(Vector((p.x, -0.5, p.z)), Vector((0, 1, 0)), 0.7)
            if hit[0] is not None:
                p = Vector((p.x, hit[0].y - 0.028, p.z))
        pts.append(p)
    ob = tube_uv("Stethoscope", pts, 0.007, False, tag("stethoscope"), ring=6)
    bind_z_blend(ob, [(1.18, {"chest": 1.0}), (1.45, {"chest": 0.55, "neck": 0.45}), (1.51, {"neck": 0.8, "chest": 0.2})])
    return ob


def build_belt(ref, v, spec):
    """Heavy waist utility belt with buckle and optional tactical pouches."""
    lm = v["lm"]
    rx = lm["waist_rx"] + 0.025
    cy = (lm["waist_ymin"] + lm["waist_ymax"]) * 0.5
    ry = (lm["waist_ymax"] - lm["waist_ymin"]) * 0.5 + 0.025
    rows = []
    for ri in range(4):
        z = 0.968 + (ri / 3.0) * 0.044
        row = [(math.sin(k / 28.0 * math.tau) * rx, cy - math.cos(k / 28.0 * math.tau) * ry, z) for k in range(28)]
        rows.append(row)
    belt = grid("Belt", rows, True, tag("belt"))
    parts = [belt]

    # Front buckle + optional hip pouches built as crisp UV-mapped boxes!
    def box_part(name, center, half_size):
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new(UV_NAME[0])
        bmesh.ops.create_cube(bm, size=1.0)
        for vert in bm.verts:
            vert.co = Vector((center[0] + vert.co.x * half_size[0] * 2.0,
                              center[1] + vert.co.y * half_size[1] * 2.0,
                              center[2] + vert.co.z * half_size[2] * 2.0))
        for f in bm.faces:
            for loop, uv_c in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
                loop[uv].uv = uv_c
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        o = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(o)
        me.materials.append(tag("belt"))
        return o

    parts.append(box_part("Buckle", (0.0, cy - ry - 0.008, 0.990), (0.028, 0.010, 0.026)))
    if spec.get("pouches"):
        parts.append(box_part("PouchL", (rx + 0.012, cy - 0.02, 0.985), (0.020, 0.036, 0.046)))
        parts.append(box_part("PouchR", (-rx - 0.012, cy - 0.02, 0.985), (0.020, 0.036, 0.046)))
        parts.append(box_part("PouchB", (0.06, cy + ry + 0.010, 0.988), (0.038, 0.022, 0.042)))

    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = belt
    bpy.ops.object.join()
    bind_z_blend(belt, [(0.94, {"hips": 0.85, "spine": 0.15}), (1.03, {"hips": 0.55, "spine": 0.45})])
    return belt


def build_backpack(ref, v, spec):
    """Student/commuter backpack resting cleanly on the upper back with twin shoulder straps."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    # Rounded pack body on +Y back
    rows = []
    for ri in range(8):
        lat = -math.pi * 0.48 + (ri / 7.0) * math.pi * 0.96
        z = 1.24 + math.sin(lat) * 0.185
        r_scale = math.cos(lat) ** 0.55
        row = []
        for ai in range(18):
            a = ai / 18.0 * math.tau
            x = math.cos(a) * 0.135 * r_scale
            y = 0.155 + math.sin(a) * 0.072 * r_scale
            row.append((x, y, z))
        rows.append(row)
    pack = grid("Backpack", rows, True, tag("backpack"))
    parts = [pack]

    # Twin shoulder straps hugging the shoulders & chest surface snugly!
    for side in (-1.0, 1.0):
        pts = [
            Vector((side * 0.105, 0.12, 1.40)),
            Vector((side * 0.112, 0.02, 1.45)),
            Vector((side * 0.112, -0.06, 1.41)),
            Vector((side * 0.115, -0.12, 1.30)),
            Vector((side * 0.125, -0.11, 1.17)),
            Vector((side * 0.135, 0.02, 1.11)),
            Vector((side * 0.125, 0.11, 1.10)),
        ]
        for idx_p in (2, 3, 4):
            hit = tree.ray_cast(Vector((pts[idx_p].x, -0.5, pts[idx_p].z)), Vector((0, 1, 0)), 0.7)
            if hit[0] is not None:
                pts[idx_p] = Vector((pts[idx_p].x, hit[0].y - 0.018, pts[idx_p].z))
        parts.append(tube_uv("Strap", pts, 0.011, False, tag("backpack"), ring=6))

    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = pack
    bpy.ops.object.join()
    bind_z_blend(pack, [(1.06, {"spine": 0.65, "chest": 0.35}), (1.28, {"chest": 1.0})])
    return pack


def build_chefs_hat(ref, v, spec):
    """Tall pleated white chef's toque sitting on the crown."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.010
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.012
    z0 = lm["crown_z"] - 0.068
    rows = []
    # Band -> puffed pleated tall crown -> rounded top!
    profile = [(0.00, 1.00), (0.045, 1.02), (0.095, 1.28), (0.155, 1.34), (0.205, 1.24), (0.235, 0.82), (0.248, 0.12)]
    for ri, (dz, scale) in enumerate(profile):
        row = []
        for ai in range(32):
            a = ai / 32.0 * math.tau
            pleat = 1.0 + (0.045 * math.sin(a * 16.0) if 1 <= ri <= 4 else 0.0)
            row.append((math.sin(a) * rx * scale * pleat, hc.y - math.cos(a) * ry * scale * pleat, z0 + dz))
        rows.append(row)
    ob = grid("ChefsHat", rows, True, tag("chefs_hat"))
    rot = Matrix.Translation(hc) @ Euler((-0.08, 0.07, 0.0)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    ob.data.transform(rot)
    bind_single_bone(ob, "head")
    return ob


def build_bucket_hat(ref, v, spec):
    """Wide sloped-brim fisherman / tourist bucket hat."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.014
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.016
    z_rim = lm["crown_z"] - 0.074
    z_top = lm["crown_z"] + 0.022
    rows = []
    profile = [(z_top, 0.15), (z_top - 0.004, 0.88), (z_top - 0.045, 0.98), (z_rim, 1.04),
               (z_rim - 0.024, 1.36), (z_rim - 0.048, 1.56)]
    for ri, (z, sc) in enumerate(profile):
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            wob = 0.005 * math.sin(a * 5 + v["seed"]) if ri >= 4 else 0.0
            row.append((math.sin(a) * rx * sc, hc.y - math.cos(a) * ry * sc, z + wob))
        rows.append(row)
    ob = grid("BucketHat", rows, True, tag("bucket_hat"))
    rot = Matrix.Translation(hc) @ Euler((-0.06, 0.06, 0.04)).to_matrix().to_4x4() @ Matrix.Translation(-hc)
    ob.data.transform(rot)
    bind_single_bone(ob, "head")
    return ob


def build_moto_helmet(ref, v, spec):
    """Delivery rider cracked motorcycle half-helmet covering crown, temples & nape with short front visor."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.028
    ry = max(hc.y - lm["head_ymin"], lm["head_ymax"] - hc.y) + 0.030
    rz = (lm["crown_z"] - hc.z) + 0.032
    base_z = lm["crown_z"] - 0.105
    rows = []
    for ri in range(10):
        t = ri / 9.0
        lat = (math.pi * 0.5) * (1.0 - t * 1.04)
        row = []
        for ai in range(28):
            a = ai / 28.0 * math.tau
            # Cut front slightly higher around brow/eyes, lower around ears & back of head!
            front = max(0.0, math.cos(a))
            z_cut = base_z + 0.036 * (front ** 1.4)
            z = z_cut + (rz + 0.024 - 0.036 * (front ** 1.4)) * max(0.0, math.sin(lat))
            r_scale = math.cos(max(0.0, lat))
            ext = (0.026 * (front ** 2) if ri == 9 else 0.0)
            row.append((math.sin(a) * rx * r_scale, hc.y - math.cos(a) * (ry * r_scale + ext), z))
        rows.append(row)
    ob = grid("MotoHelmet", rows, True, tag("moto_helmet"))
    bind_single_bone(ob, "head")
    return ob


def build_veil(ref, arm, v, spec):
    """Draping bridal or nun veil flowing from the crown down the back and shoulders."""
    lm = v["lm"]
    hc = Vector(lm["head_c"])
    rx = lm["head_rx"] + 0.022
    ry = (lm["head_ymax"] - hc.y) + 0.026
    z_top = lm["crown_z"] + 0.018
    z_bot = float(spec.get("z0", 0.96))
    rows = []
    n_r = 12
    n_c = 22
    for ri in range(n_r):
        t = ri / (n_r - 1)
        z = z_top + (z_bot - z_top) * (t ** 1.15)
        # Wraps from temples around the back of the head (angles 0.9..2*pi-0.9) and flares softly down the back!
        spread_half = math.radians(118.0 - 22.0 * t)
        rad_x = rx + (0.04 + 0.12 * t) * (1.0 if z < 1.50 else 0.3)
        rad_y = ry + 0.09 * (t ** 1.1)
        row = []
        for ci in range(n_c):
            u = ci / (n_c - 1)
            # Centered at back (+Y -> a = pi)
            a = math.pi + (-spread_half + 2.0 * spread_half * u)
            wave = 0.008 * t * math.sin(ci * 1.9 + ri * 0.8 + v["seed"])
            x = math.sin(a) * (rad_x + wave)
            y = hc.y - math.cos(a) * (rad_y + wave) + 0.03 * t
            z_j = z + (0.03 * (t ** 2) * math.sin(ci * 3.1 + v["seed"]) if ri == n_r - 1 else 0.0)
            row.append((x, y, z_j))
        rows.append(row)
    ob = grid("Veil", rows, False, tag("veil"))
    bind_z_blend(ob, [(1.38, {"chest": 0.85, "neck": 0.15}),
                      (1.52, {"neck": 0.55, "head": 0.45}),
                      (1.62, {"head": 1.0})])
    return ob


def build_sling_bag(ref, v, spec):
    """Crossbody delivery / messenger sling strap across chest & back + hip satchel."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    lm = v["lm"]
    rx = lm["waist_rx"] + 0.028
    # Diagonal loop from left shoulder (+X) down across front chest to right hip (-X), then back up rear!
    pts = [
        Vector((0.115, -0.02, 1.46)),
        Vector((0.06, -0.14, 1.34)),
        Vector((-0.04, -0.15, 1.18)),
        Vector((-rx, -0.06, 0.98)),
        Vector((-rx - 0.01, 0.06, 0.98)),
        Vector((-0.04, 0.14, 1.18)),
        Vector((0.07, 0.12, 1.36)),
    ]
    for idx_p in (1, 2):
        hit = tree.ray_cast(Vector((pts[idx_p].x, -0.5, pts[idx_p].z)), Vector((0, 1, 0)), 0.7)
        if hit[0] is not None:
            pts[idx_p] = Vector((pts[idx_p].x, hit[0].y - 0.020, pts[idx_p].z))
    strap = tube_uv("SlingStrap", pts, 0.014, True, tag("sling_bag"), ring=6)

    # Hip satchel pouch on right hip (-X)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new(UV_NAME[0])
    bmesh.ops.create_cube(bm, size=1.0)
    cx, cy, cz = -rx - 0.036, 0.02, 0.94
    hx, hy, hz = 0.036, 0.088, 0.092
    for vert in bm.verts:
        vert.co = Vector((cx + vert.co.x * hx * 2.0, cy + vert.co.y * hy * 2.0, cz + vert.co.z * hz * 2.0))
    for f in bm.faces:
        for loop, uvc in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
            loop[uv].uv = uvc
    me = bpy.data.meshes.new("SlingSatchel")
    bm.to_mesh(me)
    bm.free()
    bag = bpy.data.objects.new("SlingSatchel", me)
    bpy.context.scene.collection.objects.link(bag)
    me.materials.append(tag("sling_bag"))

    for o in bpy.context.scene.objects:
        o.select_set(o in (strap, bag))
    bpy.context.view_layer.objects.active = strap
    bpy.ops.object.join()
    bind_z_blend(strap, [(0.92, {"hips": 0.8, "spine": 0.2}), (1.18, {"spine": 0.6, "chest": 0.4}), (1.42, {"chest": 1.0})])
    return strap


def build_neck_scarf(ref, v, spec):
    """Loose cloth scarf / towel / bandana wrapped around the neck with hanging front tails."""
    lm = v["lm"]
    rx = lm["neck_rx"] + 0.022
    ry = lm["neck_ry"] + 0.024
    cy = lm["neck_cy"]
    ring_pts = [Vector((math.sin(k / 24.0 * math.tau) * rx, cy - math.cos(k / 24.0 * math.tau) * ry,
                        1.472 + 0.010 * math.sin(k * 0.7))) for k in range(24)]
    collar_ring = tube_uv("ScarfRing", ring_pts, 0.019, True, tag("neck_scarf"), ring=7)
    tail_l = tube_uv("ScarfTailL", [Vector((0.035, cy - ry, 1.46)), Vector((0.055, cy - ry - 0.035, 1.34)),
                                    Vector((0.065, cy - ry - 0.045, 1.22))], [0.016, 0.020, 0.014], False, tag("neck_scarf"), ring=6)
    tail_r = tube_uv("ScarfTailR", [Vector((-0.030, cy - ry, 1.46)), Vector((-0.048, cy - ry - 0.035, 1.36)),
                                    Vector((-0.055, cy - ry - 0.040, 1.26))], [0.015, 0.018, 0.012], False, tag("neck_scarf"), ring=6)
    for o in bpy.context.scene.objects:
        o.select_set(o in (collar_ring, tail_l, tail_r))
    bpy.context.view_layer.objects.active = collar_ring
    bpy.ops.object.join()
    bind_z_blend(collar_ring, [(1.22, {"chest": 1.0}), (1.45, {"chest": 0.55, "neck": 0.45}), (1.50, {"neck": 0.85, "chest": 0.15})])
    return collar_ring


def build_suspenders(ref, v, spec):
    """Twin vertical vintage suspender straps over shoulders hooking onto trousers."""
    bm_tmp = bmesh.new()
    bm_tmp.from_mesh(ref.data)
    tree = BVHTree.FromBMesh(bm_tmp)
    bm_tmp.free()

    parts = []
    for side in (-1.0, 1.0):
        pts = [
            Vector((side * 0.095, -0.14, 0.99)),
            Vector((side * 0.095, -0.15, 1.18)),
            Vector((side * 0.100, -0.14, 1.35)),
            Vector((side * 0.105, -0.02, 1.46)),
            Vector((side * 0.095, 0.12, 1.36)),
            Vector((side * 0.065, 0.12, 1.18)),
            Vector((side * 0.045, 0.11, 0.99)),
        ]
        for idx_p in (0, 1, 2):
            hit = tree.ray_cast(Vector((pts[idx_p].x, -0.5, pts[idx_p].z)), Vector((0, 1, 0)), 0.7)
            if hit[0] is not None:
                pts[idx_p] = Vector((pts[idx_p].x, hit[0].y - 0.020, pts[idx_p].z))
        parts.append(tube_uv("Suspender", pts, 0.009, False, tag("suspenders"), ring=5))
    for o in bpy.context.scene.objects:
        o.select_set(o in parts)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    bind_z_blend(parts[0], [(0.99, {"hips": 0.75, "spine": 0.25}), (1.18, {"spine": 0.6, "chest": 0.4}), (1.40, {"chest": 1.0})])
    return parts[0]


# ---------------------------------------------------------------- dress & assemble

def dress(arm, body, v):
    ref = bh.duplicate(body, "Reference body")
    bh.set_material(body, tag("skin"))
    parts = []
    t_ob = top(body, v)
    if t_ob is not None:
        parts.append(t_ob)
    if "bottom" in v:
        parts.append(bottom(body, v))
    if "shoes" in v:
        parts.append(shoes(body, v))
    for p in parts:
        bh.apply_modifiers(p)

    # Extra layered gear / skirt parts (painted into the single 512x512 gear atlas).
    if "skirt" in v:
        parts.append(skirt(ref, v, arm))

    gear = v.get("gear", {})
    if "coat_tail" in gear:
        parts.append(build_coat_tail(ref, arm, v, gear["coat_tail"]))
    if "vest" in gear:
        parts.append(build_vest(ref, arm, v, gear["vest"]))
    if "apron" in gear:
        parts.append(build_apron(ref, arm, v, gear["apron"]))
    if "hood_up" in gear:
        parts.append(build_hood_up(ref, arm, v, gear["hood_up"]))
    if "hardhat" in gear:
        parts.append(build_hardhat(ref, v, gear["hardhat"]))
    if "cap" in gear:
        parts.append(build_cap(ref, v, gear["cap"]))
    if "beanie" in gear:
        parts.append(build_beanie(ref, v, gear["beanie"]))
    if "salakot" in gear:
        parts.append(build_salakot(ref, v, gear["salakot"]))
    if "chefs_hat" in gear:
        parts.append(build_chefs_hat(ref, v, gear["chefs_hat"]))
    if "bucket_hat" in gear:
        parts.append(build_bucket_hat(ref, v, gear["bucket_hat"]))
    if "moto_helmet" in gear:
        parts.append(build_moto_helmet(ref, v, gear["moto_helmet"]))
    if "veil" in gear:
        parts.append(build_veil(ref, arm, v, gear["veil"]))
    if "head_bandage" in gear:
        parts.append(build_head_bandage(ref, v, gear["head_bandage"]))
    if "headband" in gear:
        parts.append(build_headband(ref, v, gear["headband"]))
    if "face_mask" in gear:
        parts.append(build_face_mask(ref, v, gear["face_mask"]))
    if "glasses" in gear:
        parts.append(build_glasses(ref, v, gear["glasses"]))
    if "necktie" in gear:
        parts.append(build_necktie(ref, v, gear["necktie"]))
    if "clerical_collar" in gear:
        parts.append(build_clerical_collar(ref, v, gear["clerical_collar"]))
    if "stethoscope" in gear:
        parts.append(build_stethoscope(ref, v, gear["stethoscope"]))
    if "belt" in gear:
        parts.append(build_belt(ref, v, gear["belt"]))
    if "backpack" in gear:
        parts.append(build_backpack(ref, v, gear["backpack"]))
    if "sling_bag" in gear:
        parts.append(build_sling_bag(ref, v, gear["sling_bag"]))
    if "neck_scarf" in gear:
        parts.append(build_neck_scarf(ref, v, gear["neck_scarf"]))
    if "suspenders" in gear:
        parts.append(build_suspenders(ref, v, gear["suspenders"]))

    # Layered sculpted 3D strand hair (via hair_kit.py).
    under_hat = any(k in gear for k in ("hardhat", "cap", "beanie", "salakot", "hood_up", "chefs_hat", "bucket_hat", "moto_helmet"))
    if "hood_up" not in gear and v.get("hair", "bald") != "bald":
        h_ob = hair_kit.build_hair(v.get("hair", "bald"), ref, arm, tag("hair"),
                                   uv_name=UV_NAME[0], seed=v["seed"], under_hat=under_hat)
        if h_ob is not None:
            parts.append(h_ob)

    # Delete covered skin under primary shells (with safe margin).
    covers = []
    for k in ("top", "bottom", "shoes", "skirt"):
        if k in v and v[k] and "covers" in v[k]:
            covers.append(v[k]["covers"])
    if covers:
        bm = bmesh.new()
        bm.from_mesh(body.data)
        bmesh.ops.delete(bm, geom=[vert for vert in bm.verts if any(f(vert.co) for f in covers)], context="VERTS")
        bm.to_mesh(body.data)
        bm.free()

    bpy.data.objects.remove(ref)
    for o in bpy.context.scene.objects:
        o.select_set(o == body or o in parts)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.name = body.data.name = "Zombie"
    for poly in body.data.polygons:
        poly.use_smooth = True
    if not any(m.type == "ARMATURE" for m in body.modifiers):
        body.modifiers.new("Armature", "ARMATURE").object = arm
    body.parent = arm
    return body


# ---------------------------------------------------------------- texture packing & baking

def pack_gear_uvs(me, gear_kinds):
    """Packs each gear surface's UVs into its own non-overlapping grid tile inside [0,1]^2."""
    n_k = len(gear_kinds)
    if n_k <= 1:
        return
    cols = math.ceil(math.sqrt(n_k))
    rows = math.ceil(n_k / cols)
    slot_kind = [m.name[4:] if m.name.startswith("gid:") else "" for m in me.materials]
    uv_data = me.uv_layers[0].data
    pad = 0.04
    for poly in me.polygons:
        k_name = slot_kind[poly.material_index]
        if k_name not in gear_kinds:
            continue
        idx = gear_kinds.index(k_name)
        col = idx % cols
        row = idx // cols
        u0 = (col + pad) / cols
        v0 = (row + pad) / rows
        du = (1.0 - 2.0 * pad) / cols
        dv = (1.0 - 2.0 * pad) / rows
        for li in poly.loop_indices:
            u, v_uv = uv_data[li].uv
            u = u % 1.0 if u > 1.0 or u < 0.0 else u
            v_uv = v_uv % 1.0 if v_uv > 1.0 or v_uv < 0.0 else v_uv
            uv_data[li].uv = (u0 + u * du, v0 + v_uv * dv)


def rasterize(me, kinds, size):
    """Per pixel of the UV square: which kind of surface is there and where it sits in 3D."""
    me.calc_loop_triangles()
    n = len(me.loop_triangles)
    uv = np.zeros(len(me.loops) * 2, np.float32)
    me.uv_layers[0].data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2) * size
    co = np.zeros(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    loops = np.zeros(n * 3, np.int32)
    me.loop_triangles.foreach_get("loops", loops)
    verts = np.zeros(n * 3, np.int32)
    me.loop_triangles.foreach_get("vertices", verts)
    polys = np.zeros(n, np.int32)
    me.loop_triangles.foreach_get("polygon_index", polys)
    slot = np.zeros(len(me.polygons), np.int32)
    me.polygons.foreach_get("material_index", slot)
    slot_kind = [m.name[4:] if m.name.startswith("gid:") else "" for m in me.materials]
    pos = np.zeros((size, size, 3), np.float32)
    gid = -np.ones((size, size), np.int16)
    order = sorted(range(n), key=lambda t: slot_kind[slot[polys[t]]] != "skin")
    for t in order:
        kind = slot_kind[slot[polys[t]]]
        if kind not in kinds:
            continue
        a, b, c = uv[loops[t * 3]], uv[loops[t * 3 + 1]], uv[loops[t * 3 + 2]]
        x0, x1 = int(max(0, math.floor(min(a[0], b[0], c[0])))), int(min(size - 1, math.ceil(max(a[0], b[0], c[0]))))
        y0, y1 = int(max(0, math.floor(min(a[1], b[1], c[1])))), int(min(size - 1, math.ceil(max(a[1], b[1], c[1]))))
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9 or x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        w0 = ((b[1] - c[1]) * (xs - c[0]) + (c[0] - b[0]) * (ys - c[1])) / den
        w1 = ((c[1] - a[1]) * (xs - c[0]) + (a[0] - c[0]) * (ys - c[1])) / den
        w2 = 1.0 - w0 - w1
        inside = (w0 >= -0.03) & (w1 >= -0.03) & (w2 >= -0.03)
        if not inside.any():
            continue
        pa, pb, pc = co[verts[t * 3]], co[verts[t * 3 + 1]], co[verts[t * 3 + 2]]
        p = w0[..., None] * pa + w1[..., None] * pb + w2[..., None] * pc
        pos[y0:y1 + 1, x0:x1 + 1][inside] = p[inside]
        gid[y0:y1 + 1, x0:x1 + 1][inside] = kinds.index(kind)
    return pos, gid


def dilate(img, filled, rounds=10):
    for _ in range(rounds):
        grown = filled.copy()
        acc = np.zeros_like(img)
        cnt = np.zeros(filled.shape, np.float32)
        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
            f = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(img, (dy, dx), (0, 1)) * f[..., None]
            cnt += f
        new = (~filled) & (cnt > 0)
        img[new] = acc[new] / cnt[new][:, None]
        grown |= new
        filled = grown
    return img


def save_image(name, rgb):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), np.float32)
    rgba[..., :3] = np.clip(rgb, 0.0, 1.0)
    img.pixels.foreach_set(rgba.ravel())
    os.makedirs(WORK, exist_ok=True)
    img.filepath_raw = os.path.join(WORK, name + ".jpg")
    img.file_format = "JPEG"
    img.save()
    img.pack()
    return img


def textured(name, img, rough):
    m = bpy.data.materials.new(name)
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    node = m.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = img
    m.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    m.use_backface_culling = False
    return m


def paint_gear_part(kind, p, spec, v, salt):
    """Paints any layered gear/accessory surface with material-specific details + grime + blood."""
    if kind == "clerical_collar":
        c = np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
        # Crisp bright white clerical tab right at the center front of the throat!
        tab = (np.abs(p[:, 0]) < 0.022) & (p[:, 1] < -0.02) & (p[:, 2] > 1.484) & (p[:, 2] < 1.514)
        c = mix(c, (0.86, 0.85, 0.82), tab.astype(np.float32))
        c = mix(c, DRIED, smooth(0.55, 0.78, fbm(p, 9.0, v["seed"] + salt)) * 0.45)
        return paint_wounds(c, p, v["wounds"], True)
    if kind == "stethoscope":
        c = np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
        if spec.get("measure_tape"):
            ticks = (np.abs((p[:, 2] * 60.0) % 1.0 - 0.5) < 0.14).astype(np.float32)
            c = mix(c, (0.06, 0.06, 0.06), ticks * 0.85)
        else:
            disc = (p[:, 2] < 1.21) & (p[:, 0] < -0.05)
            c = mix(c, (0.68, 0.70, 0.72), disc.astype(np.float32))
        return mix(c, DRIED, smooth(0.55, 0.78, fbm(p, 12.0, v["seed"] + salt)) * 0.55)
    if kind == "moto_helmet":
        c = np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
        c2 = np.asarray(spec.get("color2", spec["color"]), np.float32)
        stripe = (np.abs(p[:, 0]) < 0.022).astype(np.float32)
        c = mix(c, c2, stripe * 0.92)
        c = mix(c, DRIED, smooth(0.50, 0.76, fbm(p, 9.0, v["seed"] + salt)) * float(spec.get("blood", 0.5)))
        return paint_wounds(c, p, v["wounds"], True)
    if kind == "belt":
        c = np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
        buckle = (np.abs(p[:, 0]) < 0.032) & (p[:, 1] < -0.10)
        c = mix(c, (0.58, 0.56, 0.48), buckle.astype(np.float32))
        c = mix(c, DIRT, smooth(0.45, 0.78, fbm(p, 12.0, v["seed"] + salt)) * 0.55)
        return c
    if kind == "glasses":
        return np.tile(np.asarray(spec["color"], np.float32), (len(p), 1))
    # Default: full cloth/gear weathering painter (skirt, coat_tail, vest, apron, hood_up, hardhat, cap, beanie,
    # salakot, head_bandage, headband, face_mask, necktie, backpack).
    return paint_cloth(p, spec, v, salt)


def bake(body, v):
    me = body.data
    skin_src = bpy.data.images.load(bh.SKIN_TEX)
    sw, sh = skin_src.size
    src = np.zeros(sw * sh * 4, np.float32)
    skin_src.pixels.foreach_get(src)
    src = src.reshape(sh, sw, 4)[..., :3]
    src = np.repeat(np.repeat(src, SIZE // sh, axis=0), SIZE // sw, axis=1)

    atlas_kinds = ["skin", "top", "bottom", "shoes"]
    pos, gid = rasterize(me, atlas_kinds, SIZE)
    out = src.copy()
    # If open_jacket with undershirt (not bare_chest), paint chest region of skin as stained undershirt!
    under_col = (v.get("top") or {}).get("under_color")
    for k, kind in enumerate(atlas_kinds):
        where = gid == k
        if not where.any():
            continue
        p = pos[where]
        if kind == "skin":
            painted = paint_skin(p, src[where], v)
            if under_col is not None:
                in_shirt = (p[:, 2] > 0.94) & (p[:, 2] < 1.44) & (np.abs(p[:, 0]) < 0.24)
                if in_shirt.any():
                    u_spec = {"color": under_col, "blood": float(v["top"].get("blood", 0.7)) * 0.9}
                    painted[in_shirt] = paint_cloth(p[in_shirt], u_spec, v, 55)
            out[where] = painted
        elif kind == "shoes":
            out[where] = paint_shoe(p, v["shoes"], v)
        else:
            out[where] = paint_cloth(p, v[kind], v, 100 * k)
    out = dilate(out, gid >= 0)
    finals = {"atlas": textured("Zombie " + v["name"], save_image("z_" + v["name"], out), 0.78)}

    # Collect all present gear/skirt kinds into ONE packed 512x512 gear atlas.
    slot_names = [m.name[4:] for m in me.materials if m.name.startswith("gid:")]
    gear_kinds = [k for k in slot_names if k not in ("skin", "top", "bottom", "shoes", "hair")]
    gear_specs = dict(v.get("gear", {}))
    if "skirt" in v:
        gear_specs["skirt"] = v["skirt"]
    if gear_kinds:
        pack_gear_uvs(me, gear_kinds)
        gpos, ggid = rasterize(me, gear_kinds, GEAR_SIZE)
        gimg = np.zeros((GEAR_SIZE, GEAR_SIZE, 3), np.float32)
        for k, gk in enumerate(gear_kinds):
            where = ggid == k
            if not where.any():
                continue
            gimg[where] = paint_gear_part(gk, gpos[where], gear_specs[gk], v, 300 + 37 * k)
        gimg = dilate(gimg, ggid >= 0, rounds=8)
        finals["gear"] = textured("Zombie gear " + v["name"], save_image("z_" + v["name"] + "_gear", gimg), 0.84)

    # High-detail procedural strand hair material (with strand normal map!).
    if "hair" in slot_names:
        grime = 0.0 if v.get("clean_hair") else float(v.get("hair_grime", 0.52))
        finals["hair"] = hair_kit.make_hair_material(
            "Zombie hair " + v["name"], "z_" + v["name"], v["hair_col"], WORK,
            seed=v["seed"], grey_mix=float(v.get("grey_mix", 0.0)), zombie_grime=grime
        )

    # Collapse material slots into at most 3 clean final materials (atlas, gear, hair).
    target = []
    for m in me.materials:
        k = m.name[4:] if m.name.startswith("gid:") else ""
        if k == "hair":
            target.append("hair")
        elif k in gear_kinds:
            target.append("gear")
        else:
            target.append("atlas")
    names = list(finals)
    index = [names.index(t) for t in target]
    new_index = [index[poly.material_index] for poly in me.polygons]
    me.materials.clear()
    for nme in names:
        me.materials.append(finals[nme])
    for poly, k in zip(me.polygons, new_index):
        poly.material_index = k
    co = np.array([vert.co[:] for vert in me.vertices])
    print("BOUNDS", v["name"], np.round(co.min(axis=0), 2), np.round(co.max(axis=0), 2))


# ---------------------------------------------------------------- QA validation & output

def validate_mesh(arm, body, name):
    """Checks for unweighted vertices and animation-pose spikes so broken skinning never ships."""
    zero = [v.index for v in body.data.vertices if len(v.groups) == 0]
    if zero:
        raise RuntimeError(f"{name}: {len(zero)} unweighted vertices!")
    bh.set_action(arm, bpy.data.actions["walk_hurt"], 8)
    deps = bpy.context.evaluated_depsgraph_get()
    eval_ob = body.evaluated_get(deps)
    eval_me = eval_ob.to_mesh()
    co = np.array([v.co[:] for v in eval_me.vertices], np.float32)
    eval_ob.to_mesh_clear()
    lo, hi = co.min(axis=0), co.max(axis=0)
    if lo[2] < -0.25 or hi[2] > 2.25 or abs(lo[0]) > 1.2 or abs(hi[0]) > 1.2:
        raise RuntimeError(f"{name}: posed mesh bounds spike detected: min={lo} max={hi}")
    bh.set_action(arm, None)


def export(arm, path, animations):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    for o in bpy.context.scene.objects:
        o.select_set(o == arm or (o.type == "MESH" and o.parent == arm))
    bh.set_action(arm, None)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=animations,
                              export_animation_mode="ACTIONS", export_skins=True, export_morph=False, export_yup=True,
                              export_apply=False, export_force_sampling=True, export_optimize_animation_size=True,
                              export_def_bones=False, export_image_format="JPEG", export_jpeg_quality=88)
    print("EXPORTED", path, os.path.getsize(path))


def build_variant(v, a):
    bh.reset()
    arm, body = load(["walk_hurt"])
    shape_body(body, v)
    body = dress(arm, body, v)
    bake(body, v)
    validate_mesh(arm, body, v["name"])
    body.data.calc_loop_triangles()
    print("VARIANT", v["name"], "triangles", len(body.data.loop_triangles), [m.name for m in body.data.materials])
    if "export" in a:
        export(arm, os.path.join(OUT_DIR, "z_%s.glb" % v["name"]), False)
    if "preview" in a:
        cam = bh.setup_render((420, 700))
        bh.set_action(arm, bpy.data.actions["walk_hurt"], 8)
        bh.shoot(cam, os.path.join(WORK, v["name"] + "_front.png"), (0.0, -3.3, 1.0), (0.0, 0.0, 0.92), lens=50)
        bh.shoot(cam, os.path.join(WORK, v["name"] + "_q.png"), (-1.15, -1.45, 1.62), (0.0, 0.0, 1.48), lens=70)


def build_anims(a):
    bh.reset()
    arm, body = load(CLIPS)
    bh.retarget_run(arm)
    body.shape_key_clear()
    bh.make_crouch_walk(arm)
    crawl_clips.make_crawl(arm)
    crawl_clips.make_down_idle(arm)
    crawl_clips.make_sit_hurt(arm)
    facts = {}
    for name in CLIPS + MADE_CLIPS:
        act = bpy.data.actions.get(name)
        if act is None:
            print("MISSING CLIP", name)
            continue
        facts[name] = round((act.frame_range[1] - act.frame_range[0]) / bh.FPS, 3)
    os.makedirs(WORK, exist_ok=True)
    with open(os.path.join(WORK, "clips.json"), "w") as f:
        json.dump(facts, f, indent=1)
    print("CLIPS", facts)
    if "export" in a:
        for act in list(bpy.data.actions):
            if act.name not in CLIPS + MADE_CLIPS:
                bpy.data.actions.remove(act)
        export(arm, os.path.join(OUT_DIR, "zombie_anims.glb"), True)


def main():
    a = bh.args()
    only = [x[5:] for x in a if x.startswith("only=")]
    start_idx = 0
    for x in a:
        if x.startswith("from="):
            start_idx = int(x[5:])
    if "anims" in a or (not only and start_idx == 0 and "noanims" not in a):
        build_anims(a)
    for idx, v in enumerate(VARIANTS):
        if idx < start_idx:
            continue
        if not only or v["name"] in only:
            build_variant(v, a)


if __name__ == "__main__":
    main()
