#!/usr/bin/ruby

# (c) Douglas Triggs
# 
# I claim no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

require 'rgeo/shapefile'

# This is the code I used to generate state basemap data for my
# election game, so it was really just used "once" (although I ran it
# any number of times to get the actual quality of map I wanted) and
# would need to be modified for general use (though modifying it for
# someone's specific use should be fairly straightforward).  The data
# it was originally used was a shapefile that came from the US Census
# web page and is included in the github repository.

# This is slow, but if you're just simplifying source data, it should
# work fine.  It used to be much slower, but along the way I ended up
# significantly optimizing it; I wanted to thread it, too, but
# unfortunately native ruby threads don't really use multiple cores
# under load (and installing JRuby was too much trouble), so I just
# tended to run the program at multiple scales at the same time
# instead.

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

# Reduce the number of islands, er, artisinally; also, the source data
# is quite ugly (it includes polygons for the great lakes, for
# example, and we don't want those), so we're throwing away not just
# the more insignificant islands but those, too
states.each_key do |state|
  records = states[state].sort! {|x,y| y[0] <=> x[0]}
  if (state == "Alabama" || state == "Mississippi" || state == "Georgia" ||
      state == "South Carolina" || state == "Minnesota" ||
      state == "Oregon" || state == "Maine" || state == "Pennsylvania" ||
      state == "New Jersey" || state == "Illinois" || state == "Indiana" ||
      state == "Ohio" || state == "Maryland" || state == "California")
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
  elsif (state == "Massachusetts")
    states[state] = [records[0], records[1], records[2], records[3],
                     records[6]]
  elsif (state == "Louisiana")
    states[state] = [records[0], records[1], records[2], records[3],
                     records[4], records[6], records[7], records[8],
                     records[11], records[14], records[32], records[38],
                     records[39], records[40]]
  elsif (state == "Florida")
    states[state] = [records[0], records[1], records[2], records[3],
                     records[8], records[9], records[10], records[12],
                     records[13], records[19], records[21], records[30],
                     records[31], records[35], records[36], records[37],
                     records[38], records[41], records[42], records[45],
                     records[47]]
  elsif (state == "Texas")
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

# Projections for US, Alaska, and Hawaii This part is trickier if
# you're using different data; however, map projections are well
# defined and ought to be fairly easy to find via google
proj4 = "+proj=lcc +lat_1=33 +lat_2=45 +lat_0=40 +lon_0=-97 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"
proj4_a = "+proj=aea +lat_1=55 +lat_2=65 +lat_0=50 +lon_0=-154 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"
proj4_h = "+proj=aea +lat_1=8 +lat_2=18 +lat_0=13 +lon_0=-157 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs"

lambert_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4)
alaska_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4_a)
hawaii_f = RGeo::Geographic.projected_factory(:projection_proj4 => proj4_h)

# Figure out the bounds (well, it did; see below after the commented code):
#x_max = -999999999999
#x_min = 999999999999
#y_max = -999999999999
#y_min = 999999999999
#ax_max = -999999999999
#ax_min = 999999999999
#ay_max = -999999999999
#ay_min = 999999999999
#hx_max = -999999999999
#hx_min = 999999999999
#hy_max = -999999999999
#hy_min = 999999999999

#states.each_key do |state|
#  states[state].each do |record|
#    record[1].geometry.each do |polygon|
#      ring = polygon.exterior_ring
#      ring.points.each do |point|
#        wpoint = lambert_f.point(point.x, point.y)
#        if (state == "Alaska")
#          wpoint = alaska_f.point(point.x, point.y)
#        elsif (state == "Hawaii")
#          wpoint = hawaii_f.point(point.x, point.y)
#        end
#        if (state == "Alaska")
#          if (wpoint.projection.x > ax_max)
#            ax_max = wpoint.projection.x
#          end
#          if (wpoint.projection.x < ax_min)
#            ax_min = wpoint.projection.x
#          end
#          if (wpoint.projection.y > ay_max)
#            ay_max = wpoint.projection.y
#          end
#          if (wpoint.projection.y < ay_min)
#            ay_min = wpoint.projection.y
#          end
#        elsif (state == "Hawaii")
#          if (wpoint.projection.x > hx_max)
#            hx_max = wpoint.projection.x
#          end
#          if (wpoint.projection.x < hx_min)
#            hx_min = wpoint.projection.x
#          end
#          if (wpoint.projection.y > hy_max)
#            hy_max = wpoint.projection.y
#          end
#          if (wpoint.projection.y < hy_min)
#            hy_min = wpoint.projection.y
#          end
#        else
#          if (wpoint.projection.x > x_max)
#            x_max = wpoint.projection.x
#          end
#          if (wpoint.projection.x < x_min)
#            x_min = wpoint.projection.x
#          end
#          if (wpoint.projection.y > y_max)
#            y_max = wpoint.projection.y
#          end
#          if (wpoint.projection.y < y_min)
#            y_min = wpoint.projection.y
#          end
#        end
#      end
#    end
#  end
#end

#x_range = (x_max - x_min) / 120.0
#y_range = (y_max - y_min) / 120.0

#range = y_range
#if (x_range > y_range)
#  range = x_range
#end

#ax_range = (ax_max - ax_min) / 32.5
#ay_range = (ay_max - ay_min) / 32.5

#arange = ay_range
#if (ax_range > ay_range)
#  arange = ax_range
#end

#hx_range = (hx_max - hx_min) / 25.0
#hy_range = (hy_max - hy_min) / 25.0

#hrange = hy_range
#if (hx_range > hy_range)
#  hrange = hx_range
#end

# Because I made changes to the actual polygons included, the bounds
# ended up shifting and no longer matched my geolocated cities and
# labels; so instead of using the above code, this became hardcoded
# to match.

x_min = -2280856.693497018
y_min = -1574538.8465254293
range = 38446.34312337495

ax_min = -1013359.3187973788
ay_min = 428040.3294930048
arange = 77089.5302927532

hx_min = -337383.70336518943
hy_min = 656296.8296850828
hrange = 22763.057704569284

# And here I do the actual projection, plus rescaling for display:
states.each_key do |state|
  revised = []
  states[state].each do |record|
    projected = []
    record[1].geometry.each do |polygon|
      ring = polygon.exterior_ring
      ring.points.each do |point|
        if (state == "Alaska")
          wpoint = alaska_f.point(point.x, point.y)
          projected.push([(wpoint.projection.x - ax_min) / (arange*0.8) + 2.5,
                          (wpoint.projection.y - ay_min) / (arange*0.8) + 2.5])
        elsif (state == "Hawaii")
          wpoint = hawaii_f.point(point.x, point.y)
          projected.push([(wpoint.projection.x - hx_min) / (hrange*0.8) + 34,
                          (wpoint.projection.y - hy_min) / (hrange*0.8) + 5])
        else
          wpoint = lambert_f.point(point.x, point.y)
          projected.push([(wpoint.projection.x - x_min) / (range*0.85) + 7.5,
                          (wpoint.projection.y - y_min) / (range*0.85) + 10])
        end
      end
    end
    revised.push(projected)
  end
  states[state] = revised
end

# States orderd by fewest polygons to most; using this order speeds things
# up slightly
def ordered_keys()
  return [
          "District of Columbia", "Colorado", "New Mexico", "Wyoming",
          "Kansas", "Utah", "Rhode Island", "Delaware", "Connecticut",
          "Nevada", "South Dakota", "Nebraska", "Tennessee", "Oklahoma",
          "Hawaii", "Pennsylvania", "Arizona", "Arkansas", "Massachusetts",
          "Iowa", "Vermont", "New Hampshire", "Indiana", "Alabama", "Ohio",
          "Missouri", "Kentucky", "New Jersey", "North Dakota", "Mississippi",
          "Illinois", "Montana", "New York", "Wisconsin", "Idaho",
          "West Virginia", "Oregon", "South Carolina", "Georgia", "Maine",
          "Minnesota", "Michigan", "Washington", "Maryland", "Virginia",
          "Louisiana", "North Carolina", "California", "Texas", "Florida",
          "Alaska"]
end

# These are the bounding boxes for the states; this speeds up looking
# for state intersections which we use below
def make_bounding_boxes(data)
  all = ordered_keys()
  rc = {}
  all.each do |state|
    xMin = 999
    yMin = 999
    xMax = -999
    yMax = -999
    data[state].each do |polygon|
      polygon.each do |point|
        x = point[0]
        y = point[1]
        if (x < xMin)
          xMin = x
        end
        if (x > xMax)
          xMax = x
        end
        if (y < yMin)
          yMin = y
        end
        if (y > yMax)
          yMax = y
        end
      end
    end
    rc[state] = [xMin, yMin, xMax, yMax]
  end
  return rc
end

bounds = make_bounding_boxes(states)

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

# The following two classes implement a min-heap in an array; the
# class is used to efficiently implement our point reduction algorithm

# See here: http://en.wikipedia.org/wiki/Binary_heap

# This class is used to store/organize individual points + metadata
class AttribItemArray
  def initialize(point, area, index)
    @point = point
    @area = area
    @invalid = false
    @next_link = nil
    @prev_link = nil
    @index = index
  end

  attr_accessor :point, :area, :next_link, :prev_link, :invalid, :index

  def recalculate
    @area = check_area(@prev_link.point, @point, @next_link.point)
  end
end

# This is our actual minheap implementation using an array
class AttribHeapArray
  def initialize
    @insert_point = 0;
    @lookup = {}
    @items = []
  end

  def swap(pindex, cindex)
    # Swap nodes in the heap, i.e., parent and child
    parent = @items[pindex]
    child = @items[cindex]
    @items[cindex] = parent
    @items[pindex] = child
    child.index = pindex
    parent.index = cindex

    # Recurse as necessary
    heapify(pindex)
    heapify(cindex)
  end

  def parent(index)
    if (index > 0)
      @items[(index - 1)/2]
    else
      return nil
    end
  end

  def left_child(index)
    @items[index*2 + 1]
  end

  def right_child(index)
    @items[index*2 + 2]
  end

  # This function fixes the heap property for a given node
  def heapify(index)
    item = @items[index]
    parent = parent(index)
    left_child = left_child(index)
    right_child = right_child(index)
    if (parent && parent.area > item.area)
      swap(parent.index, index)
    elsif (left_child && right_child && left_child.area < item.area &&
           right_child.area < item.area)
      if (left_child.area < right_child.area)
        swap(index, left_child.index)
      else
        swap(index, right_child.index)
      end
    elsif (left_child && left_child.area < item.area)
      swap(index, left_child.index)
    elsif (right_child && right_child.area < item.area)
      swap(index, right_child.index)
    end
  end

  # Add a new node to the heap
  def add(point, area, invalid)
    item = AttribItemArray.new(point, area, @insert_point)
    item.invalid = invalid
    @lookup[point] = item
    @items[@insert_point] = item
    heapify(@insert_point)
    @insert_point += 1
  end

  # Link points to the next and previous point in the polygon; this
  # property is otherwise not stored in the heap itself, but is
  # necessary to efficiently recalculate areas when points are removed
  def link(point, next_point, prev_point)
    item = @lookup[point]
    item.next_link = @lookup[next_point]
    item.prev_link = @lookup[prev_point]
  end

  # Pop of the smallest area (i.e., the parent root node).  This also
  # handles all the recalculation necessary and rearranges nodes for
  # neighbors of the parent root node as well
  def pop
    @insert_point -= 1
    if (@insert_point < 0)
      return nil
    end
    rc = @items[0]
    new_head = @items[@insert_point]
    new_head.index = 0
    @items[0] = new_head
    @items[@insert_point] = nil

    # Rearrange the neighbor nodes and recalculate their areas
    rc.next_link.prev_link = rc.prev_link
    rc.prev_link.next_link = rc.next_link
    rc.next_link.recalculate
    rc.prev_link.recalculate

    # Rearrange the heap
    heapify(0)
    heapify(rc.next_link.index)
    heapify(rc.prev_link.index)

    # Some of our nodes have been invalidated (i.e. it is too close to
    # a "tri-point" and we don't want to simplify it away, because
    # that sometimes causes gaps in our map where three states meet).
    # In that case, we want to skip that node -- it should not be
    # deleted from the polygon
    if (rc.invalid)
      return pop
    else
      return rc
    end
  end
end

# This is the delta we use for checking for "triple-points," i.e. points
# we don't want to delete during simplification because it would cause
# a gap in the map
def delta()
  return 0.05
end

# This is the function we use to check for "triple-points"
def check_point(polygon, x, y, old, new)
  delta = delta()
  polygon.each do |point|
    new_x = point[0]
    new_y = point[1]
    if (new_x + delta >= x && new_x - delta <= x &&
        new_y + delta >= y && new_y - delta <= y)
      return true
    end
  end
  return false
end

# We don't want to delete points that are at the intersection of three
# states; this function finds those points so that we can mark them
def junction_point(point, allstates, current, bounds)
  if (current != "Hawaii" && current != "Alaska")
    keys = ordered_keys()
    already = false
    found = nil
    keys.each do |state|
      if (current != state && state != "Hawaii" && state != "Alaska")
        bounds_st = bounds[state]
        if (point[0] >= bounds_st[0] && point[1] >= bounds_st[1] &&
            point[0] <= bounds_st[2] && point[1] <= bounds_st[3])
          allstates[state].each do |part|
            if (check_point(part, point[0], point[1], current, state))
              if (already)
                return true
              else
                already = true
                found = state
                break
              end
            end
          end
        end
      end
    end
  end
  return false
end

# This is our actual polygon simplification function
def simplify_polygon_heap(polygon, threshold, allstates, current, bounds)
  # First, add all the points to the heap
  attributed_points = AttribHeapArray.new
  1.upto(polygon.length - 2) do |x|
    this_point = polygon[x]
    last_point = polygon[x-1]
    next_point = polygon[x+1]
    area = check_area(last_point, this_point, next_point)
    # Mark all points that are multi-state intersections so we know
    # not to delete them
    attributed_points.add(this_point, area,
                          junction_point(this_point, allstates, current,
                                         bounds))
  end
  this_point = polygon[0]
  last_point = polygon[-2]
  next_point = polygon[1]
  area = check_area(last_point, this_point, next_point)
  # Again, marking intersections
  attributed_points.add(this_point, area,
                        junction_point(this_point, allstates, current, bounds))
  # Link all the points in the heap to its neighbor (this is fast
  # because we build a hash to do that when we add the points the
  # first time)
  1.upto(polygon.length - 2) do |x|
    this_point = polygon[x]
    last_point = polygon[x-1]
    next_point = polygon[x+1]
    attributed_points.link(this_point, next_point, last_point)
  end
  this_point = polygon[0]
  last_point = polygon[-2]
  next_point = polygon[1]
  attributed_points.link(this_point, next_point, last_point)
  # Do the actual simplification
  while (1)
    if (polygon.length < 10)
      return
    end
    check = attributed_points.pop
    if (check && check.area < threshold)
      old_length = polygon.length
      polygon.delete(check.point)
      # If the polygon shrank by two, we just deleted the first/last
      # point; add the first point back to the end to close the
      # polygon
      if (polygon.length < old_length - 1)
        polygon.push(polygon.first)
      end
    else
      return
    end
  end
end

# This threshold is the parameter that determines how much point reduction
# we will do: you can get massive reduction or minor depending on what
# value you choose
threshold = 0.0025
keys = ordered_keys()
keys.each do |state|
  replace = []
  states[state].each do |polygon|
    # Alaska has a lot of points, but no neighbors; we don't really
    # need to reduce it as much as other states, and can save
    # significant points here without losing much
    if (state == "Alaska")
      threshold = 2 * threshold
    end
    simplify_polygon_heap(polygon, threshold, states, state, bounds)
    if (polygon.length > 0)
      replace.push(polygon)
    end
  end
  states[state] = replace
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

# This is special code used to create the "boxes" we have off the
# side of the map for the tiny east coast states + DC
left1 = 142.5
right1 = 147.5
left2 = 150
right2 = 155
baseline = 35

puts "    <dict>
      <key>state</key>
      <string>District of Columbia</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Maryland</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 12.5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 12.5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Delaware</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 12.5}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 12.5}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 7.5}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>New Jersey</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 15}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 15}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 20}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 20}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 15}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Connecticut</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 15}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 15}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 20}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 20}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 15}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Rhode Island</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 27.5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 27.5}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Massachusetts</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 27.5}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 27.5}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 22.5}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>Vermont</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 30}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 30}</real>
	</array>
	<array>
	  <real>#{right1}</real>
	  <real>#{baseline + 35}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 35}</real>
	</array>
	<array>
	  <real>#{left1}</real>
	  <real>#{baseline + 30}</real>
	</array>
      </array>
    </dict>
    <dict>
      <key>state</key>
      <string>New Hampshire</string>
      <key>points</key>
      <array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 30}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 30}</real>
	</array>
	<array>
	  <real>#{right2}</real>
	  <real>#{baseline + 35}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 35}</real>
	</array>
	<array>
	  <real>#{left2}</real>
	  <real>#{baseline + 30}</real>
	</array>
      </array>
    </dict>"

puts "  </array>"
puts "</plist>"
