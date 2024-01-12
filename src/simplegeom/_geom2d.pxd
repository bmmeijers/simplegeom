#------------------------------------------------------------------------------ 
# TODO:
# - Make interface complete (also delete coordinates / reset coordinates)
#------------------------------------------------------------------------------


from libc.stdlib cimport malloc, free, realloc

from simplegeom._wkb import dumps

#cimport simplegeom._wkb
# cimport _util
# cimport _wkt

#from _wkb cimport BinaryGeometryWriter
#from simplegeom._wkb cimport dumps
#cdef extern from "alloca.h":
#    void *alloca(int size)

#cdef extern from "stdio.h" :
#    int printf  ( char *, ... )
#    int sprintf ( char *str, char *format, ... )

ctypedef unsigned int uint

cdef extern from "math.h":
    int isnan(double)
    double ceil(double)
    cdef enum:
        HUGE_VAL
        FP_NAN
    
    #double atan2( double y, double x )
    double sqrt( double num )
    
cdef extern from "string.h": #nogil:
    int strlen(char *)
    void *memcpy(void *, void *, int)

cdef extern from "Python.h":
    object PyString_FromStringAndSize(char *v, int len)
    int PyBuffer_Check(object p)
    int PyString_AsStringAndSize(object obj, char **buffer, 
                                 Py_ssize_t* length) except -1

cdef inline double cmax(double a, double b)
cdef inline double cmin(double a, double b)
cdef inline double cabs(double a)

cdef enum:
    REALLOC_PATH = 3
    REALLOC_SURFACE = 1
    
cdef enum:
    SUCCESS = 0
    FAILURE = -1

cdef enum:
    WKB_POINT = 1
    WKB_LINE  = 2
    WKB_POLY  = 3
    WKB_ENVELOPE = 101 # TODO: look at specs to see how this should be -> envelope was added "recently"

cdef struct coord_t:
    double x
    double y

cdef struct path_t:
    uint items
    uint allocated
    coord_t *coords

cdef struct surface_t:
    uint items
    uint allocated
    path_t **paths

cdef struct box_t:
    double xmin
    double ymin
    double xmax
    double ymax

# --- box_t struct
#==============================================================================
cdef box_t *box_new() except NULL
cdef void box_dealloc(box_t *mbr)
cdef bint box_inited(box_t *mbr)
cdef bint box_eq(box_t *one, box_t *other )
cdef inline double box_area(box_t *one)
#cdef inline bint box_box_intersects(box_t *one, box_t *other)
#cdef inline box_box_merge(box_t *one, box_t *other)
#cdef inline bint box_box_contains(box_t *one, box_t *other)
#cdef inline bint box_box_contains_strictly(box_t *one, box_t *other)

# --- coord_t struct
#==============================================================================
cdef coord_t *coord_new() except NULL
cdef void coord_dealloc(coord_t *coord) 
#cdef void coord_box(coord_t *coord, box_t *mbr)


# --- path_t struct
#==============================================================================
cdef path_t *path_new()
cdef void path_new_coords(path_t *path, int ct = ?)
cdef void path_dealloc(path_t *path) 
cdef void path_grow(path_t *path_dest, int size)
cdef void path_add_coord(path_t *path, double x, double y)
cdef void path_extend(path_t *path_dest, path_t * path_source)
cdef void path_set_coord(path_t * path, int key, double x, double y)
#cdef void path_delete_coord(path_t *path, uint key)
cdef bint path_eq(path_t *one, path_t *other )
cdef void path_box(path_t *path, box_t *mbr)

cdef double path_length(path_t *path)
cdef double path_signed_area(path_t *path)
cdef inline double path_trapezoid_area(path_t *path)

# --- surface_t struct
#==============================================================================
cdef surface_t *surface_new() except NULL
cdef void surface_new_paths(surface_t *surface)
cdef void surface_add_path(surface_t * surface, path_t *path)
#cdef void surface_add_path(surface_t *surface)
cdef void surface_dealloc(surface_t *surface)
#cdef void surface_add_coord(surface_t *surface, uint ring, double x, double y)
#cdef void surface_delete_path(surface_t *surface, uint key)
cdef bint surface_eq(surface_t *one, surface_t *other )
cdef bint surface_box(surface_t *surface, box_t *mbr)

cdef double surface_area(surface_t *surface)

# --- Geometry
cdef class Geometry:
    cdef int _geom_type
    cdef int _srid

cdef class Envelope(Geometry):
    cdef box_t *_mbr
    #merge
    #contains
    #intersects
    #area

cdef class Point(Geometry):
    cdef coord_t *_coord
#    cdef Envelope _envelope
    cdef bint _xinit, _yinit

cdef class LineString(Geometry):
    cdef path_t *_path
#    cdef Envelope _envelope
    #cdef void __append(LineString self, double x, double y)
    #cdef void __recalc_bbox(LineString self)

cdef class LinearRing(LineString):
    pass
#==============================================================================
#
cdef class Polygon(Geometry):
    cdef surface_t *_surface

cdef class Segment(Geometry):
    cdef coord_t *_start
    cdef coord_t *_end


cpdef Point point_in_polygon(Polygon poly)
cdef inline double x_intersection_at_ray(double x0, double y0, 
                                         double x1, double y1, 
                                         double ray_y)


cpdef bint is_ccw(LinearRing ring)

cdef extend_slice(LineString to_ln, LineString from_ln, slice slice)
