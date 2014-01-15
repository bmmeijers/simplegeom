# cython: profile=True
"""EWKT reader and writer functions
"""

__all__ = ["load", "loads", "dumps", "dump"]

from re import compile

# TODO: we now instantiate a list and copy from there to geometry
#       in terms of performance this can be improved!
#       Just copy once!
cdef class WKTReader(object):
    """
    Class to transform a WKT string to a Python geometry object
    """
    def __init__(self):
        self.rx_coord_list = compile(
                    r"[ \t]*(\([ \t]*)*(?P<coords>[^\)]+)[ \t]*(\)[ \t]*)+,?"
                    )
        self._wkt_types = ["POLYGON", 
                           "LINESTRING", 
                           "POINT", ]
        self._srid = 0

    def from_wkt(self, wkt):
        """
        Return the geometry given in well-known text format as python objects
    
        The function accepts only 2D data and supports the POINT, LINESTRING 
        and POLYGON geometries.

        The string wkt may contain an SRID specification in addition to the
        actual geometry. This SRID is ignored.
        """
        parts = wkt.split(";")
        for part in parts:
            part = part.strip()
            if part.startswith("SRID"):
                # ignore SRIDs
                self._srid = int(part[5:])
            else:
                for geotype in self._wkt_types:
                    if part.startswith(geotype) and geotype == 'POINT':
                        return self.parse_point(part[len(geotype):])
                    elif part.startswith(geotype) and geotype == 'LINESTRING':
                        return self.parse_linestring(part[len(geotype):])
                    elif part.startswith(geotype) and geotype == 'POLYGON':
                        return self.parse_polygon(part[len(geotype):])
                else:
                    raise ValueError("Unsupported WKT-part %s" % repr(part[:20]))
        else:
            raise ValueError("No recognized geometry in WKT string")

    cdef parse_polygon(self, wkt):
        """Return the POLYGON geometry in wkt as a list of float pairs"""
        cdef int i, j
        cdef path_t * path
        cdef Polygon p
        if self._srid != 0:
            p = Polygon(srid = self._srid)
        else:
            p = Polygon()
        j = 0
        while wkt:
            match = self.rx_coord_list.match(wkt)
            if match:
                try:
                    path = path_new()
                except MemoryError:
                    raise
                
                wktcoords = match.group("coords")
                coords = wktcoords.split(",")
                
                try:
                    path_new_coords(path, len(coords))
                except MemoryError:
                    raise
                
                try:
                    surface_add_path(p._surface, path)
                except MemoryError:
                    raise
                
                for i, pair in enumerate(coords):
                    # a pair may be a triple actually. For now we just
                    # ignore any third value
                    x, y = map(float, pair.split())[:2]
                    path_set_coord(path, i, x, y)
                path.items = len(coords)
                p._surface.paths[j] = path
                j += 1
                wkt = wkt[match.end(0):].strip()
            else:
                raise ValueError("Invalid well-known-text (WKT) syntax")
        return p

    cdef LineString parse_linestring(self, wkt):
        """Return the LINESTRING geometry in wkt as a list of float pairs"""
        cdef int i = 0
        cdef LineString ln
        if self._srid != 0:
            ln = LineString(srid = self._srid)
        else:
            ln = LineString()
        while wkt:
            match = self.rx_coord_list.match(wkt)
            if match:
                wktcoords = match.group("coords")
                coords = wktcoords.split(",")
                try:
                    path_grow(ln._path, len(coords))
                except MemoryError:
                    raise
                for i, pair in enumerate(coords):
                    # a pair may be a triple actually. For now we just
                    # ignore any third value
                    x, y = map(float, pair.split())[:2]
                    path_set_coord(ln._path, i, x, y)
                ln._path.items = len(coords)
                return ln
            else:
                raise ValueError("Invalid well-known-text (WKT) syntax")

    cdef Point parse_point(self, wkt):
        """Return the POINT geometry in wkt format as pair of floats"""
        while wkt:
            match = self.rx_coord_list.match(wkt)
            if match:
                wktcoords = match.group("coords")
                for pair in wktcoords.split(","):
                    # a pair may be a triple actually. For now we just
                    # ignore any third value
                    x, y = map(float, pair.split())[:2]
                    if self._srid != 0:
                        return Point(x, y, srid = self._srid)
                    else:
                        return Point(x, y)

cpdef loads(str text):
    """
    Return a Geometry for a WKT representation
    """
    wkt = WKTReader()
    return wkt.from_wkt(text)

def load(fp):
    """Load a geometry from an open file."""
    data = fp.read()
    return loads(data)

cpdef dumps(Geometry geom, bint srid = False):
    """
    Return a WKT representation for a Geometry
    
    """
    res = ""
    if srid:
        res += "SRID={};".format(geom.srid)
    res += str(geom)
    return res

def dump(ob, fp):
    """Dump a geometry as WKT string to an open file."""
    fp.write("{}".format(str(ob)))