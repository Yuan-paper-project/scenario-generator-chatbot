#################################
# Description                   #
#################################
description = "The leading vehicle decelerates suddenly due to an obstacle (trash) and the ego vehicle must perform an emergency brake."

#################################
# Header                        #
#################################
param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

MODEL = 'vehicle.mini.cooper_s_2021'

#################################
# Ego                           #
#################################
param EGO_SPEED = Range(7,10)
param EGO_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 10

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(globalParameters.EGO_SPEED)
    interrupt when withinDistanceToAnyCars(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

ego = new Car following roadDirection from lead for Range(-20, -15),
        with blueprint MODEL,
        with behavior EgoBehavior()

#################################
# Adversarial                   #
#################################
param LEAD_SPEED = Range(7,10)
param LEAD_BRAKE = Range(0.5, 1.0)
SAFE_DIST = 10

behavior LeadBehavior():
    try:
        do FollowLaneBehavior(globalParameters.LEAD_SPEED)
    interrupt when withinDistanceToAnyCars(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.LEAD_BRAKE)

obstacle =  new Trash on lane.centerline

lead =  new Car following roadDirection from obstacle for Range(-50, -30),
        with behavior LeadBehavior()

#################################
# Spatial Relation              #
#################################
lane = Uniform(*network.lanes)

#################################
# Requirements and Restrictions #
#################################
INIT_DIST = 50
TERM_DIST = 30

require (distance to intersection) > INIT_DIST
terminate when (distance to obstacle) > TERM_DIST