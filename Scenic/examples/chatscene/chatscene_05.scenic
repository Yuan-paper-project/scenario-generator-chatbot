#################################
# Description                   #
#################################
description = "The ego vehicle is attempting to change lanes to avoid a slow-moving leading vehicle; the adversarial car in the target lane suddenly slows down, matching the speed of the leading vehicle, and effectively blocking the ego vehicle from completing the lane change."

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
param OPT_EGO_SPEED = Range(1, 5)
OPT_OVERTAKE_DISTANCE = 12

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED) until (distance from self to LeadingAgent < OPT_OVERTAKE_DISTANCE)
        do LaneChangeBehavior(laneSectionToSwitch=adjLaneSec, target_speed=globalParameters.OPT_EGO_SPEED)
        do FollowLaneBehavior(target_speed=globalParameters.OPT_EGO_SPEED)
    interrupt when withinDistanceToObjsInLane(self,globalParameters.OPT_BRAKE_DIST):
            take SetBrakeAction(1)  # Brake to avoid collision

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(1, 5)
param OPT_LEADING_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(0.8,0.9)  


LeadingAgent = new Car at LeadingSpawnPt,
    with regionContainedIn egoLaneSec,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED)

#################################
# Adversarial                   #
#################################
param OPT_EGO_SPEED = Range(1, 5) 
param OPT_LEADING_DIST = Range(20, 30)   

param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(1.05,1.1,1.15)
param OPT_ADV_BLOCK_DIST = globalParameters.OPT_LEADING_DIST * 0.3
OPT_ADV_DIST = 12
param OPT_LEADING_SPEED = globalParameters.OPT_EGO_SPEED * Uniform(0.8,0.9)  

behavior AdvBehavior():
    try:
        do FollowLaneBehavior(target_speed=globalParameters.OPT_ADV_SPEED)
    interrupt when (distance from self to LeadingAgent < OPT_ADV_DIST):
        do FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED) until (distance from self to AdvAgent > globalParameters.OPT_ADV_BLOCK_DIST)

AdvAgent = new Car at AdvSpawnPt,
    with heading ego.heading,
    with regionContainedIn adjLaneSec,
    with behavior AdvBehavior()

#################################
# Spatial Relation              #
#################################
param OPT_LEADING_DIST = Range(20, 30)   

param OPT_ADV_BLOCK_DIST = globalParameters.OPT_LEADING_DIST * 0.3
OPT_ADV_DIST = 12

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward and laneSec._laneToLeft is not None and laneSec._laneToLeft.isForward:
            laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
adjLaneSec = egoLaneSec._laneToLeft

egoSpawnPt = new OrientedPoint in egoLaneSec.centerline
LeadingSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_LEADING_DIST
adjLanePt = adjLaneSec.centerline.project(egoSpawnPt.position)
AdvSpawnPt = new OrientedPoint following roadDirection from adjLanePt for globalParameters.OPT_ADV_BLOCK_DIST

#################################
# Requirements and Restrictions #
#################################
param OPT_BRAKE_DIST = Range(5, 6)  

require distance to intersection >= 100  # Ensure the ego vehicle is far from the intersection
terminate when distance from ego to egoSpawnPt > 150 # Terminate when ego has moved 150m from spawn point