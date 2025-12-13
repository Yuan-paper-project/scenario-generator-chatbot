#################################
# Description                   #
#################################
description = "The ego vehicle is preparing to change lanes to evade a slow-moving leading vehicle; the adversarial car in the target lane starts weaving between lanes, making it difficult for the ego vehicle to predict its position and safely execute the lane change.\n\n"

#################################
# Header                        #
#################################
Town = 'Town05'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model
from scenic.domains.driving.controllers import *
EGO_MODEL = "vehicle.lincoln.mkz_2017"

#################################
# Ego                           #
#################################
param OPT_EGO_SAFETY_DISTANCE = Range(7, 9)  # Distance threshold for braking to avoid collision
param OPT_EGO_SPEED = Range(6, 8)
OPT_OVERTAKE_DISTANCE = 10

behavior EgoBehavior(ego_speed, overtake_distance, safety_distance, lane_change_target):
    try:
        do FollowLaneBehavior(target_speed=ego_speed) until (distance from self to LeadingAgent < overtake_distance)
        do LaneChangeBehavior(laneSectionToSwitch=lane_change_target, target_speed=ego_speed)
        do FollowLaneBehavior(target_speed=ego_speed)
    interrupt when withinDistanceToObjsInLane(self, safety_distance):
        take SetBrakeAction(1)  # Brake to avoid collision

ego = new Car at egoSpawnPt,
    with regionContainedIn egoLaneSec,
    with blueprint EGO_MODEL,
    with behavior EgoBehavior(
        globalParameters.OPT_EGO_SPEED,
        OPT_OVERTAKE_DISTANCE,
        globalParameters.OPT_EGO_SAFETY_DISTANCE,
        targetLaneSec
    )

#################################
# Adversarial                   #
#################################
param OPT_LEADING_SPEED = globalParameters.OPT_EGO_SPEED - 3


LeadingAgent = new Car at LeadingSpawnPt,
    with regionContainedIn egoLaneSec,
    with behavior FollowLaneBehavior(target_speed=globalParameters.OPT_LEADING_SPEED)

#################################
# Adversarial                   #
#################################
param OPT_ADV_SPEED = globalParameters.OPT_EGO_SPEED - 2
param OPT_ADV_DISTANCE = Range(10, 15)
param OPT_LEADING_DIST = Range(30, 50)
param OPT_ADV_DIST = globalParameters.OPT_LEADING_DIST * 0.5

behavior WeavePIDBehavior(target_speed, weave_amplitude=0.3, weave_period=12):
    K_P = 0.2
    K_D = 0.1
    K_I = 0.01
    dt = 0.1
    pid = PIDLateralController(K_P, K_D, K_I, dt)
    pid.windup_guard = 0.5 
    past_steer = 0.0

    while True:
        trajectoryLine = self.laneSection.centerline
        proj = trajectoryLine.project(self.position)
        progress = distance from trajectoryLine[0] to proj

        sine_offset = weave_amplitude * sin(progress / weave_period)
        cte = trajectoryLine.signedDistanceTo(self.position) - sine_offset

        steer = pid.run_step(cte)
        take RegulatedControlAction(target_speed, steer, past_steer)
        past_steer = steer
        wait

behavior AdvBehavior(speed, weave_amplitude=0.3, weave_period=3, distance=Range(10, 20)):
    do FollowLaneBehavior(target_speed=speed) until (distance from self to ego < distance)
    do WeavePIDBehavior(speed, weave_amplitude=weave_amplitude, weave_period=weave_period)

AdvAgent = new Car at AdvSpawnPt,
    with heading AdvSpawnPt.heading,
    with regionContainedIn adjLaneSec,
    with behavior AdvBehavior(
        globalParameters.OPT_ADV_SPEED,
        weave_amplitude=0.3,
        weave_period=3,
        distance=globalParameters.OPT_ADV_DISTANCE
    )

#################################
# Spatial Relation              #
#################################

param OPT_LEADING_DIST = Range(30, 50)
param OPT_ADV_DIST = globalParameters.OPT_LEADING_DIST * 0.5

laneSecsWithLeftLane = []
for lane in network.lanes:
    for laneSec in lane.sections:
        if laneSec.isForward and laneSec._laneToLeft is not None and laneSec._laneToLeft.isForward:
            laneSecsWithLeftLane.append(laneSec)

egoLaneSec = Uniform(*laneSecsWithLeftLane)
targetLaneSec = egoLaneSec._laneToLeft
egoSpawnPt = new OrientedPoint in egoLaneSec.centerline

adjLaneSec = egoLaneSec._laneToLeft
adjLanePt = adjLaneSec.centerline.project(egoSpawnPt.position)
AdvSpawnPt = new OrientedPoint following roadDirection from adjLanePt for globalParameters.OPT_ADV_DIST

LeadingSpawnPt = new OrientedPoint following roadDirection from egoSpawnPt for globalParameters.OPT_LEADING_DIST

adjLaneSec = egoLaneSec._laneToLeft
AdvSpawnPt = new OrientedPoint following roadDirection from adjLanePt for globalParameters.OPT_ADV_DIST

#################################
# Requirements and Restrictions #
#################################

require distance to intersection >= 100  # Ensure the ego vehicle is far from the intersection