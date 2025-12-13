#################################
# Description                   #
#################################
description = "Scenario Description:\n\nThe ego encounters a parked car blocking its lane and must use the opposite lane to bypass the vehicle, carefully assessing the situation and yielding to oncoming traffic, when an oncoming motorcyclist swerves into the lane unexpectedly, necessitating the ego to brake to avoid a potential accident.\n\n"

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
param OPT_LC_DIST = Range(15, 25)    # Distance threshold for lane change trigger
param OPT_BRAKE_DIST = Range(8, 15)  # Distance threshold for braking to avoid collision

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker < globalParameters.OPT_LC_DIST)
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, is_oppositeTraffic=True, target_speed=globalParameters.OPT_EGO_SPEED)
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec, is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_BRAKE_DIST):
            take SetBrakeAction(1)  # Brake to avoid collision
            terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 30)

Blocker = new Car at IntSpawnPt,
    with heading IntSpawnPt.heading,
    with regionContainedIn None

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(4, 8)
param OPT_LC_DIST = Range(15, 25)    # Distance threshold for lane change trigger
param OPT_BRAKE_DIST = Range(8, 15)  # Distance threshold for braking to avoid collision

behavior AdvBehavior():
    while distance to Blocker > globalParameters.OPT_LC_DIST:
        take SetSpeedAction(globalParameters.OPT_ADV_SPEED)  # Maintain speed until close to blocker
    do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, target_speed=globalParameters.OPT_ADV_SPEED)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)

AdvAgent = new Motorcycle at motoStartPt,
    with heading IntSpawnPt.heading + 180 deg,  # Facing toward ego
    with regionContainedIn egoLaneSec,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 30)
param OPT_MOTO_START_DIST = Range(40, 60)  # How far ahead of ego the motorcyclist starts

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec._laneToLeft is not None and laneSec._laneToRight is None:
            if laneSec._laneToLeft.isForward != laneSec.isForward:
                laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE

motoStartPt = new OrientedPoint following roadDirection from IntSpawnPt for globalParameters.OPT_MOTO_START_DIST

#################################
# Requirements and Restrictions #
#################################
