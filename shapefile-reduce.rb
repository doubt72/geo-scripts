#!/usr/bin/ruby

# (c) Douglas Triggs
# 
# I claim no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

require 'rgeo/shapefile'

# This is basically the code I used to generate state basemap data for
# my election game, so it was really just used once and would need to
# be modified for general use (though modifying it for someone's
# specific use should be fairly straightforward).  The data it was
# originally used was a shapefile that came from the US Census web
# page...  Somewhere.  I don't recall where, but it's public data, so
# shouldn't be hard to find.

# This is slow (very slow), but if you're just simplifying source
# data, it should work fine.

# What this code does is suck in the shapefile, do point
# simplification based on this algorithm described here:
# http://bost.ocks.org/mike/simplify/
# and dumps out a plist (Apple's XML config/data format) that I then
# rendered directly in Cocoa/Objective-C.  The last doesn't matter,
# you could dump it back as shapefiles or something else if you
# wanted.

states = {}

# Grab everything but US Virgin Islands and Puerto Rico
RGeo::Shapefile::Reader.open('statesp020.shp') do |file|
  file.each do |record|
    state = record.attributes["STATE"]
    area = record.attributes["AREA"]
    if (state != "U.S. Virgin Islands" &&
        state != "Puerto Rico" && area > 0.0)
      if (states[state] == nil)
        states[state] = []
      end
      states[state].push([area, record])
    end
  end
end

# Reduce the number of islands, er, artisinally
states.each_key do |state|
  records = states[state].sort! {|x,y| y[0] <=> x[0]}
  if (state == "Alabama" || state == "Mississippi" || state == "Louisiana" ||
      state == "Florida" || state == "Georgia" || state == "South Carolina" ||
      state == "Minnesota" || state == "Oregon" || state == "Maine" ||
      state == "Massachusetts" || state == "Pennsylvania" ||
      state == "New Jersey" || state == "Illinois" || state == "Indiana" ||
      state == "Ohio" || state == "Maryland" || state == "Texas" ||
      state == "California")
    states[state] = [records[0]]
  elsif (state == "Wisconsin")
    states[state] = [records[0], records[3], records[4]]
  elsif (state == "Michigan")
    states[state] = [records[0], records[2], records[3]]
  elsif (state == "New York")
    states[state] = [records[0], records[2], records[3]]
  elsif (state == "Virginia")
    states[state] = records[0..1]
  elsif (state == "North Carolina")
    states[state] = records[0..4]
  elsif (state == "Alaska")
    states[state] = [records[0], records[1], records[2], records[4],
                     records[6], records[7], records[8], records[9],
                     records[10], records[11], records[13], records[14],
                     records[15], records[18]]
  elsif (state == "Washington")
    states[state] = [records[0]] + records[2..5]
  elsif (state == "Rhode Island")
    states[state] = records[0..2] + records[4..5]
  end
end

# Projections for US, Alaska, and Hawaii
# This part is trickier if you're using different data

proj4 = "+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
proj4_a = "+proj=aea +lat_1=55 +lat_2=65 +lat_0=50 +lon_0=-154 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"
proj4_h = "+proj=aea +lat_1=8 +lat_2=18 +lat_0=13 +lon_0=-157 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"

lambert_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4)
alaska_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4_a)
hawaii_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4_h)
x_max = -999999999999
x_min = 999999999999
y_max = -999999999999
y_min = 999999999999
ax_max = -999999999999
ax_min = 999999999999
ay_max = -999999999999
ay_min = 999999999999
hx_max = -999999999999
hx_min = 999999999999
hy_max = -999999999999
hy_min = 999999999999

# Figure out the bounds:
states.each_key do |state|
  states[state].each do |record|
    record[1].geometry.each do |polygon|
      ring = polygon.exterior_ring
      ring.points.each do |point|
        wpoint = lambert_f.point(point.x, point.y)
        if (state == "Alaska")
          wpoint = alaska_f.point(point.x, point.y)
        elsif (state == "Hawaii")
          wpoint = hawaii_f.point(point.x, point.y)
        end
        if (state == "Alaska")
          if (wpoint.projection.x > ax_max)
            ax_max = wpoint.projection.x
          end
          if (wpoint.projection.x < ax_min)
            ax_min = wpoint.projection.x
          end
          if (wpoint.projection.y > ay_max)
            ay_max = wpoint.projection.y
          end
          if (wpoint.projection.y < ay_min)
            ay_min = wpoint.projection.y
          end
        elsif (state == "Hawaii")
          if (wpoint.projection.x > hx_max)
            hx_max = wpoint.projection.x
          end
          if (wpoint.projection.x < hx_min)
            hx_min = wpoint.projection.x
          end
          if (wpoint.projection.y > hy_max)
            hy_max = wpoint.projection.y
          end
          if (wpoint.projection.y < hy_min)
            hy_min = wpoint.projection.y
          end
        else
          if (wpoint.projection.x > x_max)
            x_max = wpoint.projection.x
          end
          if (wpoint.projection.x < x_min)
            x_min = wpoint.projection.x
          end
          if (wpoint.projection.y > y_max)
            y_max = wpoint.projection.y
          end
          if (wpoint.projection.y < y_min)
            y_min = wpoint.projection.y
          end
        end
      end
    end
  end
end

# Here I figure out the ranges for my, er, display later:
x_range = (x_max - x_min) / 120.0
y_range = (y_max - y_min) / 120.0

range = y_range
if (x_range > y_range)
  range = x_range
end

ax_range = (ax_max - ax_min) / 32.5
ay_range = (ay_max - ay_min) / 32.5

arange = ay_range
if (ax_range > ay_range)
  arange = ax_range
end

hx_range = (hx_max - hx_min) / 25.0
hy_range = (hy_max - hy_min) / 25.0

hrange = hy_range
if (hx_range > hy_range)
  hrange = hx_range
end

total = 0

# And here I do the actual projection:
states.each_key do |state|
  revised = []
  state_total = 0
  states[state].each do |record|
    polygon_total = 0
    projected = []
    record[1].geometry.each do |polygon|
      ring = polygon.exterior_ring
      ring.points.each do |point|
        total += 1
        state_total += 1
        polygon_total += 1
        wpoint = lambert_f.point(point.x, point.y)
        if (state == "Alaska")
          wpoint = alaska_f.point(point.x, point.y)
          projected.push([(wpoint.projection.x - ax_min) / (arange*0.8) + 2.5,
                          (wpoint.projection.y - ay_min) / (arange*0.8) + 2.5])
        elsif (state == "Hawaii")
          wpoint = hawaii_f.point(point.x, point.y)
          projected.push([(wpoint.projection.x - hx_min) / (hrange*0.8) + 34,
                          (wpoint.projection.y - hy_min) / (hrange*0.8) + 5])
        else
          projected.push([(wpoint.projection.x - x_min) / (range*0.85) + 7.5,
                          (wpoint.projection.y - y_min) / (range*0.85) + 10])
        end
      end
    end
    revised.push(projected)
  end
  states[state] = revised
end

# A function needed to figure the area for point reduction
def check_area(point1, point2, point3)
  area = (point1[0] * (point2[1] - point3[1]) +
          point2[0] * (point3[1] - point1[1]) +
          point3[0] * (point1[1] - point2[1]))/2
  if (area < 0)
    area = -area
  end
  return area
end

# A function that does the actual point reduction
def simplify_polygon(polygon, threshold)
  attributed_points = []
  if (polygon.length < 10)
    return false
  end
  1.upto(polygon.length - 2) do |x|
    last_point = polygon[x-1]
    next_point = polygon[x+1]
    this_point = polygon[x]
    area = check_area(last_point, this_point, next_point)
    attributed_points.push([x, area])
  end
  attributed_points.sort! {|x,y| x[1] <=> y[1]}
  if (attributed_points.first[1] < threshold)
    polygon.delete_at(attributed_points.first[0])
    return true
  else
    return false
  end
end

# This threshold is the parameter that determines how much point reduction
# we will do: you can get massive reduction or minor depending on what
# value you choose
threshold = 0.01
states.each_key do |state|
  replace = []
  states[state].each do |polygon|
    cont = true
    while (cont)
      cont = simplify_polygon(polygon, threshold)
    end
    replace.push(polygon)
  end
  states[state] = replace
end

total = 0
states.each_key do |state|
  states[state].each do |polygon|
    total += polygon.length
  end
end

# Some horrible XML generation.  Probably could have used an XML
# library for this, but the format is simple, really
puts "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
  <array>"
states.each_key do |state|
  states[state].each do |polygon|
    puts "    <dict>"
    puts "      <key>state</key>"
    puts "      <string>#{state}</string>"
    puts "      <key>points</key>"
    puts "      <array>"
    polygon.each do |point|
      puts "        <array>"
      puts "          <real>#{point[0]}</real>"
      puts "          <real>#{point[1]}</real>"
      puts "        </array>"
    end
    puts "      </array>"
    puts "    </dict>"
  end
end
puts "  </array>"
puts "</plist>"
