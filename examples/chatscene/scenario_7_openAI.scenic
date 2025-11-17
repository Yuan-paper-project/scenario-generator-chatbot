# scenario_7_openAI.scenic
# Scenic 3.0 — Ego turning right, adversarial pedestrian crosses from left-front and stops in intersection

Town = 'Town05'
mapPath = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
carla_map = Town

model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

# -------------------------
# Concrete scenario values
# -------------------------
# Adversary crossing speed (m/s) — pedestrian-like
OPT_ADV_SPEED = 1.5         # m/s

# Distance used by CrossingBehavior (m)
OPT_ADV_DISTANCE = 2.5      # m

# Distance threshold to switch to stopping (m)
OPT_STOP_DISTANCE = 0.5     # m

# Distance ahead of ego spawn to place the blocking car (m)
OPT_GEO_BLOCKER_Y_DISTANCE = 10.0  # m

# Lateral (x) and longitudinal (y) offset relative to blocker (m)
OPT_GEO_X_DISTANCE = -1.0   # m (left of blocker -> left-front of ego)
OPT_GEO_Y_DISTANCE = 4.0    # m (forward relative to blocker)

# -------------------------
# Behavior definitions
# -------------------------
behavior AdvBehavior():
    # Cross until within a small distance of the ego's planned trajectory, then stop
    do CrossingBehavior(ego, OPT_ADV_SPEED, OPT_ADV_DISTANCE) until (distance from self to egoTrajectory) < OPT_STOP_DISTANCE
    while True:
        take SetSpeedAction(0)

# -------------------------
# Scenario geometry & spawns
# -------------------------
# Choose a 3- or 4-way intersection from the map
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))

# Pick a right-turn maneuver at that intersection for the ego
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

# Spawn an oriented point on the initial lane centerline for the ego
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

# Ego vehicle spawn
ego = new Car at egoSpawnPt
    with regionContainedIn None
    with blueprint EGO_MODEL

# Lane section containing the ego (kept from original logic)
laneSec = network.laneSectionAt(ego)

# Spawn point ahead for the blocking car (placed along the road direction)
IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for OPT_GEO_BLOCKER_Y_DISTANCE

# Blocking car (the static/slow car that the ego might need to bypass)
Blocker = new Car at IntSpawnPt facing IntSpawnPt.heading
    with regionContainedIn None
    with blueprint "vehicle.tesla.model3"   # optional: set a specific blocker blueprint if desired

# Compute lateral/longitudinal SHIFT as required by Scenic
SHIFT = (OPT_GEO_X_DISTANCE @ OPT_GEO_Y_DISTANCE)

# Adversarial agent placed left-front relative to the blocker; crosses perpendicular to the road
AdvAgent = new Motorcycle at Blocker offset along IntSpawnPt.heading by SHIFT
    facing IntSpawnPt.heading + 90 deg
    with regionContainedIn None
    with behavior AdvBehavior()
    with blueprint "motorcycle.yamaha_r1"   # optional: choose realistic pedestrian substitute

# End of file
