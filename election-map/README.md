# Election Map Stuff

This is a ruby point-reduction script using rgeo's shapefile library; while it's a single-purpose script, it can probably be fairly easily generalized for other uses.

The script uses min-heaps to implement the algorithm [described here](http://bost.ocks.org/mike/simplify/ "link").

Included is the shapefile (from the US Census web page) that the script uses for source data.

Feel free to use this however you want, give me credit or not, I don't care. I also give no warrantees -- even though I'd hope it doesn't, if the code breaks for you, you're on your own.
