from simplegeom._geom2d cimport Geometry, Point, LineString, Polygon, \
    box_t, coord_t, path_t, surface_t, \
    path_new, path_new_coords, path_grow, path_dealloc, \
    path_set_coord, surface_add_path

cdef class WKTReader:
    cdef object rx_coord_list
    cdef object _wkt_types
    cdef int _srid
    cdef parse_polygon(self, wkt)
    cdef LineString parse_linestring(self, wkt)
    cdef Point parse_point(self, wkt)

cpdef loads(object text) # text - unicode
cpdef dumps(Geometry geom, bint srid = ?)
