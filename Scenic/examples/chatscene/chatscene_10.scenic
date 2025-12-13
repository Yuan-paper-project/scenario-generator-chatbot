#################################
# Description                   #
#################################
description = "The ego encounters a parked car blocking its lane and must use the opposite lane to bypass the vehicle when an oncoming pedestrian enters the lane without warning and suddenly stops, necessitating the ego to brake sharply."

#################################
# Header                        #
#################################
Town = 'Town01'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SPEED = Range(2, 5)
param OPT_EGO_LC_DISTANCE = Range(10, 20)
param OPT_AVOID_DIST = Range(3, 5)

behavior EgoBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker < globalParameters.OPT_EGO_LC_DISTANCE)
    try:
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, is_oppositeTraffic=True, target_speed=globalParameters.OPT_EGO_SPEED)
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self, globalParameters.OPT_AVOID_DIST):
            take SetBrakeAction(1)
            terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
Blocker = new Car at IntSpawnPt,
    with heading IntSpawnPt.heading,
    with regionContainedIn None

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 3)
param OPT_ADV_DISTANCE = Range(8, 10)
OPT_STOP_DISTANCE = 1

behavior CrossAndStopBehavior(actor_reference, adv_speed, adv_distance, stop_reference, stop_distance):
    do CrossingBehavior(actor_reference, adv_speed, adv_distance) until (distance from self to stop_reference <= stop_distance)
    take SetWalkingSpeedAction(0)

AdvAgent = new Pedestrian at PedSpawnPt,
    with heading IntSpawnPt.heading - 90 deg,
    with regionContainedIn None,
    with behavior CrossAndStopBehavior(
        ego,
        globalParameters.OPT_ADV_SPEED,
        globalParameters.OPT_ADV_DISTANCE,
        egoLaneSec._laneToLeft.centerline,
        OPT_STOP_DISTANCE
    )

#################################
# Spatial Relation              #
#################################
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(30, 40)
OPT_SIDEWALK_OFFSET = 6

intersection = Uniform(*filter(lambda i: i.is4Way or i.is3Way, network.intersections))
egoManeuver = Uniform(*filter(lambda m: m.type is ManeuverType.STRAIGHT, intersection.maneuvers))
egoInitLane = egoManeuver.startLane
egoSpawnPt = new OrientedPoint in egoInitLane.centerline
egoLaneSec = network.laneSectionAt(egoSpawnPt)

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE

PedSpawnPt = new OrientedPoint left of IntSpawnPt by OPT_SIDEWALK_OFFSET,
    with heading IntSpawnPt.heading + 90 deg

#################################
# Requirements and Restrictions #
#################################
param OPT_AVOID_DIST = Range(3, 5)

require (distance from egoSpawnPt to intersection) >= 200

