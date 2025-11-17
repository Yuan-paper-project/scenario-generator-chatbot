"""
Scenic 3.0 Scenario: Right Turn Intersection with Crossing Pedestrian
---------------------------------------------------------------------
The ego vehicle is turning right at an intersection; the adversarial pedestrian 
on the left front suddenly crosses the road and stops in the middle of the 
intersection, blocking the ego vehicle's path.
"""

Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr') 
param carla_map = Town
model scenic.simulators.carla.model

EGO_MODEL = "vehicle.lincoln.mkz_2017"

# Concrete parameter values (replaced from global parameters)
ADV_SPEED = 5.0          # Moderate pedestrian crossing speed (m/s)
ADV_DISTANCE = 8.0       # Distance pedestrian travels before stopping (m)
STOP_DISTANCE = 0.5      # Distance from trajectory where pedestrian stops (m)
GEO_BLOCKER_Y_DISTANCE = 20.0  # Distance ahead for blocker car (m)
GEO_X_DISTANCE = 0.0     # Lateral offset for pedestrian (m)
GEO_Y_DISTANCE = 4.0     # Forward offset for pedestrian from blocker (m)

behavior AdvBehavior():
    do CrossingBehavior(ego, ADV_SPEED, ADV_DISTANCE) until (distance from self to egoTrajectory) < STOP_DISTANCE
    while True:
        take SetSpeedAction(0)

# Select an intersection with 3-way or 4-way configuration
intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))

# Select a right turn maneuver from the intersection
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.RIGHT_TURN, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoTrajectory = [egoInitLane, egoManeuver.connectingLane, egoManeuver.endLane]
egoSpawnPt = new OrientedPoint in egoInitLane.centerline

# Create ego vehicle with "new" keyword (v3.0 requirement)
ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL

# Setup for the blocking car that the ego must bypass
laneSec = network.laneSectionAt(ego)
IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for GEO_BLOCKER_Y_DISTANCE

# Create blocker with "new" keyword and "facing" instead of "with heading" (v3.0 requirement)
Blocker = new Car at IntSpawnPt,
    facing IntSpawnPt.heading,
    with regionContainedIn None

# Setup for the pedestrian (motorcycle) who suddenly appears and complicates the maneuver
SHIFT = GEO_X_DISTANCE @ GEO_Y_DISTANCE
AdvAgent = new Motorcycle at Blocker offset along IntSpawnPt.heading by SHIFT,
    facing IntSpawnPt.heading + 90 deg,  # Perpendicular to the road, crossing the street
    with regionContainedIn None,
    with behavior AdvBehavior()