# Room dimensions and door states

Nichols world origin is `(-12,-1.7,-82)`. All vectors in the copied layout JSON are already Godot Y-up vectors; **add the origin without flipping Z again**. Only `nichols_property.gd:local(x,depth,up)` accepts positive depth and converts it to negative Z.

| Room ID | Room | World floor / ceiling | World X range | World Z range |
| --- | --- | --- | --- | --- |
| NR01 | foyer | -1.70 / 6.30 | -16.00..-8.00, -14.70..-9.30 | -91.40..-82.30, -82.30..-81.70 |
| NR02 | parlour | -1.70 / 2.30 | -24.70..-16.00 | -93.00..-82.30 |
| NR03 | dining | -1.70 / 2.30 | -8.00..0.70 | -93.00..-82.30 |
| NR04 | closet | -1.70 / 2.30 | -16.00..-8.00 | -93.00..-91.40 |
| NR05 | hall | -1.70 / 2.30 | -24.70..0.70 | -95.40..-93.00 |
| NR06 | library | -1.70 / 2.30 | -24.70..-16.00 | -101.70..-95.40 |
| NR07 | pantry | -1.70 / 2.30 | -16.00..-8.00 | -101.70..-95.40 |
| NR08 | kitchen | -1.70 / 2.30 | -8.00..0.70 | -101.70..-95.40 |
| NR09 | corridor_w | 2.70 / 6.30 | -24.70..-16.00 | -84.40..-82.30 |
| NR10 | corridor_e | 2.70 / 6.30 | -8.00..0.70 | -84.40..-82.30 |
| NR11 | bridge | 2.70 / 6.30 | -16.00..-8.00, -14.70..-9.30 | -84.40..-82.30, -82.30..-81.70 |
| NR12 | gallery_w | 2.70 / 6.30 | -16.00..-14.60 | -85.70..-84.40 |
| NR13 | gallery_e | 2.70 / 6.30 | -9.40..-8.00 | -85.70..-84.40 |
| NR14 | master | 2.70 / 6.30 | -24.70..-16.00 | -93.00..-84.40 |
| NR15 | nursery | 2.70 / 6.30 | -8.00..0.70 | -93.00..-84.40 |
| NR16 | sealed | 2.70 / 6.30 | -24.70..0.70, -16.00..-8.00 | -101.70..-93.00, -93.00..-91.40 |
| BR01 | shaft | -4.40 / 2.30 | -15.92..-8.08 | -92.92..-91.48 |
| BR02 | cellar | -4.40 / -1.74 | -24.20..-12.30 | -101.20..-93.08 |
| BR03 | passage | -5.30 / -2.50 | -12.30..-10.50 | -99.40..-98.30 |
| BR04 | corridor | -5.30 / -2.15 | -10.50..0.30 | -100.20..-97.40 |

## Authored interior door states

These are initial source states. Opening or moving a leaf changes the runtime geometry. The front double door, cellar door and terminal chained door have separate setup code.

| Door | World hinge | Width / height | Initial state |
| --- | --- | --- | --- |
| Parlour door | (-19.5, -1.7, -93) | 0.98 / 2.49 | ajar, 38 degrees |
| Dining door | (-4.5, -1.7, -93) | 0.98 / 2.49 | open, 95 degrees |
| Kitchen door | (-3, -1.7, -95.4) | 0.98 / 2.49 | ajar, 50 degrees |
| Pantry door | (-12.45, -1.7, -95.4) | 0.88 / 2.39 | locked, 0 degrees |
| Library door | (-21, -1.7, -95.4) | 0.98 / 2.49 | closed, 0 degrees |
| Pantry side door | (-8, -1.7, -99.05) | 0.88 / 2.39 | closed, 0 degrees |
| Bedroom door | (-20, 2.7, -84.4) | 0.98 / 2.49 | ajar, 30 degrees |
| Nursery door | (-4, 2.7, -84.4) | 0.98 / 2.49 | closed, 0 degrees |

## House room volumes and access

The eight ground-floor volumes include a narrow closet volume under/behind the grand stair. Upstairs, the front bridge and narrow galleries overlook the foyer. The `sealed` upstairs volume is intentionally classified separately: its presence in the model does not establish player access. `BR01 shaft` overlaps ground-floor height because it encloses the stair shaft. The cellar and corridor floors differ by .9 m; their connecting broken passage descends between them.

## Exterior and home dimensions

| Feature | Bounds / dimensions | Vertical reference |
| --- | --- | --- |
| Main living room | Interior approximately X=-3.3..3.3, Z=-2.7..2.7 | Floor near 0; ceiling near 2.9 |
| Kitchen | X=-5.65..-3.3, Z=-2.7..2.7 | Floor 0 |
| Studio | X=-5.65..-1.25, Z=2.9..7.3 (4.4 × 4.4) | Floor 0; ceiling 2.9 |
| Balcony | X=.95..5.6, Z=2.9..4.55; outer parapet 4.75 | Floor 0; ceiling 2.75 |
| Stair | 16 risers, .18125 m rise, .27 m tread; Z=2.9..3.85 | 0 down to -2.9 |
| Courtyard | X=9.65..12.6, Z=2.9..5.3 | Floor -2.9 |
| Hut interior in local frame | X=-1.734..1.695, Z=-1.64..1.691 | Local floor .42; world floor -2.63 |
| Hut doorway | Local +X wall, local Z=-.62...02; top 2.3 | Local, rotated with hut |
| Field road | 4.1 m road width, approximately 6.4 m walking band | Ground -2.9 |
| Concrete canal bridge | 23 m across, 4.4 m along Z | Deck -2.1 |
| Plank canal bridge | 1.15 m wide | East -4.4 to west -5.45 |
| Warren crossings | 4.9 m nominal span, 1 m wide | Deck -2.05 |

