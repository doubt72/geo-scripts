# Election Map Stuff

This is a ruby point-reduction script using rgeo's shapefile library; while it's a single-purpose script, it can probably be fairly easily generalized for other uses.

The script uses min-heaps to implement the algorithm [described here](http://bost.ocks.org/mike/simplify/ "simplify").

Included is the shapefile (from the US Census web page) that the script uses for source data.

[This site](https://www.jasondavies.com/simplify/ "simplify") may also be of interest to anyone looking at this; the current script does not account for this, though it does (somewhat) deal with triple-point state intersections.
