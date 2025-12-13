#################################
# Description                   #
#################################
description = "The ego approaches a parked car that is blocking its lane and must use the opposite lane to bypass the vehicle, cautiously monitoring oncoming traffic, and suddenly encounters a jaywalking pedestrian, requiring the ego to quickly assess the situation and respond appropriately to avoid a collision."

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
param OPT_EGO_SPEED = Range(2, 3)
param OPT_BRAKE_DISTANCE = Range(3, 5)
OPT_OVERTAKE_DISTANCE = 12

behavior WaitBehavior():
    while True:
        wait

behavior EgoBehavior(ego_speed, brake_distance,  overtake_trigger):
    initialLane = self.laneSection
    targetLane = initialLane._laneToLeft 
    try:
        do FollowLaneBehavior(target_speed=ego_speed) until (distance from self to Blocker < overtake_trigger)
        do LaneChangeBehavior(laneSectionToSwitch=targetLane, is_oppositeTraffic=True, target_speed=ego_speed)
        do FollowLaneBehavior(target_speed=ego_speed, is_oppositeTraffic=True) until (distance from self to Blocker > overtake_trigger)
        do LaneChangeBehavior(laneSectionToSwitch=initialLane, is_oppositeTraffic=False, target_speed=ego_speed)
        do FollowLaneBehavior(target_speed=ego_speed)
    interrupt when withinDistanceToObjsInLane(self, brake_distance):
        take SetBrakeAction(1)  
        take SetThrottleAction(0)
        do WaitBehavior() for 5 seconds
        terminate

ego = new Car at egoSpawnPt,
    with regionContainedIn None,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        globalParameters.OPT_BRAKE_DISTANCE,
        OPT_OVERTAKE_DISTANCE
    )

#################################
# Adversarial                   #
#################################

Blocker = new Car at IntSpawnPt,
    with heading IntSpawnPt.heading,
    with regionContainedIn None

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = Range(1, 2)
param OPT_ADV_DISTANCE = Range(8, 12)

behavior AdvBehavior(adv_speed, adv_distance):
    do CrossingBehavior(ego, adv_speed, adv_distance)

AdvAgent = new Pedestrian at Blocker offset along IntSpawnPt.heading by SHIFT,
    with heading IntSpawnPt.heading + 90 deg,
    with regionContainedIn None,
    with behavior AdvBehavior(
        globalParameters.OPT_ADV_SPEED,
        globalParameters.OPT_ADV_DISTANCE
    )

#################################
# Spatial Relation              #
#################################

param OPT_GEO_BLOCKER_Y_DISTANCE = Range(20, 30)
param OPT_GEO_X_DISTANCE = Range(-1, 1)
param OPT_GEO_Y_DISTANCE = Range(2, 6)

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec._laneToLeft is not None and laneSec._laneToRight is None:
            if laneSec._laneToLeft.isForward != laneSec.isForward:
                laneSecsWithLeftLane.append(laneSec)
              
egoLaneSec = Uniform(*laneSecsWithLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE
SHIFT = globalParameters.OPT_GEO_X_DISTANCE @ globalParameters.OPT_GEO_Y_DISTANCE

#################################
# Requirements and Restrictions #
#################################
require distance to intersection >= 100  # Ensure the ego vehicle is far from the intersection