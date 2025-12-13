#################################
# Description                   #
#################################
description = "The ego approaches a parked car obstructing its lane and must use the opposite lane to go around when an oncoming car suddenly turns into the ego's target lane without signaling, requiring the ego to wait untill the oncoming car has passed."

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
param OPT_EGO_SAFE_DISTANCE = 60
param OPT_EGO_SPEED = Range(2, 5)
OPT_BYPASS_DISTANCE = 12

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker < OPT_BYPASS_DISTANCE)
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, is_oppositeTraffic=True, target_speed=globalParameters.OPT_EGO_SPEED)
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to AdvAgent) > OPT_BYPASS_DISTANCE
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec, is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)
        terminate
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_EGO_SAFE_DISTANCE):
        take SetBrakeAction(1)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)

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
param OPT_ADV_SPEED = Range(4, 8)
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 30)
param OPT_EGO_SAFE_DISTANCE = 60
OPT_BYPASS_DISTANCE = 12

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED, is_oppositeTraffic=True) until (distance from self to Blocker < globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE)
    do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, target_speed=globalParameters.OPT_ADV_SPEED)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Car at carStartPt,
    with heading IntSpawnPt.heading + 180 deg,  # Facing toward ego
    with regionContainedIn egoLaneSec,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 30)
param OPT_MOTO_START_DIST = Range(40, 60)

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec._laneToLeft is not None and laneSec._laneToRight is None:
            if laneSec._laneToLeft.isForward != laneSec.isForward:
                laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE

carStartPt = new OrientedPoint following roadDirection from IntSpawnPt for globalParameters.OPT_MOTO_START_DIST

#################################
# Requirements and Restrictions #
#################################
