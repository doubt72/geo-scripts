#!/usr/bin/ruby

# Copyright 2014 Douglas Triggs (douglas@triggs.org)
# 
# I reserve no rights to this, if this is useful to anybody, do whatever
# you want to do to it, give me credit or not, I don't care.  I also
# give no warrantee -- if the code breaks for you, you're on your own.

# These are functions meant to test/validate the utility classes
# (i.e., verify that triangulation or point simplification is
# happening properly)

# NOTE: these functions are disabled by default; the early returns
# need to be removed for these to actually do anything.

# For testing polygon integrity, used for testing our data and for
# debugging; this is very slow, but purposefully kept relatively
# simple
def validate_polygons(polygons)
  # Remove to enable validation
  log "=== skipping polygon validation ==="
  return
  polygons.each do |polygon|
    validate_polygon(polygon)
  end
end

def validate_polygon(polygon)
  # Remove to enable validation
  return
  tot_count = 0;
  intersections = []
  0.upto(polygon.length - 1) do |index|
    count = 0
    with = []
    line1 = Line.new(polygon[index], polygon[index + 1])
    (index + 1).upto(polygon.length - 1) do |index2|
      line2 = Line.new(polygon[index2], polygon[index2 + 1])
      if (check_intersection(line1, line2))
        with.push([index2, line2.format_string])
        check_intersection_debug(line1, line2)
        count += 1
      end
    end
    if (count > 0)
      tot_count += count
      intersections.push([index, line1.format_string, with])
    end
  end
  if (tot_count > 0)
    puts "WARNING: self-intersecting poly #{tot_count} intersection for #{polygon.length} sides"
    intersections.each do |inter|
      puts "side: #{inter[0]}\n  #{inter[1]}"
      inter[2].each do |with|
        puts "with: #{with[0]}\n  #{with[1]}"
      end
    end
    exit
  end
end

# For testing integrity of triangulation algorithm.  This is (very)
# slow, so we put everything into buckets first to minimize the O(n^2)
# nature of testing all the triangles (otherwise it may never have
# finished); again used for debugging so basically kept pretty simple
def validate_triangulation(triangles, message = true)
  # Remove to enable validation
  if (message)
    log "=== skipping triangle validation ==="
  end
  return
  # Partition things first into buckets to speed things up a bit
  buckets = []
  box_size = 2
  -180.step(179, box_size) do |x|
    inner_bucket = []
    -90.step(89, box_size) do |y|
      x_hi = x + box_size
      y_hi = y + box_size
      set = []
      triangles.each do |triangle|
        check = false
        triangle.points.each do |point|
          if (point.x >= x && point.x <= x_hi &&
              point.y >= y && point.y <= y_hi)
            check = true
          end
        end
        if (check)
          set.push(triangle)
        end
      end
      inner_bucket.push(set)
    end
    buckets.push(inner_bucket)
  end
  count = 0
  buckets.each do |bucket|
    bucket.each do |set|
      if (set.length > 0)
        count += set.length
        if (validate_triangle_bucket(set) == false)
          return false
        end
      end
    end
  end
  return true
end

def validate_triangle_bucket(triangles)
  0.upto(triangles.length - 1) do |index|
    t1 = triangles[index]
    (index + 1).upto(triangles.length - 1) do |index2|
      t2 = triangles[index2]
      if (check_intersection(Line.new(t1.point1, t1.point2),
                             Line.new(t2.point1, t2.point2)) ||
          check_intersection(Line.new(t1.point1, t1.point2),
                             Line.new(t2.point2, t2.point3)) ||
          check_intersection(Line.new(t1.point1, t1.point2),
                             Line.new(t2.point3, t2.point1)) ||
          check_intersection(Line.new(t1.point2, t1.point3),
                             Line.new(t2.point1, t2.point2)) ||
          check_intersection(Line.new(t1.point2, t1.point3),
                             Line.new(t2.point2, t2.point3)) ||
          check_intersection(Line.new(t1.point2, t1.point3),
                             Line.new(t2.point3, t2.point1)) ||
          check_intersection(Line.new(t1.point3, t1.point1),
                             Line.new(t2.point1, t2.point2)) ||
          check_intersection(Line.new(t1.point3, t1.point1),
                             Line.new(t2.point2, t2.point3)) ||
          check_intersection(Line.new(t1.point3, t1.point1),
                             Line.new(t2.point3, t2.point1)))
        puts "WARNING: triangle intersection"
        puts "triangles\n#{t1.format_string}\n#{t2.format_string}"
      end
    end
  end
end
