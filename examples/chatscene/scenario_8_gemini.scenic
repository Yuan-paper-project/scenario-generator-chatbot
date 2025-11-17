'''The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left front suddenly crosses the road and stops in the middle of the intersection, blocking the ego vehicle's path.'''

# --- Constants (for setup) ---
TOWN = 'Town05'

# --- Global Parameters (Required by CARLA model) ---
param map = localPath(f'../../assets/maps/CARLA/{TOWN}.xodr')
param carla_map = TOWN

# --- Model Import ---
model scenic.simulators.carla.model

# --- Scenario Constants ---
EGO_MODEL = "vehicle.lincoln.mkz_2017"
ADV_SPEED = 3.0
ADV_DISTANCE = 10.0
STOP_DISTANCE = 0.5
GEO_Y_DISTANCE = -5.0

# --- Behavior Definition ---
behavior AdvBehavior(adv_speed, adv_dist, stop_dist):
    do CrossingBehavior(ego, adv_speed, adv_dist) until (distance from self to egoTrajectory) < stop_dist
    while True:
        take SetWalkingSpeedAction(0)

# --- Scene Setup ---
# 1. Get a CONCRETE list of valid intersections
intersections = filter(lambda i: i.is4Way or i.is3Way, network.intersections)

# 2. Get a CONCRETE list of all possible right turns from those intersections
possibleManeuvers = [m for i in intersections for m in i.maneuvers if m.type is ManeuverType.RIGHT_TURN]

# 3. Sample ONCE from the final concrete list.
egoManeuver = Uniform(*possibleManeuvers)

# These are now all 'random values' dependent on egoManeuver
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

### --- START: ERROR FIX --- ###
# Use 'on' instead of 'in'.
# 'on' creates a dependency, which is correct.
# 'in' tries to sample from a random region, which causes the error.
egoSpawnPt = new OrientedPoint on egoInitLane.centerline
### --- END: ERROR FIX --- ###

# --- Object Creation (Updated for 3.0) ---
ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Defining adversarial maneuvers
advManeuvers = filter(lambda i: i.type == ManeuverType.LEFT_TURN, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = advManeuver.connectingLane.centerline[0]
IntSpawnPt = advManeuver.connectingLane.centerline.start

# Setting up the adversarial agent
AdvAgent = new Pedestrian following roadDirection from IntSpawnPt for GEO_Y_DISTANCE,
    facing IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior(ADV_SPEED, ADV_DISTANCE, STOP_DISTANCE)

# --- Requirements ---
require 160 deg <= abs(RelativeHeading(AdvAgent)) <= 180 deg
require any([AdvAgent.position in traj for traj in [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]])