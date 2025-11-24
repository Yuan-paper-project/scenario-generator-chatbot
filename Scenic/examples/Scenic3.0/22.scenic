#################################
# DESCRIPTION                   #
#################################

description = "The leading vehicle decelerates suddenly due to an obstacle (trash) and the ego vehicle must perform an emergency brake."

#################################
# MAP AND MODEL                 #
#################################

param map = localPath('../../assets/maps/CARLA/Town05.xodr')
param carla_map = 'Town05'
model scenic.simulators.carla.model

#################################
# CONSTANTS                     #
#################################

MODEL = 'vehicle.mini.cooper_s_2021'

param EGO_SPEED = Range(7,10)
param EGO_BRAKE = Range(0.5, 1.0)

param LEAD_SPEED = Range(7,10)
param LEAD_BRAKE = Range(0.5, 1.0)

SAFE_DIST = 10
INIT_DIST = 50
TERM_DIST = 30

#################################
# AGENT BEHAVIORS               #
#################################

behavior EgoBehavior():
    try:
        do FollowLaneBehavior(globalParameters.EGO_SPEED)
    interrupt when withinDistanceToAnyCars(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.EGO_BRAKE)

behavior LeadBehavior():
    try:
        do FollowLaneBehavior(globalParameters.LEAD_SPEED)
    interrupt when withinDistanceToAnyCars(self, SAFE_DIST):
        take SetBrakeAction(globalParameters.LEAD_BRAKE)

#################################
# SPATIAL RELATIONS             #
#################################

lane = Uniform(*network.lanes)

#################################
# SCENARIO SPECIFICATION        #
#################################

obstacle =  new Trash on lane.centerline

lead =  new Car following roadDirection from obstacle for Range(-50, -30),
        with behavior LeadBehavior()

ego = new Car following roadDirection from lead for Range(-20, -15),
        with blueprint MODEL,
        with behavior EgoBehavior()

require (distance to intersection) > INIT_DIST
terminate when (distance to obstacle) > TERM_DIST