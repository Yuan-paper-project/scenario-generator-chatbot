"""Scenario Description:

The ego-vehicle is standing still on a road from where it can see a pedestrian on the right sidewalk. The pedestrian is not moving.

"""

#################################
# MAP AND MODEL                 #
#################################

Town = 'Town01'
param map = localPath(f'../../assets/maps/CARLA/{Town}.xodr')
param carla_map = Town
model scenic.simulators.carla.model

#################################
# SPATIAL RELATIONS             #
#################################

select_road = Uniform(*network.roads)
select_lane = Uniform(*select_road.lanes)

#################################
# SCENARIO SPECIFICATION        #
#################################

ego = new Car on select_lane.centerline

right_sidewalk = network.laneGroupAt(ego)._sidewalk

new Pedestrian on visible right_sidewalk