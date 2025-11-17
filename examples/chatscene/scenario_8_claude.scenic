'''The ego vehicle is turning right at an intersection; the adversarial pedestrian on the left front suddenly crosses the road and stops in the middle of the intersection, blocking the ego vehicle's path.'''
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

# Precise parameter values (replacing global parameters)
OPT_ADV_SPEED = 2.5  # meters per second (mid-range of 0-5)
OPT_ADV_DISTANCE = 7.5  # meters (mid-range of 0-15)
OPT_STOP_DISTANCE = 0.5  # meters (mid-range of 0-1)
OPT_GEO_Y_DISTANCE = 0  # meters (center of range -10 to 10)

behavior AdvBehavior():
    do CrossingBehavior(ego, OPT_ADV_SPEED, OPT_ADV_DISTANCE) until (distance from self to ego) < OPT_STOP_DISTANCE
    while True:
        take SetWalkingSpeedAction(0)

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]

# Using 'new' keyword for object creation (Scenic 3.0 requirement)
ego = new Car in egoInitLane.centerline,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Defining adversarial maneuvers as those conflicting with the ego's straight path
advManeuvers = filter(lambda i: i.type == ManeuverType.LEFT_TURN, egoManeuver.conflictingManeuvers)
advManeuver = Uniform(*advManeuvers)
advTrajectory = [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]
advSpawnPt = advManeuver.connectingLane.centerline[0]  # Initial point on the connecting lane's centerline
IntSpawnPt = advManeuver.connectingLane.centerline.start  # Start of the connecting lane centerline

# Setting up the adversarial agent (using 'new' keyword and 'facing' instead of 'with heading')
AdvAgent = new Pedestrian following roadDirection from IntSpawnPt for OPT_GEO_Y_DISTANCE,
    facing IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior AdvBehavior()

# Requirements to ensure the adversarial agent's relative position and trajectory are correctly aligned with the scenario's needs
require 160 deg <= abs(RelativeHeading(AdvAgent)) <= 180 deg
require any([AdvAgent.position in traj for traj in [advManeuver.startLane, advManeuver.connectingLane, advManeuver.endLane]])