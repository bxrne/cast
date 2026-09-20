# cast

A fly fishing game in Lua on LOVE 11.5. Seeded rivers with data-driven trout, bank birds, a live hatch, and a two-beat verlet cast.

## Getting started

Needs LOVE 11.5.

```sh
love .
```

## Controls

- **Space** lift a laid line, start the backcast, or shoot the forward cast. Timing the second beat is the skill.
- **Wheel down** mend the laid line upstream.
- **Wheel up** pay out slack.
- **F** open the fly box. Pick a pattern and tie it on.
- **Net button** open the creel to see landed fish.
- **F1** toggle the debug panel. Seeds change only from the panel.
- **F12** save `current.png` to the LOVE write dir.
- **Esc** close any open drawer.

## How it works

### River

Each seed derives bed type, half-width, meander, and flow speed. Bed types are chalk, peat, gravel, silt, and bedrock, each with its own colour palette, moss, and lichen affinity. A spline centerline with three sinusoidal harmonics offsets along the normal to form the meander. Depth follows a shelf-trough model: shallow at the banks, deepest at the thalweg. Speed couples to depth (V ~ D^-0.42), superelevation, boundary drag, and continuity. The water shader samples a baked flow map for per-texel bed colour, depth tint, and a Fresnel-like sheen.

### Trout

Five taxa from data: brown, rainbow, brook, cutthroat, bull. Each has tuned bed fit, current tolerance, aggression, skittishness, feed period, surface manners, body shader colour, swim beat, slither, and tail amplitude. Species weights scale with bed type, flow, and channel size, then `species.instantiate` copies a taxon and adjusts stress, cruise, surface period, aggression, and rise depth to the beat. The school is 6 to 24 fish placed on ranked habitat lies so each holds in its preferred lane.

### Habitat scoring

Velocity, depth, and cover each map to a suitability index (piecewise tent form). Combined as the geometric mean HSI, weighted by occupancy from rock overlap. Net energy follows Hughes and Dill drift feeding: intake from the next lane minus cubed hold cost favours slack water beside fast seams. Fish rank all grid cells and pick the best unoccupied lie.

### Behaviour tree

Each trout runs its own clone of a seven-node selector:

1. **Fight** hooked fish burst while strong, then the rod drags them toward the shallows or the edge. A tired fish that reaches shallow water or the bank is caught.
2. **Flee** bolt deep away from the player or a flying bird while spooked.
3. **Bully** push a weaker fish off its lie. Only fires for species with aggression above 0.45.
4. **Take** hunt a live fly. Film and emerge phases only. The laid fly is the biggest meal on the film. Fish approach, strike on contact (85% hook rate), or miss. Airborne swarm flies draw a jump that often misses.
5. **Rise** break the surface when depth, hold time, and column height align. Species manners (sip, splash, head-and-tail, porpoise) pick the breach style.
6. **Seek** swim to the next habitat lie.
7. **Feed** hold, nymph-drift, or rest by phase.

Feed phases cycle rest, nymph, emerge, film with species-specific proportions. Column height shifts with phase: 0.12 at rest, 0.22 nymphing near the bed, 0.58 emerging, 0.9 at the film.

### Fly line

A 14-segment verlet rope. The tip follows the cursor, the fly trails behind. Space lifts and casts in two beats: back first, then forward once the line straightens. Early second beats land short. The fly lays out where the physics puts it. Waterborne points snap to the film and drift with the current. Scroll mends push the line upstream; scroll up pays slack and risks throwing a hooked fish.

### Fly box

Twelve patterns from data: Adams, BWO, elk hair caddis, royal wulff, Griffiths gnat, stimulator, partridge and orange, leadwing coachman, pheasant tail, hare's ear, copper john, woolly bugger. Each has rig, water, and tip text. Open with F, navigate with arrows, tie on or off with the button. The tied fly shows on the line end and in the bottom hint.

### Birds

Bank birds (heron, egret) spawn 0 to 2 per beat. Types weight against bed, flow, and channel size. Birds perch on emergent rocks (mid-channel preferred), lift, fly with a glide path, and land again. Fish spook from flying birds and fresh landings. Perched birds peck the nearest catchable fly within 48 px on a seeded timer.

### Insects

Two or three clusters of four to six flies wander the film on noise-driven anchors. States: swarm above the film, skitter on it, startled bursts away, taken is gone until respawn. Fish take events scatter nearby flies. Gulp eats the nearest catchable fly. Bird shadows scatter flies under the flight path; perched birds peck them.

### Splash pool

Rings spread on the film, drops fly on a breach, dimples mark holding fish and skittering flies. Fixed 160-element pool, no allocation after build.

### Debug panel

F1 toggles. Sections: river (seed, current, turbulence, bed exposure, water sheen), life (fish count, bird and fly visibility, takes, hatch), sim (pause, time scale), sound (sfx toggle, master volume), view (fish tags, flow overlay, fps).

