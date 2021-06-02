cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *v, int len)

from _geom2d cimport Geometry, Point, LineString, LinearRing, Polygon, \
    Envelope, \
    box_t, coord_t, path_t, surface_t, \
    malloc, free, realloc, ceil, \
    WKB_POINT, WKB_LINE, WKB_POLY, WKB_ENVELOPE, \
    path_new, path_new_coords, path_grow, path_dealloc, \
    path_set_coord, surface_add_path

cdef class EWKBReader(object):
    cdef bint has_z
    cdef bint has_m
    cdef int srid
    cdef object stream
    cdef unicode _endianness 
    
    cpdef object read_geometry(self)
    cdef read_header(self)
    cdef long read_int(self)
    cdef double read_double(self)
    cdef Point read_point(self)
    cdef LineString read_linestring(self)
    cdef Polygon read_polygon(self)


cdef class EWKBWriter(object):
    cdef int tp
    cdef bint has_z
    cdef bint has_m
    cdef int srid
    cdef object stream
    cdef Geometry geometry

    cdef write_geometry(self)
    cdef write_int(self, value)
    cdef write_double(self, value)
    cdef inline void write_point(self)
    cdef inline void write_linestring(self)
    cdef inline void write_polygon(self)
    cpdef as_hex(self)

cpdef loads(object data, object cursor=?) # maybe data should have type 'unicode' -- but this works for both py2+3
cpdef load(fp)
cpdef dumps(Geometry ob)
cpdef dump(Geometry ob, fp)
