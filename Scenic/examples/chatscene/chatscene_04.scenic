#################################
# Description                   #
#################################
description = "The ego vehicle is trying to change to the left lane; the adversarial car is driving parallel to the ego and blocking its maneuver."

#################################
# Header                        #
#################################
Town = 'Town03'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(1, 5)  # Speed for the ego vehicle
param OPT_EGO_Brake_DISTANCE = Range(4,6)

behavior EgoBehavior():
    try:
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_EGO_Brake_DISTANCE):
        take SetBrakeAction(1)
        take SetThrottleAction(0)  # Stop accelerating
    terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(1, 5)  # Speed for the ego vehicle

AdvAgent = new Car at adjLanePt,
    with heading egoSpawnPt.heading,
    with regionContainedIn adjLaneSec,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)

#################################
# Spatial Relation              #
#################################

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward and laneSec._laneToLeft is not None and laneSec._laneToLeft.isForward:
            laneSecsWithLeftLane.append(laneSec)
fourWayIntersection = filter(lambda i: i.is4Way, network.intersections)
egoLaneSec = Uniform(*laneSecsWithLeftLane)
intersec = Uniform(*fourWayIntersection)

egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

adjLaneSec = egoLaneSec._laneToLeft
adjLanePt = adjLaneSec.centerline.project(egoSpawnPt.position)

#################################
# Requirements and Restrictions #
#################################
require distance to intersection >= 100  