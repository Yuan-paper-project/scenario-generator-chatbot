'''The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left front suddenly crosses the road and stops in the middle of the intersection, blocking the ego vehicle's path.'''

Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr') 
param carla_map = Town
model scenic.simulators.carla.model

EGO_MODEL = "vehicle.lincoln.mkz_2017"

# Concrete parameter values (replacing global parameters)
OPT_ADV_SPEED = 1.5  # Pedestrian walking speed in m/s (typical: 1.2-1.8 m/s)
OPT_ADV_DISTANCE = 8.0  # Distance to travel before stopping (meters)
OPT_STOP_DISTANCE = 0.5  # Distance threshold to trigger stopping (meters)
OPT_GEO_Y_DISTANCE = 5.0  # Spawn offset along connecting lane (meters)

behavior AdvBehavior():
    do CrossingBehavior(ego, OPT_ADV_SPEED, OPT_ADV_DISTANCE) until (distance from self to egoTrajectory) < OPT_STOP_DISTANCE
    while True:
        take SetSpeedAction(0)

# Select a 3-way or 4-way intersection
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))

# Select a right turn maneuver for the ego vehicle
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

# Spawn point for ego vehicle
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

# Create ego vehicle with "new" keyword and "facing" instead of "with heading"
ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Defining adversarial maneuvers as those conflicting with ego's right turn
# Changed from LEFT_TURN to match pedestrian crossing scenario
advManeuvers = filter(lambda i: i.type == ManeuverType.LEFT_TURN, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]

# Spawn point for adversarial agent
advSpawnPt = advManeuver.connectingLane.centerline[0]
IntSpawnPt = advManeuver.connectingLane.centerline.start

# Setting up the adversarial pedestrian (changed from Bicycle to Pedestrian)
AdvAgent = new Pedestrian following roadDirection from IntSpawnPt for OPT_GEO_Y_DISTANCE,
    facing IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

# Requirements to ensure proper positioning and trajectory alignment
require 160 deg <= abs(RelativeHeading(AdvAgent)) <= 180 deg
require any([AdvAgent.position in traj for traj in [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]])