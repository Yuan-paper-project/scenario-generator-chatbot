"""Scenario Description:

The ego encounters a parked car blocking its lane and must use the opposite lane to bypass the vehicle when an oncoming car suddenly accelerates, closing the gap for the ego to safely return to its lane, necessitating the ego to quickly decide whether to accelerate or brake to avoid a collision.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town01'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

EGO_MODEL = "vehicle.lincoln.mkz_2017"

param OPT_GEO_BLOCKER_Y_DISTANCE = Range(15, 20)
param OPT_ADV_START_DIST = Range(90, 100)
param OPT_ADV_SPEED_INITIAL = Uniform(1,2) # Initial speed in m/s for adversary agent
param OPT_ADC_ACCELERATED_SPEED = globalParameters.OPT_ADV_SPEED_INITIAL + Uniform(3,4) # Speed after adversary accelerates
param OPT_ADV_TRIGGER_SECONDS = Range(2, 4) # Time before adversary accelerates
param OPT_EGO_SPEED = Range(2, 5)
param OPT_EGO_ACCELERATED_SPEED = globalParameters.OPT_EGO_SPEED + Uniform(2,3)
param OPT_EGO_COLLISION_AVOIDANCE_DISTANCE = Range(20, 30) # Distance to trigger braking to avoid collision

OPT_EGO_BYPASS_DISTANCE = 12 # Distance to trigger bypassing the blocker
OPT_EGO_MIN_BYPASS_DISTANCE = 4

#################################
# AGENT BEHAVIORS               #
#################################

behavior AdvBehavior():
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED_INITIAL) for globalParameters.OPT_ADV_TRIGGER_SECONDS seconds
    do FollowLaneBehavior(target_speed=globalParameters.OPT_ADC_ACCELERATED_SPEED)

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker < OPT_EGO_BYPASS_DISTANCE)
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec._laneToLeft, is_oppositeTraffic=True, target_speed=globalParameters.OPT_EGO_SPEED)
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to Blocker > OPT_EGO_BYPASS_DISTANCE)
        do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec, is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_SPEED)  
    interrupt when (distance from self to AdvAgent < globalParameters.OPT_EGO_COLLISION_AVOIDANCE_DISTANCE) and (AdvAgent.laneSection == self.laneSection):
        if(self.laneSection != egoLaneSec and distance from self to Blocker > OPT_EGO_MIN_BYPASS_DISTANCE):
            # Faster Lane Change to avoid collision
            do LaneChangeBehavior(laneSectionToSwitch=egoLaneSec, is_oppositeTraffic=False, target_speed=globalParameters.OPT_EGO_ACCELERATED_SPEED)
            abort
        else:
            # Brake as last resort
            take SetThrottleAction(0)
            take SetBrakeAction(1)
    do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)  # Continue following the lane at the initial speed

#################################
# SPATIAL RELATIONS             #
#################################

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec._laneToLeft is not None and laneSec._laneToRight is None:
            if laneSec._laneToLeft.isForward != laneSec.isForward:
                laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

IntSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_GEO_BLOCKER_Y_DISTANCE

adjLaneSec = egoLaneSec._laneToLeft
AdvSpawnPt = new OrientedPoint following roadDirection from IntSpawnPt for globalParameters.OPT_ADV_START_DIST
AdvSpawnPt = adjLaneSec.centerline.project(AdvSpawnPt.position)

#################################
# SCENARIO SPECIFICATION        #
#################################

# Ego vehicle setup
ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

# Blocking car setup
Blocker = new Car at IntSpawnPt,
    with heading IntSpawnPt.heading,
    with regionContainedIn egoLaneSec

# Adversary car setup: already in the opposite lane (left lane), facing toward ego
AdvAgent = new Car at AdvSpawnPt,
    with heading IntSpawnPt.heading + 180 deg,
    with regionContainedIn adjLaneSec,
    with behavior AdvBehavior()

require distance to intersection > 100