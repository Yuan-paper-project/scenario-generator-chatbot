# --- Scenic 3.0 Script ---
# FIX: Re-added 'param map' to resolve the 'RuntimeError' that occurs when
# the driving model is imported, as it specifically requires 'map' to be a
# global parameter to ensure proper initialization.

Town = 'Town05'
# FIX: Changed to 'param' to satisfy the driving model's requirement.
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
carla_map = Town
model scenic.simulators.carla.model

EGO_MODEL = "vehicle.lincoln.mkz_2017"

# --- Concrete Values for Parameters ---
ADV_SPEED = 1.5           # (from OPT_ADV_SPEED) Pedestrian's brisk walk/jog speed (m/s)
ADV_BEHAVIOR_DIST = 5.0   # (from OPT_ADV_DISTANCE) A parameter for CrossingBehavior
STOP_DISTANCE = 0.5       # (from OPT_STOP_DISTANCE) Stops 0.5m from ego's path
BLOCKER_Y_DISTANCE = 15.0 # (from OPT_GEO_BLOCKER_Y_DISTANCE) Blocker car is 15m ahead
PED_X_OFFSET = 1.0        # (from OPT_GEO_X_DISTANCE) Pedestrian offset 1m right of blocker
PED_Y_OFFSET = 3.0        # (from OPT_GEO_Y_DISTANCE) Pedestrian offset 3m in front of blocker

behavior AdvBehavior():
    # Use the concrete speed and distance values
    do CrossingBehavior(ego, ADV_SPEED, ADV_BEHAVIOR_DIST) until (distance from self to egoTrajectory) < STOP_DISTANCE
    while True:
        take SetSpeedAction(0) # Stop and block the path

# Setup the intersection and ego's path
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

# Create the ego vehicle
# SCENIC 3.0: Added 'new' keyword
ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Setup for the blocking car (occluder)
# Use concrete value for distance
IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for BLOCKER_Y_DISTANCE

# SCENIC 3.0: Added 'new' and replaced 'with heading' with 'facing'
Blocker = new Car at IntSpawnPt,
    facing IntSpawnPt.heading,
    with regionContainedIn None

# Setup for the adversarial pedestrian
# Use concrete values for the offset
SHIFT = PED_X_OFFSET @ PED_Y_OFFSET

# SCENIC 3.0: Added 'new', replaced 'with heading' with 'facing',
# and changed 'Motorcycle' to 'Pedestrian' to match the description.
AdvAgent = new Pedestrian at Blocker offset along IntSpawnPt.heading by SHIFT,
    facing IntSpawnPt.heading + 90 deg,  # Perpendicular to the road
    with regionContainedIn None,
    with behavior AdvBehavior()