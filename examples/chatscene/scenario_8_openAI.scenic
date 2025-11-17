# Scenario (Scenic 3.0-style) — right-turn ego, adversarial pedestrian crosses and stops

#Scenario Description: The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left front suddenly crosses the road and stops in the middle of the intersection, blocking the ego vehicle's path.

Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

# --- Concrete parameter values (replaced former ranges) ---
# adversary walking speed while crossing
OPT_ADV_SPEED = 3             # chosen from previous Range(0,5)

# how far along the connecting lane the adversary will walk before stopping (distance along lane)
OPT_ADV_DISTANCE = 6            # chosen from previous Range(0,15)

# stopping trigger distance relative to ego trajectory
OPT_STOP_DISTANCE = 0.5       # chosen from previous Range(0,1)

# lateral offset along connecting lane where the adversary spawns (signed meters)
OPT_GEO_Y_DISTANCE = 4.0      # chosen from previous Range(-10,10)

# --- Behavior definition (unchanged semantics) ---
behavior AdvBehavior():
    do CrossingBehavior(ego, OPT_ADV_SPEED, OPT_ADV_DISTANCE) until (distance from self to egoTrajectory) < OPT_STOP_DISTANCE
    while True:
        take SetWalkingSpeedAction(0)

# --- intersection and maneuvers selection ---
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

# spawn location for ego (OrientedPoint on the lane centerline)
egoSpawnPt = new OrientedPoint on egoInitLane.centerline

# create ego vehicle (Scenic 3.0: must use 'new')
ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# adversarial maneuvers: left turns that conflict with ego's right-turn
advManeuvers = filter(lambda i: i.type == ManeuverType.LEFT_TURN, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]

# spawn points along the connecting lane's centerline
advSpawnPt = advManeuver.connectingLane.centerline[0]          # initial point on the connecting lane's centerline
IntSpawnPt = advManeuver.connectingLane.centerline.start      # start of the connecting lane centerline

# create adversarial pedestrian (Scenic 3.0: use 'new', and 'facing' instead of setting heading)
AdvAgent = new Pedestrian following roadDirection from IntSpawnPt for OPT_GEO_Y_DISTANCE,
    with facing IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

# Requirements (kept, semantic intents preserved)
require 160 deg <= abs(RelativeHeading(AdvAgent)) <= 180 deg
require any([AdvAgent.position in traj for traj in [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]])
