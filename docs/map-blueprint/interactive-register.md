# Interactive objects and neighboring buildings

This is the startup inventory. Coordinates are node origins; a gate root may be an abstract (0,0,0) assembly with displaced leaf children. Use leaf transforms and collision bounds before placing the player. `I` and `HOUSE` IDs below are additional documentation labels, not gameplay keys.

## Doors, gates, switches and other usable nodes

| Reference | Name / world origin | Script / properties / path |
| --- | --- | --- |
| I001 / N-f9c52706b3be | EntryDoor (2.43, 0.0, 2.6335) | `res://scripts/hinged_door.gd` {"label": "door"} — `LivingRoom/ReferenceRoomSurroundings/EntryDoor` |
| I002 / N-9691d997a52a | LockedClosetDoor (3.25, 0.0, 0.9) | `res://scripts/locked_room_door.gd` {} — `LivingRoom/LockedClosetDoor` |
| I003 / N-7b231b8eadf8 | CourtyardGate (0.0, 0.0, 0.0) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/CourtyardGate` |
| I004 / N-66621a3ea843 | Warren locked door 00 (-105.7929, -1.1, -7.9154) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 00` |
| I005 / N-ff6ec3556b00 | Warren locked door 01 (-104.8046, -1.1, -2.9965) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 01` |
| I006 / N-2d66b32ea45b | Warren locked door 02 (-104.1166, -1.1, 0.6406) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 02` |
| I007 / N-4c75f3edc3bd | Warren locked door 03 (-103.7463, -1.1, 2.7608) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 03` |
| I008 / N-f0ae1dda3362 | Warren locked door 04 (-110.8872, -1.1, -9.4302) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 04` |
| I009 / N-dffe180ec0bf | Warren locked door 05 (-109.5358, -1.1, -2.6451) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 05` |
| I010 / N-7eaa22b38e90 | Warren locked door 06 (-107.8443, -1.1, 7.6724) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 06` |
| I011 / N-801b626fb67b | Warren locked door 07 (-107.5128, -1.1, 10.8614) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 07` |
| I012 / N-e5c09f568bee | Warren locked door 08 (-107.2658, -1.1, 24.6745) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 08` |
| I013 / N-6ae4ad22ecfd | Warren locked door 09 (-107.8677, -1.1, 34.9592) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 09` |
| I014 / N-e1b3e6c57365 | Warren locked door 10 (-108.4821, -1.1, 46.0604) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 10` |
| I015 / N-76a84d5c483a | Warren locked door 11 (-108.673, -1.1, 52.1783) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 11` |
| I016 / N-a92ca296229c | Warren door 00 (-107.7133, -2.04, 1.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 00` |
| I017 / N-47aca9a35cdc | Warren door 01 (-106.9202, -2.04, 6.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 01` |
| I018 / N-991c6a2d4201 | Warren door 02 (-106.0225, -2.04, 18.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 02` |
| I019 / N-90ce72e82f60 | Warren door 03 (-106.0684, -2.04, 23.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 03` |
| I020 / N-cad5bb28313a | Warren door 04 (-107.0433, -2.04, 40.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 04` |
| I021 / N-390208e6b3d9 | Warren door 05 (-107.2972, -2.04, 45.0) | `res://scripts/warren_door.gd` {"label": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 05` |
| I022 / N-2f4bf0d35c9a | Warren radio (-109.2463, -1.67, 4.7) | `res://scripts/warren_usable.gd` {"kind": "radio"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren radio` |
| I023 / N-ddb6fdc56c03 | Warren switch (-108.7908, -0.75, 1.07) | `res://scripts/warren_usable.gd` {"kind": "switch"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren switch` |
| I024 / N-ce4bb798b611 | Warren locked door 12 (-111.1854, -1.1, 18.8005) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren locked door 12` |
| I025 / N-d5ece850d7ea | Store window (-108.4497, -0.74, 42.5025) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Store window` |
| I026 / N-27cb53f6c916 | Warren pump (-109.4068, -2.02, 31.0) | `res://scripts/warren_usable.gd` {"kind": "pump"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren pump` |
| I027 / N-b720d5194ecc | Warren door 06 (-93.9459, -2.08, 8.48) | `res://scripts/warren_door.gd` {"label": "tin sheet"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 06` |
| I028 / N-bbc8240b2b32 | Warren door 07 (-93.3912, -2.08, 55.18) | `res://scripts/warren_door.gd` {"label": "tin sheet"} — `Balcony/Neighbourhood/Canal settlement/Canal warren/Warren door 07` |
| I029 / N-b73164d43a6d | Nichols Front door (-12.93, -1.7, -81.55) | `res://scripts/nichols_door.gd` {"label": "the front door"} — `Balcony/Neighbourhood/Nichols property/Nichols Front door` |
| I030 / N-5d5350c54f06 | @Node3D@628 (-11.07, -1.7, -81.55) | `res://scripts/nichols_door.gd` {"label": "the front door"} — `Balcony/Neighbourhood/Nichols property/@Node3D@628` |
| I031 / N-39276180d04e | Nichols Parlour door (-19.5, -1.7, -93.0) | `res://scripts/nichols_door.gd` {"label": "parlour door"} — `Balcony/Neighbourhood/Nichols property/Nichols Parlour door` |
| I032 / N-14aca3de465c | Nichols Dining door (-4.5, -1.7, -93.0) | `res://scripts/nichols_door.gd` {"label": "dining door"} — `Balcony/Neighbourhood/Nichols property/Nichols Dining door` |
| I033 / N-1d115eddd7b8 | Nichols Kitchen door (-3.0, -1.7, -95.4) | `res://scripts/nichols_door.gd` {"label": "kitchen door"} — `Balcony/Neighbourhood/Nichols property/Nichols Kitchen door` |
| I034 / N-8074386330ec | Nichols Pantry door (0.0, 0.0, 0.0) | `res://scripts/nichols_locked.gd` {"label": "pantry door"} — `Balcony/Neighbourhood/Nichols property/Nichols Pantry door` |
| I035 / N-79073d976ae5 | Nichols Library door (-21.0, -1.7, -95.4) | `res://scripts/nichols_door.gd` {"label": "library door"} — `Balcony/Neighbourhood/Nichols property/Nichols Library door` |
| I036 / N-e6477c61517c | Nichols Pantry side door (-8.0, -1.7, -99.05) | `res://scripts/nichols_door.gd` {"label": "pantry side door"} — `Balcony/Neighbourhood/Nichols property/Nichols Pantry side door` |
| I037 / N-7e5068883e5c | Nichols Bedroom door (-20.0, 2.7, -84.4) | `res://scripts/nichols_door.gd` {"label": "bedroom door"} — `Balcony/Neighbourhood/Nichols property/Nichols Bedroom door` |
| I038 / N-1c8ce96ed14c | Nichols Nursery door (-4.0, 2.7, -84.4) | `res://scripts/nichols_door.gd` {"label": "nursery door"} — `Balcony/Neighbourhood/Nichols property/Nichols Nursery door` |
| I039 / N-126bd8115868 | Nichols iron door (0.21, -4.24, -98.8) | `res://scripts/nichols_locked.gd` {"label": "the iron door"} — `Balcony/Neighbourhood/Nichols property/Nichols basement/Nichols iron door` |
| I040 / N-858a0aec0042 | Nichols Cellar door (-9.65, -1.7, -91.4) | `res://scripts/nichols_door.gd` {"label": "cellar door"} — `Balcony/Neighbourhood/Nichols property/Nichols Cellar door` |
| I041 / N-cbc4698ece47 | House gate 00 (-10.3089, -2.9, 14.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 00` |
| I042 / N-97a740d2a25e | House gate 01 (-0.4922, -2.9, 14.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 01` |
| I043 / N-bd63c597bb3b | House gate 02 (12.9588, -2.9, 14.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 02` |
| I044 / N-590c01057c77 | House gate 03 (-11.1228, -2.9, 21.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 03` |
| I045 / N-63aadc93011c | House gate 04 (1.1157, -2.9, 21.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 04` |
| I046 / N-b32d43380519 | House gate 05 (13.9612, -2.9, 21.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 05` |
| I047 / N-da4f333ec4fb | House gate 06 (-12.519, -2.9, 45.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 06` |
| I048 / N-001e5b465103 | House gate 07 (-2.989, -2.9, 45.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 07` |
| I049 / N-a9dc04dbb305 | House gate 08 (13.8242, -2.9, 45.75) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 08` |
| I050 / N-a1241bab174c | House gate 09 (-13.8656, -2.9, 52.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 09` |
| I051 / N-33b9b6fc1266 | House gate 10 (-1.5391, -2.9, 52.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 10` |
| I052 / N-1aceaccc56ab | House gate 11 (8.7591, -2.9, 52.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 11` |
| I053 / N-1895eda921d4 | House gate 12 (14.2584, -2.9, 52.25) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 12` |
| I054 / N-cfb79d66f9d0 | House gate 13 (24.25, -2.9, 26.8317) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 13` |
| I055 / N-02b1fc69038b | House gate 14 (24.25, -2.9, 33.6637) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 14` |
| I056 / N-c3db6107a8c9 | House gate 15 (24.25, -2.9, -27.1799) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 15` |
| I057 / N-2c2a038734f2 | House gate 16 (24.25, -2.9, -15.5374) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 16` |
| I058 / N-e3e182b3c151 | House gate 17 (24.25, -2.9, -4.6313) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 17` |
| I059 / N-b57aac0f2f76 | House gate 18 (24.25, -2.9, 7.705) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 18` |
| I060 / N-2549e79392b5 | House gate 19 (46.25, -2.9, 25.2465) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 19` |
| I061 / N-34eb0374525a | House gate 20 (46.25, -2.9, 40.1855) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 20` |
| I062 / N-8c1a90c22d4e | House gate 21 (46.25, -2.9, -28.0866) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 21` |
| I063 / N-c3502f03034f | House gate 22 (46.25, -2.9, -17.1541) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 22` |
| I064 / N-e330fff491ee | House gate 23 (46.25, -2.9, -6.9753) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 23` |
| I065 / N-580c6b1a91f7 | House gate 24 (46.25, -2.9, 1.2424) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 24` |
| I066 / N-6203a88e7252 | House gate 25 (46.25, -2.9, 11.7937) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 25` |
| I067 / N-7a6b8009447e | House gate 26 (17.75, -2.9, -3.5762) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 26` |
| I068 / N-ba9e6801735a | House gate 27 (-22.25, -2.9, -26.1331) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 27` |
| I069 / N-3e4cb7a6fe15 | House gate 28 (-22.25, -2.9, -12.0964) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 28` |
| I070 / N-92bde396ab48 | House gate 29 (-22.25, -2.9, -5.0358) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 29` |
| I071 / N-bb53feb877ac | House gate 30 (-22.25, -2.9, 4.07) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 30` |
| I072 / N-976f2b04d358 | House gate 31 (-22.25, -2.9, 26.9194) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 31` |
| I073 / N-942129feb69c | House gate 32 (-22.25, -2.9, 34.5815) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 32` |
| I074 / N-cd6d2f533020 | House gate 33 (-22.25, -2.9, 43.4218) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 33` |
| I075 / N-cdb4ac7647e7 | House gate 34 (-22.25, -2.9, 53.9118) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 34` |
| I076 / N-af43e0ddea31 | House gate 35 (-22.25, -2.9, 63.0419) | `res://scripts/push_gate.gd` {"locked": true} — `Balcony/Neighbourhood/Neighborhood interactions/House gate 35` |
| I077 / N-94a46294b4a8 | Locked house door 00 (14.7581, -1.71, 55.0692) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 00` |
| I078 / N-ce497d63500e | Old doorbell 0 (14.0581, -1.46, 55.0692) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 0` |
| I079 / N-24db2cd20fab | Locked house door 01 (43.8905, -1.71, -18.9443) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 01` |
| I080 / N-8c5a54d32df3 | Rusted mailbox 1 (43.8905, -1.96, -19.6443) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 1` |
| I081 / N-b3c4be67acb3 | Locked house door 02 (-24.2277, -1.71, 7.1043) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 02` |
| I082 / N-6ae7b3d17141 | Old doorbell 2 (-24.2277, -1.46, 6.4043) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 2` |
| I083 / N-95ef40a32a4f | Locked house door 03 (-24.7103, -1.71, 33.7641) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 03` |
| I084 / N-b0062bd32c53 | Rusted mailbox 3 (-24.7104, -1.96, 33.0641) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 3` |
| I085 / N-826ead7b8d5c | Locked house door 04 (-24.2042, -1.71, 42.6456) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 04` |
| I086 / N-e60a440252b1 | Old doorbell 4 (-24.2042, -1.46, 41.9456) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 4` |
| I087 / N-eb7ffd7a5c40 | Locked house door 05 (-3.9287, -1.71, 55.1428) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 05` |
| I088 / N-df408c323031 | Rusted mailbox 5 (-4.6287, -1.96, 55.1428) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 5` |
| I089 / N-fc150cb8dbcd | Locked house door 06 (-0.6914, -1.71, 12.3065) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 06` |
| I090 / N-fc7828f46063 | Old doorbell 6 (0.0086, -1.46, 12.3065) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 6` |
| I091 / N-3f4994e44443 | Locked house door 07 (11.3297, -1.71, 12.4484) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 07` |
| I092 / N-0065fa05be88 | Rusted mailbox 7 (12.0297, -1.96, 12.4484) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 7` |
| I093 / N-a941ac249411 | Locked house door 08 (-9.7021, -1.71, 43.8923) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 08` |
| I094 / N-8dd03cfc20ec | Old doorbell 8 (-9.0021, -1.46, 43.8923) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 8` |
| I095 / N-73bb80689f45 | Locked house door 09 (-1.2575, -1.71, 43.3118) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 09` |
| I096 / N-afc7ec81c440 | Rusted mailbox 9 (-0.5575, -1.96, 43.3118) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 9` |
| I097 / N-7454afd70505 | Locked house door 10 (12.5054, -1.71, 43.9119) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 10` |
| I098 / N-13d9881e5009 | Old doorbell 10 (13.2054, -1.46, 43.9119) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 10` |
| I099 / N-f55acbf899e0 | Locked house door 11 (26.352, -1.71, 9.0037) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 11` |
| I100 / N-0da47332a199 | Rusted mailbox 11 (26.3519, -1.96, 9.7037) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 11` |
| I101 / N-c872d6cbce73 | Locked house door 12 (43.6974, -1.71, 23.9787) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 12` |
| I102 / N-de5c2eaa6ea6 | Old doorbell 12 (43.6974, -1.46, 23.2787) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 12` |
| I103 / N-404bdbfe2e50 | Locked house door 13 (44.2724, -1.71, -10.0764) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 13` |
| I104 / N-aa3837be1844 | Rusted mailbox 13 (44.2724, -1.96, -10.7764) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 13` |
| I105 / N-9cb08b577375 | Locked house door 14 (44.3276, -1.71, 9.6625) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 14` |
| I106 / N-83abb1244b04 | Old doorbell 14 (44.3276, -1.46, 8.9625) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 14` |
| I107 / N-a16e6a01342d | Locked house door 15 (-24.3433, -1.71, -24.4562) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 15` |
| I108 / N-3a596c7064c8 | Rusted mailbox 15 (-24.3433, -1.96, -25.1562) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 15` |
| I109 / N-ffabbcca7a36 | Locked house door 16 (-24.8695, -1.71, -15.9525) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 16` |
| I110 / N-8cf1d8497a5e | Old doorbell 16 (-24.8695, -1.46, -16.6525) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 16` |
| I111 / N-f0b9dea55d57 | Locked house door 17 (-24.4949, -1.71, -6.9031) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 17` |
| I112 / N-14b1ad3ce4b5 | Rusted mailbox 17 (-24.4949, -1.96, -7.6031) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 17` |
| I113 / N-d7ceb90d946b | Locked house door 18 (-24.3886, -1.71, 24.2274) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 18` |
| I114 / N-fc9df56b0d5b | Old doorbell 18 (-24.3886, -1.46, 23.5274) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 18` |
| I115 / N-a824154383ae | Locked house door 19 (-24.905, -1.71, 55.0397) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 19` |
| I116 / N-b80414937665 | Rusted mailbox 19 (-24.9051, -1.96, 54.3397) | `res://scripts/neighborhood_usable.gd` {"kind": "mailbox"} — `Balcony/Neighbourhood/Neighborhood interactions/Rusted mailbox 19` |
| I117 / N-d7032a3b64b8 | Locked house door 20 (27.1225, -1.71, -12.6486) | `res://scripts/neighborhood_usable.gd` {"kind": "door"} — `Balcony/Neighbourhood/Neighborhood interactions/Locked house door 20` |
| I118 / N-d65736d25c56 | Old doorbell 20 (27.1225, -1.46, -11.9486) | `res://scripts/neighborhood_usable.gd` {"kind": "bell"} — `Balcony/Neighbourhood/Neighborhood interactions/Old doorbell 20` |
| I119 / N-2977ce2c29d7 | StudioDoor (-3.23, 0.0, 2.84) | `res://scripts/sliding_door.gd` {"label": "studio door"} — `Studio/StudioDoor` |
| I120 / N-191bd0371919 | DrawerUse (34.2263, -2.048, 148.851) | `res://scripts/hut_usable.gd` {"kind": "drawer"} — `Fields/HutHouse/Dresser/TopDrawer/DrawerUse` |
| I121 / N-dd604bb48bda | GunUse (34.2263, -2.048, 148.851) | `res://scripts/hut_usable.gd` {"kind": "gun"} — `Fields/HutHouse/Dresser/TopDrawer/GunUse` |
| I122 / N-dc8af15fb953 | FlashlightUse (34.2263, -2.048, 148.851) | `res://scripts/hut_usable.gd` {"kind": "flashlight"} — `Fields/HutHouse/Dresser/TopDrawer/FlashlightUse` |
| I123 / N-bd9f3aa639f3 | Key (34.399, -1.786, 149.0401) | `res://scripts/hut_usable.gd` {"kind": "key"} — `Fields/HutHouse/Key` |

## Original neighboring house collision blocks

These are façade/house-shell collider envelopes from the baked neighborhood. They do not establish implemented interiors. The register includes scenery shells outside the sheet-iron perimeter.

| Reference | Node | World min (X,Y,Z) | World max (X,Y,Z) |
| --- | --- | --- | --- |
| HOUSE01 | `Balcony/Neighbourhood/NeighbourhoodColliders/House` | [-4.7276, -2.9, 8.55] | [3.3448, 0.35, 12.2415] |
| HOUSE02 | `Balcony/Neighbourhood/NeighbourhoodColliders/House2` | [6.1025, -2.9, 8.55] | [16.5569, 0.35, 12.3834] |
| HOUSE03 | `Balcony/Neighbourhood/NeighbourhoodColliders/House3` | [-14.4621, -2.9, 35.9819] | [-8.0821, 0.35, 43.8273] |
| HOUSE04 | `Balcony/Neighbourhood/NeighbourhoodColliders/House4` | [-5.6124, -2.9, 35.55] | [3.0975, 0.35, 43.2468] |
| HOUSE05 | `Balcony/Neighbourhood/NeighbourhoodColliders/House5` | [5.0015, -2.9, 35.5977] | [17.0278, 6.25, 43.8469] |
| HOUSE06 | `Balcony/Neighbourhood/NeighbourhoodColliders/House6` | [-5.2975, -2.9, 55.2078] | [0.0778, 0.35, 62.45] |
| HOUSE07 | `Balcony/Neighbourhood/NeighbourhoodColliders/House7` | [12.3374, -2.9, 55.1342] | [17.1788, 0.35, 62.45] |
| HOUSE08 | `Balcony/Neighbourhood/NeighbourhoodColliders/House8` | [27.1875, -2.9, -17.8521] | [34.2786, 3.3, -10.8808] |
| HOUSE09 | `Balcony/Neighbourhood/NeighbourhoodColliders/House9` | [26.417, -2.9, 0.9247] | [34.45, 0.35, 13.871] |
| HOUSE10 | `Balcony/Neighbourhood/NeighbourhoodColliders/House10` | [37.0749, -2.9, 22.0468] | [43.6324, 3.3, 29.6741] |
| HOUSE11 | `Balcony/Neighbourhood/NeighbourhoodColliders/House11` | [36.05, -2.9, -20.4645] | [43.8255, 6.25, -14.4836] |
| HOUSE12 | `Balcony/Neighbourhood/NeighbourhoodColliders/House12` | [37.2287, -2.9, -11.8068] | [44.2075, 3.3, -4.985] |
| HOUSE13 | `Balcony/Neighbourhood/NeighbourhoodColliders/House13` | [36.678, -2.9, 5.4988] | [44.2626, 6.25, 13.8261] |
| HOUSE14 | `Balcony/Neighbourhood/NeighbourhoodColliders/House14` | [-32.1877, -2.9, -28.9913] | [-24.4083, 0.35, -19.9212] |
| HOUSE15 | `Balcony/Neighbourhood/NeighbourhoodColliders/House15` | [-32.45, -2.9, -17.5129] | [-24.9345, 3.3, -11.3715] |
| HOUSE16 | `Balcony/Neighbourhood/NeighbourhoodColliders/House16` | [-32.45, -2.9, -8.4745] | [-24.5599, 6.25, -2.2889] |
| HOUSE17 | `Balcony/Neighbourhood/NeighbourhoodColliders/House17` | [-32.45, -2.9, -0.0101] | [-24.2927, 6.25, 14.2186] |
| HOUSE18 | `Balcony/Neighbourhood/NeighbourhoodColliders/House18` | [-30.7699, -2.9, 22.4078] | [-24.4536, 0.35, 29.5861] |
| HOUSE19 | `Balcony/Neighbourhood/NeighbourhoodColliders/House19` | [-32.45, -2.9, 32.3357] | [-24.7753, 3.3, 37.9493] |
| HOUSE20 | `Balcony/Neighbourhood/NeighbourhoodColliders/House20` | [-32.45, -2.9, 40.1305] | [-24.2692, 0.35, 45.1606] |
| HOUSE21 | `Balcony/Neighbourhood/NeighbourhoodColliders/House21` | [-32.45, -2.9, 53.5172] | [-24.97, 6.25, 59.5073] |
