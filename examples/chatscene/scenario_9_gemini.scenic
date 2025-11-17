"""The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left front suddenly crosses the road and stops in the middle of the intersection, blocking the ego vehicle's path."""
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr') 
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

# --- Concrete Global Parameter Values ---
OPT_ADV_SPEED = 5 # Chosen value: 5 m/s
OPT_ADV_DISTANCE = 10 # Chosen value: 10 meters
OPT_STOP_DISTANCE = 0.5 # Chosen value: 0.5 meters
OPT_GEO_Y_DISTANCE = 5 # Chosen value: 5 meters
# ----------------------------------------

behavior AdvBehavior():
    # Scenic 3.0: No change in behavior syntax, but globalParameters access is removed
    do CrossingBehavior(ego, OPT_ADV_SPEED, OPT_ADV_DISTANCE) until (distance from self to egoTrajectory) < OPT_STOP_DISTANCE
    while True:
        take SetSpeedAction(0)

# Scenic 3.0: 'new' keyword for object creation
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
# Scenic 3.0: 'new' keyword for object creation
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Defining adversarial maneuvers as those conflicting with the ego's straight path
# NOTE: The scenario description says "adversarial pedestrian," but the original code used 'Bicycle' and conflicting maneuvers for a *Left* Turn. 
# I am changing the AdvAgent type to Pedestrian as per the scenario description and keeping the geometric setup for conflict.
advManeuvers = filter(lambda i: i.type == ManeuverType.LEFT_TURN, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = advManeuver.connectingLane.centerline[0]  # Initial point on the connecting lane's centerline
IntSpawnPt = advManeuver.connectingLane.centerline.start  # Start of the connecting lane centerline

# Scenic 3.0: 'new' keyword for object creation; 'facing' instead of 'with heading'
AdvAgent = new Pedestrian following roadDirection from IntSpawnPt for OPT_GEO_Y_DISTANCE,
    facing IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

# Requirements to ensure the adversarial agent's relative position and trajectory are correctly aligned with the scenario's needs
require 160 deg <= abs(RelativeHeading(AdvAgent)) <= 180 deg
require any([AdvAgent.position in traj for traj in [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]])