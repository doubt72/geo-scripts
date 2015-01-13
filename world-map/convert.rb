#!/usr/bin/ruby

# Copyright 2014 Douglas Triggs (douglas@triggs.org)
# 
# I reserve no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

# This is code I'm using to generate global basemap data for a
# possible game I'm working on, i.e., in particular for generating
# user scenarios in the scenario editor.  The data originally comes
# from here:
#
# http://www.naturalearthdata.com/downloads/10m-physical-vectors/
#
# I've included the actual data being used by the script in the
# repository with the script; some of the data wouldn't work, however,
# and had to be loaded and re-exported with QGIS; I've also included
# that data.
#
# The script converts several of the shapefiles directly into JSON
# without doing any processing, in addition, it creates simplified
# versions of the basemap for zoomed out views.  It is quite slow, but
# if you're just simplifying source data, it should work fine.  The
# script was originally adapted from a script I wrote for simplifying
# U.S. State basemap data for an election game (also in this
# repository), however some of the things I needed for that I didn't
# need for this (i.e., detecting triple-points) so those features were
# removed.

require_relative 'utilities'
require 'rgeo/shapefile'

# Convert all the datas
log "starting"

# All of this data (reefs, minor island, bathymetry) is only used when
# "zoomed in" so don't do any processing, just convert this to an
# easier digest format (i.e., JSON).

# Convert reef data
count = 0
reefs = []
name = 'ne_10m_reefs'
RGeo::Shapefile::Reader.open("#{name}/#{name}.shp") do |file|
  file.each do |record|
    reef = []
    record.geometry.each do |line|
      line.points.each do |point|
        count += 1
        reef.push([point.x, point.y])
      end
    end
    reefs.push(reef)
  end
end
log "reefs: #{reefs.length} lines, #{count} points"
File.write('o_reefs.json', reefs.to_json)
#log "done writing reefs"

# Convert minor island data
count = 0
islands = []
name = 'ne_10m_minor_islands'
RGeo::Shapefile::Reader.open("#{name}/#{name}.shp") do |file|
  file.each do |record|
    points = []
    record.geometry.each do |polygon|
      polygon.exterior_ring.points.each do |point|
        count += 1
        points.push(Point.new(point.x, point.y))
      end
    end
    island = Polygon.new(points[0..-2])
    islands.push(island)
  end
end
log "minor islands: #{islands.length} polygons, #{count} points"
#volidate_polygons(islands)
#log "done validating polygons"
File.write('o_minor_islands.json', islands.to_json)
#log "done writing polygons"

# ...And triangulate
island_triangles = []
islands.each do |island|
  triangles = triangulate_heap(island)
  triangles.each do |triangle|
    island_triangles.push(triangle)
  end
end
log "minor islands: #{island_triangles.length} triangles"
#validate_triangulation(island_triangles)
#log "done validating triangles"
File.write('o_minor_islands_t.json', island_triangles.to_json)
#log "done writing triangles"

# Convert bathymetry data
['K_200', 'J_1000', 'I_2000', 'H_3000', 'G_4000', 'F_5000', 'E_6000',
 'D_7000', 'C_8000', 'B_9000', 'A_10000'].reverse.each do |level|
  dir = 'ne_10m_bathymetry_all'
  name = "ne_10m_bathymetry_#{level}"
  count = 0
  data = []
  RGeo::Shapefile::Reader.open("#{dir}/#{name}.shp") do |file|
    file.each do |record|
      points = []
      record.geometry.each do |polygon|
        polygon.exterior_ring.points.each do |point|
          count += 1
          points.push(Point.new(point.x, point.y))
        end
      end
      shape = Polygon.new(points[0..-2])
      data.push(shape)
    end
  end
  log "level #{level}: #{data.length} polygons, #{count} points"
  #volidate_polygons(data)
  #log "done validating polygons"
  File.write("o_depth_#{level.split('_')[1]}_raw.json", data.to_json)
  #log "done writing polygons"

  # ...And triangulate
  data_triangles = []
  data.each do |datum|
#    puts datum.format_string
    triangles = triangulate_heap(datum)
    triangles.each do |triangle|
      data_triangles.push(triangle)
    end
  end
  log "level #{level}: #{data_triangles.length} triangles"
  #validate_triangulation(data_triangles)
  #log "done validating triangles"

  File.write("o_depth_#{level.split('_')[1]}_raw_t.json",
             data_triangles.to_json)
  #log "done writing triangles"

  #...And simplified data
  [0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.1].each do |threshold|
    data2 = []
    data.each do |polygon|
      new_polygon = Polygon.new
      polygon.points.each do |point|
        new_polygon.add(Point.new(point.x, point.y))
      end
      simplify_polygon_heap(new_polygon, threshold)
      if (new_polygon.length > 0)
        data2.push(new_polygon)
      end
    end
    count = 0
    data2.each do |polygon|
      count += polygon.length
    end
    log "simplified #{threshold}: #{data2.length} polygons, #{count} points"
    #volidate_polygons(data2)
    #log "done validating polygons"

    File.write("o_depth_#{level.split('_')[1]}_" +
               "#{threshold.to_s.sub(/\./,'')}.json", data2.to_json)
    #log "done writing polygons"

    # ...And triangulate
    data_triangles = []
    data2.each do |lump|
      triangles = triangulate_heap(lump)
      triangles.each do |triangle|
        data_triangles.push(triangle)
      end
    end
    log "simplified #{threshold}: #{data_triangles.length} triangles"
    #validate_triangulation(data_triangles)
    #log "done validating triangles"
    File.write("o_depth_#{level.split('_')[1]}_" +
               "#{threshold.to_s.sub(/\./,'')}_t.json", data_triangles.to_json)
    #log "done writing triangles"
  end
end

# Load land data
count = 0
land = []
name = 'ne_10m_land'
log "starting land load"
RGeo::Shapefile::Reader.open("#{name}/#{name}.shp") do |file|
  file.each do |record|
    record.geometry.each do |polygon|
      points = []
      polygon.exterior_ring.points.each do |point|
        count += 1
        points.push(Point.new(point.x, point.y))
      end
      shape = Polygon.new(points[0..-2])
      land.push(shape)
    end
  end
end
log "land: #{land.length} polygons, #{count} points"
#volidate_polygons(land)
#log "done validating polygons"
File.write('o_land_raw.json', land.to_json)
#log "done writing polygons"

# ...And triangulate
land_triangles = []
land.each do |lump|
  triangles = triangulate_heap(lump)
  triangles.each do |triangle|
    land_triangles.push(triangle)
  end
end
log "land: #{land_triangles.length} triangles"
#validate_triangulation(land_triangles)
#log "done validating triangles"
File.write("o_land_raw_t.json", land_triangles.to_json)
#log "done writing triangles"

# Simplify!
[0.0001, 0.0003, 0.001, 0.003, 0.01, 0.03, 0.1].each do |threshold|
  # TODO: skip this for now
  land2 = []
  land.each do |polygon|
    new_polygon = Polygon.new
    polygon.points.each do |point|
      new_polygon.add(Point.new(point.x, point.y))
    end
    simplify_polygon_heap(new_polygon, threshold)
    if (new_polygon.length > 0)
      land2.push(new_polygon)
    end
  end
  count = 0
  land2.each do |polygon|
    count += polygon.length
  end
  log "simplified #{threshold}: #{land2.length} polygons, #{count} points"
  #volidate_polygons(land2)
  #log "done validating polygons"
  File.write("o_land_#{threshold.to_s.sub(/\./,'')}.json", land2.to_json)
  #log "done writing polygons"

  # ...And triangulate
  land_triangles = []
  land2.each do |lump|
    triangles = triangulate_heap(lump)
    triangles.each do |triangle|
      land_triangles.push(triangle)
    end
  end
  log "simplified #{threshold}: #{land_triangles.length} triangles"
  #validate_triangulation(land_triangles)
  #log "done validating triangles"
  File.write("o_land_#{threshold.to_s.sub(/\./,'')}_t.json",
             land_triangles.to_json)
  #log "done writing triangles"
end
log "all done"
