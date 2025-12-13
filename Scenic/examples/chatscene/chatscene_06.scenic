#################################
# Description                   #
#################################
description = "The ego vehicle is performing a lane change to evade a slow-moving vehicle; the adversarial car in the target lane on the right front suddenly brakes, causing the ego vehicle to react quickly to avoid a collision."

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
param OPT_EGO_SPEED = Range(3, 5)
OPT_EGO_BRAKE_AMOUNT = 1                  # Full brake

param OPT_BRAKE_DISTANCE = Range(5, 10)         # Distance threshold for ego to brake to avoid collision

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior(ego_speed, brake_distance, lane_change_target, brake_amount):
    try:
        do FollowLaneBehavior(target_speed=ego_speed) until (distance from self to LeadingAgent < brake_distance)
        do LaneChangeBehavior(laneSectionToSwitch=lane_change_target, target_speed=ego_speed)
        do FollowLaneBehavior(target_speed=ego_speed)
    interrupt when (distance from self to AdvAgent < brake_distance):
        take SetBrakeAction(brake_amount)  # Brake to avoid collision
        do WaitBehavior() for 5 seconds
        terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        globalParameters.OPT_BRAKE_DISTANCE,
        adjLaneSec,
        OPT_EGO_BRAKE_AMOUNT
    )

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(3, 5)
param OPT_LEADING_SPEED = globalParameters.OPT_EGO_SPEED - 2


LeadingAgent = new Car at LeadingSpawnPt,
    with regionContainedIn egoLaneSec,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED)

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED - 1
     
param OPT_ADV_BRAKE_TRIGGER_DIST = Range(8, 15) # Distance at which adv car brakes
OPT_ADV_BRAKE_AMOUNT = 1                  # Full brake

behavior AdvBehavior(adv_speed, brake_trigger_distance, brake_amount):
    do FollowLaneBehavior(target_speed=adv_speed) until (distance from self to ego < brake_trigger_distance)
    while True:
        take SetBrakeAction(brake_amount)  # Brake to block ego

AdvAgent = new Car at AdvSpawnPt,
    with heading egoSpawnPt.heading,
    with regionContainedIn adjLaneSec,
    with behavior AdvBehavior(
        globalParameters.OPT_ADV_SPEED,
        globalParameters.OPT_ADV_BRAKE_TRIGGER_DIST,
        OPT_ADV_BRAKE_AMOUNT
    )

#################################
# Spatial Relation              #
#################################
param OPT_ADV_BLOCK_DIST = Range(20, 30) 
param OPT_LEADING_DIST = Range(10, 20)          # How far ahead the leading car is from ego (in left lane)
laneSecsWithRightLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward and laneSec._laneToRight is not None and laneSec._laneToRight.isForward:
            laneSecsWithRightLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithRightLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline
adjLaneSec = egoLaneSec._laneToRight

LeadingSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_LEADING_DIST

adjLanePt = adjLaneSec.centerline.project(egoSpawnPt.position)
AdvSpawnPt = new OrientedPoint following roadDirection from adjLanePt for globalParameters.OPT_ADV_BLOCK_DIST

#################################
# Requirements and Restrictions #
#################################

require distance to intersection >= 100  # Ensure the ego vehicle is far from the intersection