#!/usr/bin/ruby

# Copyright 2014 Douglas Triggs (douglas@triggs.org)
# 
# I reserve no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

# These are the utility files I'm using for data conversion, i.e., the
# functions that do the polygon simplification/point reduction and
# polygon triangulation, along with data classes used by the algorithm
# (geometric classes + a min-heap implementation).

require_relative 'validation'
require 'json'

# This is the distance at which we consider two points to be the same;
# since our source data is encoded as lat/lons, this is a precision of
# approximately one meter (at the equator, less horizontally near the
# poles); we're working with essentiall 10m data, so this should be
# good enough.
POINT_DELTA = 0.000009

# Super-simple log function to stick timestamps on everything
def log(string)
  puts "#{Time.now.strftime('%H:%M:%S')}: #{string}"
end

# Some basic geometric classes
class Point
  def initialize(x, y)
    @x = x
    @y = y
  end

  attr_accessor :x, :y

  # Are points the same (inside our delta)?
  def same?(point, delta = POINT_DELTA)
    if ((@x + delta > point.x && @x - delta < point.x &&
         @y + delta > point.y && @y - delta < point.y))
      return true
    end
    return false
  end

  def format_string
    "[#{@x}, #{@y}]"
  end

  def to_json(json)
    rc = [@x, @y]
    rc.to_json
  end
end

class Triangle
  def initialize(point1, point2, point3)
    @point1 = point1
    @point2 = point2
    @point3 = point3
  end

  attr_accessor :point1, :point2, :point3

  def points
    [@point1, @point2, @point3]
  end

  def area
    check_area(@point1, @point2, @point3)
  end

  def format_string
    "[#{@point1.format_string},\n #{@point2.format_string},\n #{@point3.format_string}]"
  end

  def to_json(json)
    rc = points.to_json
  end
end

class Line
  def initialize(start_point, end_point)
    @start_point = start_point
    @end_point = end_point
  end

  attr_accessor :start_point, :end_point

  def points
    [@start_point, @end_point]
  end

  def format_string
    "[#{@start_point.format_string},\n #{@end_point.format_string}]"
  end

  def to_json(json)
    points.to_json
  end
end

class Polygon
  def initialize(points = [])
    @points = []
    points.each do |point|
      @points.push(point)
    end
    @concave_points = nil
  end

  def length
    @points.length
  end

  def copy
    Polygon.new(@points)
  end

  def add(point)
    @points.push(point)
  end

  # If index < 0, wraps around to end.  If index > bounds, wraps
  # around to beginning.  This removes massive amounts of checking
  # for special cases below at a small cost in speed
  def [] (index)
    if (@points.length == 0)
      raise "cannot get any points from an empty polygon"
    end
    while (index < 0)
      index += @points.length
    end
    while (index > @points.length - 1)
      index -= @points.length
    end
    @points[index]
  end

  def []= (index, point)
    if (@points.length == 0)
      raise "cannot set any points in an empty polygon"
    end
    while (index < 0)
      index += @points.length
    end
    while (index > @points.length - 1)
      index -= @points.length
    end
    @points[index] = point 
  end

  def points
    @points
  end

  def index(point)
    @points.index(point)
  end

  def delete(point)
    index = @points.index(point)
    if (index)
      @points.delete_at(index)
    else
      raise "cannot delete point that doesn't exist"
    end
    if (@concave_points)
      @concave_points.delete(point)
    end
  end

  def delete_all
    @points = []
  end

  # Verify that polygon is clockwise; otherwise, reverse it (so that the
  # convex checking based on left/right turn checking will work)
  def verify_clockwise()
    total = 0
    0.upto(self.length - 1) do |index|
      point0 = self[index - 1]
      point1 = self[index]
      point2 = self[index + 1]
      delta_x = point0.x - point1.x
      delta_y = point0.y - point1.y
      start_angle = Math.atan2(delta_y, delta_x) / Math::PI * 180
      delta_x = point1.x - point2.x
      delta_y = point1.y - point2.y
      end_angle = Math.atan2(delta_y, delta_x) / Math::PI * 180 - start_angle
      if (end_angle > 180)
        end_angle = end_angle - 360
      end
      if (end_angle < -180)
        end_angle = end_angle + 360
      end
      total -= end_angle
    end
    if (total < 0)
      # -360!  Abort!  Abort!
      @points.reverse!
    end
  end

  # Check to see if a point on the polygon is concave; requires
  # polygons to be clockwise (see above)
  def concave?(index)
    point0 = self[index - 1]
    point1 = self[index]
    point2 = self[index + 1]
    delta_x = point0.x - point1.x
    delta_y = point0.y - point1.y
    start_angle = Math.atan2(delta_y, delta_x) / Math::PI * 180
    delta_x = point1.x - point2.x
    delta_y = point1.y - point2.y
    end_angle = Math.atan2(delta_y, delta_x) / Math::PI * 180 - start_angle
    if (end_angle > 180)
      end_angle = end_angle - 360
    end
    if (end_angle < -180)
      end_angle = end_angle + 360
    end
    if (end_angle > 0)
      return true
    end
    return false
  end

  # Get a set of concave points; needed for checking ears
  def calculate_concave_points
    # Requires polygon to be clockwise, we'll go ahead and do this here
    verify_clockwise

    @concave_points = []
    0.upto(length - 1) do |index|
      if (concave?(index))
        @concave_points.push(self[index])
      end
    end
  end

  # A function to figure if a sub-triangle centered on a vertex is an
  # "ear" of the polygon (i.e., the third/"internal" side doesn't
  # intersect any other sides of the polygon and actually is internal
  # to the polygon -- we can do this by checking for internal points).
  # For the purposes of this check, we assume the points on the
  # triangle are [index, index - 1, index + 1]
  def ear?(index)
    point2 = self[index]
    if (@concave_points.include?(point2))
      # Double-check in case point has become convex; convex points,
      # however, can never become concave
      if (concave?(index))
        return false
      else
        @concave_points.delete(point2)
      end
    end
    point1 = self[index - 1]
    point3 = self[index + 1]
    @concave_points.each do |check_point|
      if (check_interior(check_point, point1, point2, point3))
        return false
      end
    end
    return true
  end

  def format_string
    rc = "[#{self[0].format_string},\n"
    1.upto(self.length - 2) do |n|
      rc += " #{self[n].format_string},\n"
    end
    rc += " #{self[self.length-1].format_string}]"
  end

  def to_json(json)
    points.to_json
  end
end

# The following two classes implement a generic min-heap in an array;
# these classes need to be inherited and have key methods overloaded
# for an actual implementation, and are the used to efficiently
# implement our point reduction and triangulation algorithms
#
# See here: http://en.wikipedia.org/wiki/Binary_heap
#
# This class is used to store/organize individual points + metadata
class AttribItem
  def initialize(point, attrib, index, metadata)
    @point = point
    @attrib = attrib
    @next_link = nil
    @prev_link = nil
    @index = index
    process_metadata(metadata)
  end

  attr_accessor :point, :attrib, :next_link, :prev_link, :index

  # Stub this out of no additional data needed for processing
  def process_metadata(metadata)
    # By default, do nothing
  end

  def recalculate
    puts "'recalculate' needs to be implemented/overloaded"
    exit
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
    if (parent && parent.attrib > item.attrib)
      swap(parent.index, index)
    elsif (left_child && right_child && left_child.attrib < item.attrib &&
           right_child.attrib < item.attrib)
      if (left_child.attrib < right_child.attrib)
        swap(index, left_child.index)
      else
        swap(index, right_child.index)
      end
    elsif (left_child && left_child.attrib < item.attrib)
      swap(index, left_child.index)
    elsif (right_child && right_child.attrib < item.attrib)
      swap(index, right_child.index)
    end
  end

  def node_class
    puts "'node_class' needs to be implemented/overloaded"
    exit
  end

  # Add a new node to the heap
  def add(point, index, attrib, metadata = nil)
    item = node_class.new(point, attrib, @insert_point, metadata)
    @lookup[index] = item
    @items[@insert_point] = item
    heapify(@insert_point)
    @insert_point += 1
  end

  # Link points to the next and previous point in the polygon; this
  # property is otherwise not stored in the heap itself, but is
  # necessary to efficiently recalculate attribs when points are removed
  def link(index, next_index, prev_index)
    item = @lookup[index]
    item.next_link = @lookup[next_index]
    item.prev_link = @lookup[prev_index]
  end

  # Pop of the smallest attrib (i.e., the parent root node).  This also
  # handles all the recalculation necessary and rearranges nodes for
  # neighbors of the parent root node as well
  def pop
    @insert_point -= 1
    if (@insert_point < 0)
      return nil
    end
    check = @items[0]

    rc = pop_sync(check)
    new_head = @items[@insert_point]
    new_head.index = 0
    @items[0] = new_head
    @items[@insert_point] = nil

    # Rearrange the neighbor nodes and recalculate their attribs
    check.next_link.prev_link = check.prev_link
    check.prev_link.next_link = check.next_link
    check.next_link.recalculate
    check.prev_link.recalculate

    # Rearrange the heap
    heapify(0)
    heapify(check.next_link.index)
    heapify(check.prev_link.index)

    return rc
  end

  # Used to adjust polygon before recalculating for triangulation; stub
  # this out otherwise
  def pop_sync(rc)
    # By default, return what we're given
    return rc
  end
end

# And now some geometry helper functions

# A function to figure the area of triangles
def check_area(point1, point2, point3)
  area = (point1.x * (point2.y - point3.y) +
          point2.x * (point3.y - point1.y) +
          point3.x * (point1.y - point2.y))/2
  if (area < 0)
    area = -area
  end
  return area
end

# Check all the endpoints of a line (within our delta is implied)
def check_endpoints(line1, line2, delta)
  if (line1.start_point.same?(line2.start_point) ||
      line1.start_point.same?(line2.end_point) ||
      line1.end_point.same?(line2.start_point) ||
      line1.end_point.same?(line2.end_point))
    return true
  end
  return false
end

# A function to figure the "compactness" of triangles, i.e., how close
# to enclosing the maximum volume the triangle comes compared to an
# equalateral triangle; maximum compactness is ~0.5 (technically
# sin60/18 because we only care about relative values and don't bother
# normalizing) -- but because we're using a min-heap, we then invert
# the value
def check_compactness(point1, point2, point3)
  area = check_area(point1, point2, point3)
  line = (Math.sqrt((point1.x - point2.x)**2 + (point1.y - point2.y)**2) +
          Math.sqrt((point2.x - point3.x)**2 + (point2.y - point3.y)**2) +
          Math.sqrt((point3.x - point1.x)**2 + (point3.y - point1.y)**2))
  # Assuming the input is floating point (should be), this will return
  # "infinity" if area is 0, and that's fine; also we square the
  # distance, so triangles of the same shape have the same
  # compactness, no matter how big they are
  return (line * line) / area
end

# Check if two lines intersect; yay linear algebra!  A line that
# terminates at exactly where they would intersect does not count as
# an intersection; lines must actually cross.  Perfectly parallel
# lines always return false, even if they "overlap" (they need to
# actually cross)
def check_intersection(line1, line2)
  # Lines that share an endpoint cannot intersect; due to precision
  # issues, we need to make an explicit check for this, and stick
  # a delta on it besides
  if (check_endpoints(line1, line2, POINT_DELTA))
    return false
  end
  x1 = line1.start_point.x
  x2 = line1.end_point.x
  x3 = line2.start_point.x
  x4 = line2.end_point.x
  y1 = line1.start_point.y
  y2 = line1.end_point.y
  y3 = line2.start_point.y
  y4 = line2.end_point.y
  den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  point_x = (x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - x4 * y3)
  if (den == 0)
    return false
  end
  point_x = point_x / den
  if ((x1 > x2 && point_x >= x1) || (x1 < x2 && point_x <= x1) ||
      (x3 > x4 && point_x >= x3) || (x3 < x4 && point_x <= x3) ||
      (x1 > x2 && point_x <= x2) || (x1 < x2 && point_x >= x2) ||
      (x3 > x4 && point_x <= x4) || (x3 < x4 && point_x >= x4))
    return false
  end
  # The above fails for any perfectly (or, due to precision issues,
  # sufficiently) vertical lines that would intersect (if extended to)
  # the other line; check y instead in that case:
  if ((x1 + POINT_DELTA > x2 && x1 - POINT_DELTA < x2) ||
      (x3 + POINT_DELTA > x4 && x3 - POINT_DELTA < x4))
    point_y = (x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - x4 * y3)
    point_y = point_y / den
    if ((y1 > y2 && point_y >= y1) || (y1 < y2 && point_y <= y1) ||
        (y3 > y4 && point_y >= y3) || (y3 < y4 && point_y <= y3) ||
        (y1 > y2 && point_y <= y2) || (y1 < y2 && point_y >= y2) ||
        (y3 > y4 && point_y <= y4) || (y3 < y4 && point_y >= y4))
      return false
    end
  end
  return true
end

# Check to see if a point is internal to a triangle; more linear algebra
def check_interior(check, point1, point2, point3)
  # Points on a vertex cannot be interior; due to precision issues, we
  # need to make an explicit check for this
  if (check.same?(point1) || check.same?(point2) || check.same?(point3))
    return false
  end
  # Unlike the above function, this can be negative; in fact, if the
  # triangle is wound counter-clockwise (I think) it needs to be for
  # the rest of the math to work out
  area = (point1.x * (point2.y - point3.y) +
          point2.x * (point3.y - point1.y) +
          point3.x * (point1.y - point2.y))/2
  s = 1 / (2 * area) * (point1.y * point3.x - point1.x * point3.y +
                        (point3.y - point1.y) * check.x +
                        (point1.x - point3.x)*check.y);
  t = 1 / (2 * area) * (point1.x * point2.y - point1.y * point2.x +
                        (point1.y - point2.y) * check.x +
                        (point2.x - point1.x)*check.y);
  if (s > 0 && t > 0 && 1 - s - t > 0)
    return true
  end
  return false
end

### These are our min heap simplification classes
class TriangulateItem < AttribItem
  attr_accessor :parent_polygon
  def process_metadata(polygon)
    @parent_polygon = polygon
  end

  def recalculate
    if (@parent_polygon.ear?(@parent_polygon.index(@point)))
      @attrib = check_compactness(@prev_link.point, @point, @next_link.point)
    else
      # A very, very large number: somewhere around 10^15
      @attrib = 1.0 / (POINT_DELTA * POINT_DELTA * POINT_DELTA)
    end
  end
end

class TriangulateHeapArray < AttribHeapArray
  def node_class
    TriangulateItem
  end

  # We have to implement this, because we can't recalculate and
  # reorder the heap without removing the point from the polygon --
  # but then, we ALSO don't know what the point was unless we capture
  # it and return it; order of operations matter here.  So, a minor
  # hack:
  def pop_sync(rc)
    point1 = rc.prev_link.point
    point2 = rc.point
    point3 = rc.next_link.point

    # This works because all of the nodes share the same
    # "parent_polygon" i.e., they aren't copies, they're the same ruby
    # object.  This makes triangulation destructive, which is why
    # we copy the polygon first
    rc.parent_polygon.delete(point2)

    return Triangle.new(point1, point2, point3)
  end
end

# A function for triangulating polygons by snipping off "ears" -- this
# almost certainly isn't the fastest possible method, but we want some
# "non-standard" properties from our resulting triangles, namely,
# we're trying to get the "squarest" possible triangles, both for
# aesthetic reasons and to optimize spatial trees later.  That said,
# this algorithm is (probably) O(n^2) or so in practice.  At any rate,
# we're preprocessing things for speed later, so we don't care how
# fast this is (within reason).
# 
# This is similar to some pretty standard algorithms that would (very,
# very likely) be faster if you didn't care what the triangles looked
# like, and you can find a fair number of examples of them in various
# languages if you google it, but here is a pretty good discussion of
# the standard ear-clipping algorithm in detail:
#
# http://www.sunshine2k.de/coding/java/Polygon/Kong/Kong.html
#
# See also maybe:
#
# http://www.personal.kent.edu/~rmuhamma/Compgeometry/MyCG/TwoEar/two-ear.htm
#
# http://blogs.agi.com/insight3d/index.php/2008/03/20/triangulation-rhymes-with-strangulation/
#
def triangulate_heap(input)
  # Make triangulation non-destructive:
  if (input.length < 3)
    return []
  end
  polygon = input.copy

  # We need to do this to set up the data
  polygon.calculate_concave_points

  # Add all the points to the heap
  attributed_points = TriangulateHeapArray.new
  0.upto(polygon.length - 1) do |x|
    this_point = polygon[x]
    last_point = polygon[x-1]
    next_point = polygon[x+1]
    if (polygon.ear?(x))
      compactness = check_compactness(last_point, this_point, next_point)
    else
      compactness = 1.0 / (POINT_DELTA * POINT_DELTA * POINT_DELTA)
    end
    attributed_points.add(this_point, x, compactness, polygon)
  end

  # Link all the points in the heap to its neighbor (fast because we're
  # cacheing the index we'll use to link as we add points)
  1.upto(polygon.length - 2) do |x|
    attributed_points.link(x, x+1, x-1)
  end
  attributed_points.link(0, 1, polygon.length - 1)
  attributed_points.link(polygon.length - 1, 0, polygon.length - 2)

  # Do the actual triangulation
  triangles = []
  while (polygon.length > 3)
    triangle = attributed_points.pop
    if (triangle.area > (POINT_DELTA * POINT_DELTA)/2)
      triangles.push(triangle)
    end
  end
  if (check_area(polygon[0], polygon[1], polygon[2]) >
      (POINT_DELTA * POINT_DELTA)/2)
    triangles.push(Triangle.new(polygon[0], polygon[1], polygon[2]))
  end
  validate_triangulation(triangles, false)
  return triangles
end

### These are our min heap simplification classes
class SimplifyItem < AttribItem
  def recalculate
    @attrib = check_area(@prev_link.point, @point, @next_link.point)
  end
end

class SimplifyHeapArray < AttribHeapArray
  def node_class
    SimplifyItem
  end
end

### This is our polygon simplification function
#
# The point simplification is based on the algorithm described here:
#
# http://bost.ocks.org/mike/simplify/
#
def simplify_polygon_heap(polygon, threshold)
  # First, add all the points to the heap
  attributed_points = SimplifyHeapArray.new
  0.upto(polygon.length - 1) do |x|
    this_point = polygon[x]
    last_point = polygon[x-1]
    next_point = polygon[x+1]
    area = check_area(last_point, this_point, next_point)
    attributed_points.add(this_point, x, area)
  end
  # Link all the points in the heap to its neighbor (this is fast
  # because we build a hash to do that when we add the points the
  # first time)
  1.upto(polygon.length - 2) do |x|
    attributed_points.link(x, x+1, x-1)
  end
  attributed_points.link(0, 1, polygon.length - 1) 
  attributed_points.link(polygon.length - 1, 0, polygon.length - 2)
  # Do the actual simplification
  while (1)
    if (polygon.length < 4)
      # This polygon has been simplified out of existence!
      polygon.delete_all
      return
    end
    check = attributed_points.pop
    if (check && check.attrib < threshold)
      polygon.delete(check.point)
    else
      return
    end
  end
end
