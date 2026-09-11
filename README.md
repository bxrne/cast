# cast

Status: in progress. A fly fishing game in Lua on LOVE 11.5. The river sim runs with seeded water and trout. Fishing itself is not in yet.


## Getting started

Needs LOVE 11.5.

```sh
love .
```

F1 toggles the debug panel. Seeds change only from the panel, shown as number plus bed type. Arrow keys adjust the selected row. Esc quits. F12 saves `current.png` to the LOVE write dir.

## How it works

The river derives bed type, size, meander, and flow from its seed. Trout spawn on ranked habitat lies and run behaviour trees covering flee, bully, rise, seek, and feed, with swim beat set by activity and a body shader painting dorsal to belly plus a behaviour linked flash.

Habitat scoring follows PHABSIM practice. Velocity, depth, and cover each map to a suitability index, combined as a geometric mean HSI and weighted by net energy gain. Energy follows Hughes and Dill drift feeding logic, where intake from the next lane minus cubed hold cost favours slack water beside fast seams.

The code keeps draw and entity apart. Draw owns the river scene, flow field, rocks, splash pool, and shaders. Entity owns trout, species fit, habitat scoring, and behaviour. Shared helpers stay in lib, with love bound gfx living beside the draw code that uses it.
