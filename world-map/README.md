# World Map Stuff

version `0.0.not-quite-done-yet`

This is code I'm using to generate global basemap data for a possible
game I'm working on, i.e., in particular for making maps in a scenario
editor.  The data I'm using for this originally comes from here:

[Natural Earth 1:10m physical vector data](http://www.naturalearthdata.com/downloads/10m-physical-vectors/ "link")

I've included the actual data that I used for the script in the
repository; however, for whatever reason, GEOS/RGeo had issues with
three of the shapefiles, so I've included the "fixed" files (which I
"fixed" by loading in QGIS and re-saved back out).  You'll need to
move those into the `ne_10m_bathymetry_all` directory.

The `convert.rb` script converts the shapefiles into JSON (both
original/raw versions and versions at various levels of simplification
-- but not GeoJSON, just super-basic JSON arrays), and also produces
versions with the polygons broken into triangles.  This script uses a
simplified and refactored version of the simplification code used by
the U.S. State basemap generation script (simplified because: for one
thing, it doesn't have to deal with "triple-points").  The
simplification code is reasonably fast, the triangulation code is
often noticably slower on the same data sets (because, well, it has to
do more work, and I didn't optimize for highly concave polygons or
anything -- I just got it working fast enough for batch use).  It will
take a bit of time once it gets to the nearly half-million-point data
sets here, but not more than on the order of an hour or so for a given
operation (i.e., to triangulate or simplify a dataset).

There's also a fair amount of debugging/validation code; that code is
**HELLA SLOW** because it checks *everything*, every possible
intersection, etc -- we're talking very evil O(n^2) code.  Also, under
our "normal" use here it will sometimes fail validation for valid
reasons (sometimes the point simplification code will result in --
relatively harmless -- self-intersecting polygons, and everything we
do assumes no holes or meaningful self-intersection).  Beyond that,
it's not entirely debugged at this point; some stuff still fails
validation, but haven't yet determined why; I haven't yet rendered the
results to be sure if it's a real problem or not (so this probably
isn't a final version).  For these reasons, that code was left off
when not actively debugging the script (and is currently disabled).
If you enable it (i.e., comment out the early returns, etc.), you can
use some of the test code in the `test.rb` script as well.

Either way, if you want to adapt it for your own use, it should be a
lot easier to deal with than the election map version.

# Links

Some other useful links:

## Ear-clipping Triangulation Algorithm

[Some discussion of a basic (but slightly more efficient than the one I used) ear-clipping triangulation (Kong's) algorithm.](http://www.sunshine2k.de/coding/java/Polygon/Kong/Kong.html "link")

[More ear-clipping triangulation discussion.](http://www.personal.kent.edu/~rmuhamma/Compgeometry/MyCG/TwoEar/two-ear.htm "link")

[Optimising the algorithm with spatial trees (I didn't do this, but might be worthwhile if you need more speed.  There's probably significant speedups to be had there).](http://blogs.agi.com/insight3d/index.php/2008/03/20/triangulation-rhymes-with-strangulation/ "link")

Google will find you actual code in other languages that does this
kind of thing, too.

## Point-simplification Algorithm

[All about the polygon point-simplification (Visvalingham's) algorithm.](http://bost.ocks.org/mike/simplify/ "link")

## Min-Heaps

[Discussion of binary min-heap (see the array implementation).](http://en.wikipedia.org/wiki/Binary_heap "link")

For the stuff I used for line intersections and interior point
detection, well, that's adapted linear algebra, you can google for
more example code for that kind of stuff.
