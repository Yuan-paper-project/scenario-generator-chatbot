#################################
# Description                   #
#################################
description = "The ego vehicle is attempting to overtake a slow-moving leading vehicle; the adversarial car in the target lane suddenly merges into the ego vehicle's original lane, blocking the ego vehicle from returning to its initial position."

#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_CHANGE_DISTANCE = Range(10, 15)
param OPT_EGO_Brake_DISTANCE = Range(1,5)
param OPT_EGO_SPEED = Range(4, 6)

behavior EgoBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker < globalParameters.OPT_EGO_CHANGE_DISTANCE)
    do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft,is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)
    try:
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec,is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_EGO_Brake_DISTANCE):
        take SetBrakeAction(1)  # Brake if too close to the adversarial vehicle
    do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_BLOCKER_SPEED = globalParameters.OPT_EGO_SPEED - 3 
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(10, 40)

Blocker = new Car at IntSpawnPt,
    with heading IntSpawnPt.heading,
    with regionContainedIn None,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_BLOCKER_SPEED),

#################################
# Adversarial                   #
#################################
param OPT_ADV_DISTANCE_1 = Range(20, 30)
param OPT_ADV_DISTANCE_2 = Range(7, 10)
param OPT_ADV_SPEED_1 = globalParameters.OPT_EGO_SPEED - 2.5 
param OPT_ADV_SPEED_2 = globalParameters.OPT_EGO_SPEED

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED_1) until (distance from self to Blocker < globalParameters.OPT_ADV_DISTANCE_1)
    do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec, is_oppositeTraffic=False, target_speed=globalParameters.OPT_ADV_SPEED_1)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED_1) until (distance from self to ego < globalParameters.OPT_ADV_DISTANCE_2)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED_2)

AdvAgent = new Car at IntSpawnPt offset along IntSpawnPt.heading by SHIFT,
    with heading IntSpawnPt.heading,
    with regionContainedIn leftLaneSec,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_GEO_X_DISTANCE = Range(-8, 0)  
param OPT_GEO_Y_DISTANCE = Range(10, 15)

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if (
            laneSec.isForward and
            laneSec._laneToLeft is not None and
            laneSec._laneToLeft.isForward
        ):
            laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
leftLaneSec = egoLaneSec._laneToLeft

egoSpawnPt = new OrientedPoint in egoLaneSec.centerline
laneSec = network.laneSectionAt(egoSpawnPt)  
IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE
SHIFT = globalParameters.OPT_GEO_X_DISTANCE @ globalParameters.OPT_GEO_Y_DISTANCE

#################################
# Requirements and Restrictions #
#################################
require distance to intersection >= 100
terminate when (distance from ego to Blocker > 70)