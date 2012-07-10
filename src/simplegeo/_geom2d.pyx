# cython: profile=True
"""Provide Simple Feature like Geometry objects in 2 dimensions.

@see: OGC specifications for Simple Features

Classes:

    Geometry (abstract)
    Point
    LineString
    LinearRing
    Polygon

Not defined in simple feature spec:    
    Envelope
    Segment
"""
from _wkb import dumps
try:
    import psycopg2.extensions
    HAS_PSYCOPG2 = True
except ImportError:
    HAS_PSYCOPG2 = False

##------------------------------------------------------------------------------
## TODO:
## - Make bbox calculation work:
##   ==> responsibility of updating lies outside object now
##       (see wkb / wkt parser)
##       Should change to inside of objects (encapsulated!)
##------------------------------------------------------------------------------
#
cdef inline double cabs(double a):
    """
    Gives the absolute value of a
    """
    if a < 0.0:
        return -a
    else:
        return a

cdef inline double cmax(double a, double b):
    """
    Gives the maximum of two values
    """
    if a > b:
        return a
    else:
        return b

cdef inline double cmin(double a, double b):
    """
    Gives the minimum of two values
    """
    if a < b:
        return a
    else:
        return b
#==============================================================================
#cdef inline bint box_box_intersects(box_t *one, box_t *other):
#    return not (other.xmin > one.xmax or other.xmax < one.xmin or \
#                other.ymin > one.ymax or other.ymax < one.ymin)
#
cdef inline box_box_merge(box_t *one, box_t *other):
    one.xmin = cmin(one.xmin, other.xmin)
    one.ymin = cmin(one.ymin, other.ymin)
    one.xmax = cmax(one.xmax, other.xmax)
    one.ymax = cmax(one.ymax, other.ymax)
#
#cdef inline bint box_box_contains(box_t *one, box_t *other):
#    return one.xmin <= other.xmin and \
#           one.ymin <= other.ymin and \
#           one.xmax >= other.xmax and \
#           one.ymax >= other.ymax
#
#cdef inline bint box_box_contains_strictly(box_t *one, box_t *other):
#    return one.xmin < other.xmin and \
#           one.ymin < other.ymin and \
#           one.xmax > other.xmax and \
#           one.ymax > other.ymax
#
cdef bint box_eq(box_t *one, box_t *other):
    """
    Finds if two path_t's are exactly similar
    """
    cdef int i
    return one.xmin == other.xmin and \
           one.ymin == other.ymin and \
           one.xmax == other.xmax and \
           one.ymax == other.ymax
#
cdef inline double box_area(box_t *one):
    return (one.xmax - one.xmin) * (one.ymax - one.ymin)
#==============================================================================
# --- coord_t struct
cdef coord_t *coord_new() except NULL:
    """
    Allocates memory for a coordinate
    """
    cdef coord_t *ret
    # ret = <coord_t*>NULL
    ret = <coord_t*>malloc(sizeof(coord_t))
    if ret == NULL:
        raise MemoryError("coord_new")
    return ret

cdef void coord_dealloc(coord_t *coord):
    """
    Frees memory for a coordinate
    """
    free(coord)
    return

#
# --- path_t struct
#
cdef path_t *path_new():
    """
    Allocates memory for a path
    """
    cdef path_t *ret
    ret = <path_t*>malloc(sizeof(path_t))
    if not ret:
        raise MemoryError("path_new")
    return ret

cdef void path_new_coords(path_t *path, int ct = 0):
    """
    Allocates memory for the coordinates in the path
    """
    if ct <= 0:
        ct = 1
    path.items = 0
    path.allocated = <int>REALLOC_PATH * \
                     <int>ceil(<double>ct / <double>REALLOC_PATH)
    path.coords = <coord_t *>malloc(sizeof(coord_t) * path.allocated)
    if not path.coords:
        raise MemoryError("path_init")

cdef void path_add_coord(path_t *path, double x, double y):
    """
    Adds a coordinate to a path, and reallocates if the coordinate
    doesn't fit any more
    """
    path.items += 1
    if path.allocated == path.items:
        path.allocated += REALLOC_PATH
        path.coords = <coord_t*>realloc(path.coords,
                                        sizeof(coord_t) * path.allocated)
        if not path.coords:
            raise MemoryError("path.coords")
    path_set_coord(path, path.items-1, x, y)

cdef void path_extend(path_t *path_dest, path_t * path_source):
    """
    Extends a path with coordinates of another path
    """
    cdef int source_size = path_source.items
    cdef int dest_size = path_dest.items
    cdef int i = 0
    
    # if destination path does not have enough space we realloc to
    # create enough space for holding also the extension
    if path_dest.allocated <= (path_dest.items + source_size):
        # allocate more space on the dest
        path_dest.allocated += <int>(REALLOC_PATH * \
                               ceil(<double>source_size / <double>REALLOC_PATH))
        path_dest.coords = <coord_t*>realloc(path_dest.coords,
                                             sizeof(coord_t) * \
                                             path_dest.allocated)
        if not path_dest.coords:
            raise MemoryError("path_dest.coords")
    # add all coordinates from source to destination path
    path_dest.items = dest_size + source_size
    for i from 0 <= i < source_size:
        path_set_coord(path_dest,
                       dest_size + i,
                       path_source.coords[i].x,
                       path_source.coords[i].y)

cdef void path_grow(path_t *path_dest, int size):
    """
    Grows a path so that ``size'' number of coordinates can be placed
    in the path
    """
    # if destination path does not have enough space we realloc to 
    if path_dest.allocated <= (path_dest.items + size):
        path_dest.allocated += <int>(REALLOC_PATH * ceil(<double>size / <double>REALLOC_PATH)) 
        path_dest.coords = <coord_t*>realloc(path_dest.coords, 
                                             sizeof(coord_t) * \
                                             path_dest.allocated)
        if not path_dest.coords:
            raise MemoryError("path_dest.coords")

cdef void path_set_coord(path_t * path, int key, double x, double y):
    """
    Set the coordinate at place 'key' to the new value
    
    It's up to the caller to ensure that place 'key' exists in the path
    """
    cdef coord_t coord
    coord.x = x
    coord.y = y
    path.coords[key] = coord
    return

#cdef void path_delete_coord(path_t *path, int key):
#    """
#    Delete the coordinate at place 'key' from the path
#    """
#    # TODO: should we free/realloc stuff ?
#    cdef int i
#    if key < 0 or key > path.items:
#        return
#    for i from key < i < path.items:
#        path.coords[i-1] = path.coords[i]
#    path.items -= 1
#    return

cdef double path_length(path_t *path):
    cdef int i
    cdef double result
    result = 0
    for i from 1 <= i < path.items:
        dx = path.coords[i].x - path.coords[i-1].x 
        dy = path.coords[i].y - path.coords[i-1].y
        result += sqrt(dx*dx + dy*dy)
    return result

cdef void path_dealloc(path_t *path):
    """
    Frees memory in use for the path and for the coordinates
    """
    free(path.coords)
    free(path)
    return
#
cdef bint path_eq(path_t *one, path_t *other):
    """
    Finds if two path_t's are exactly similar
    """
    cdef int i
    if one.items == other.items:
        for i from 0 <= i < one.items:
            if one.coords[i].x != other.coords[i].x or \
                one.coords[i].y != other.coords[i].y:
                return False
        else:
            return True
    else:
        return False
#
## --- surface_t struct
cdef surface_t *surface_new() except NULL:
    """
    Allocates memory to hold a surface_t
    """
    cdef surface_t * ret
    ret = <surface_t*>malloc(sizeof(surface_t))
    if not ret:
        raise MemoryError("surface")
    return ret

cdef void surface_new_paths(surface_t *surface):
    surface.items = 0
    surface.allocated = REALLOC_SURFACE
    surface.paths = <path_t**>malloc(sizeof(path_t) * surface.allocated)
    if not surface.paths:
        raise MemoryError

cdef void surface_add_path(surface_t * surface, path_t *path):
    """
    Adds a path to a surface
    """
    surface.items += 1
    if surface.allocated == surface.items:
        surface.allocated += REALLOC_SURFACE
        surface.paths = <path_t**>realloc(surface.paths, \
                                          sizeof(path_t) * surface.allocated)
        if not surface.paths:
            raise MemoryError("surface.paths")
    surface.paths[surface.items-1] = path

#
cdef void surface_dealloc(surface_t *surface):
    """
    Frees memory in use for a surface_t and its path_t's
    """
    cdef int i
    for i from 0 <= i < surface.items:
        path_dealloc(surface.paths[i])
    free(surface.paths)
    free(surface)


cdef double surface_area(surface_t *surface):
    cdef int i
    cdef double area = 0.
    for i from 0 <= i < surface.items:
        area += path_signed_area(surface.paths[i])
    return area

#cdef void surface_add_coord(surface_t * surface, int ring, \
#                            double x, double y):
#    """
#    Add a coordinate to a path belonging to a surface
#    """
#    cdef coord_t coord
#    coord.x = x
#    coord.y = y
#    surface.paths[ring].items += 1
#    if surface.paths[ring].allocated == surface.paths[ring].items:
#        surface.paths[ring].allocated += REALLOC
#        surface.paths[ring].coords = \
#            <coord_t*>realloc(surface.paths[ring].coords, \
#                              sizeof(coord_t)*surface.paths[ring].allocated)
#        if surface.paths[ring].coords == NULL:
#            raise MemoryError
#    surface.paths[ring].coords[surface.paths[ring].items-1] = coord
#    return
#
#cdef void surface_delete_path(surface_t *surface, int key):
#    """
#    Delete a path from a surface
#    """
#    cdef int i
#    if key < 0 or key > surface.items:
#        return
#    for i from key < i < surface.items:
#        surface.paths[i-1] = surface.paths[i]
#    surface.items -= 1
#    return
#

cdef bint surface_eq(surface_t *one, surface_t *other):
    """
    Finds if two surface_t's are exactly similar
    """
    cdef int i
    if one.items == other.items:
        for i from 0 <= i < one.items:
            if not path_eq(one.paths[i], \
                                other.paths[i]):
                return False
        else:
            return True
    else:
        return False

## --- box_t struct
cdef box_t *box_new() except NULL:
    """
    Allocates memory for a box_t
    """
    cdef box_t *ret
    ret = <box_t*>malloc(sizeof(box_t))
    if ret == NULL:
        raise MemoryError
    else:
        ret.xmin = HUGE_VAL
        ret.ymin = HUGE_VAL
        ret.xmax = HUGE_VAL
        ret.ymax = HUGE_VAL
    return ret
#
cdef void box_dealloc(box_t *mbr):
    """
    Frees memory for a box_t
    """
    free(mbr)
#
cdef bint box_inited(box_t *mbr):
    """
    Finds if a box_t is inited
    """
    # TODO: is this function 100% reliable, based on HUGE_VAL ?
    if mbr.xmin == HUGE_VAL or \
       mbr.ymin == HUGE_VAL or \
       mbr.xmax == HUGE_VAL or \
       mbr.ymax == HUGE_VAL:
        return False
    else:
        return True
#
#cdef void coord_box(coord_t *coord, box_t *mbr):
#    """
#    Sets a box for a coordinate
#    """
#    mbr.xmin = coord[0].x
#    mbr.ymin = coord[0].y
#    mbr.xmax = coord[0].x
#    mbr.ymax = coord[0].y
#    return
#
cdef void path_box(path_t *path, box_t *mbr):
    """
    Sets a box for a path
    """
    cdef int i
    if path.items == 0:
        return
    else:
        mbr.xmin = path.coords[0].x
        mbr.ymin = path.coords[0].y
        mbr.xmax = path.coords[0].x
        mbr.ymax = path.coords[0].y
        if path.items <= 1:
            return
        for i from 1 <= i < path.items:
            mbr.xmin = cmin(mbr.xmin, path.coords[i].x)
            mbr.ymin = cmin(mbr.ymin, path.coords[i].y)
            mbr.xmax = cmax(mbr.xmax, path.coords[i].x)
            mbr.ymax = cmax(mbr.ymax, path.coords[i].y)
        return
#
cdef bint surface_box(surface_t *surface, box_t *mbr):
    """
    Sets a box for a surface
    """
    cdef int i, j
    cdef bint first = True
    if surface.items != 0:
        for i from 0 <= i < surface.items:
            for j from 0 <= j < surface.paths[i].items:
                if first == True:
                    mbr.xmin = surface.paths[i].coords[j].x
                    mbr.ymin = surface.paths[i].coords[j].y
                    mbr.xmax = surface.paths[i].coords[j].x
                    mbr.ymax = surface.paths[i].coords[j].y
                    first = False
                else:
                    mbr.xmin = cmin(mbr.xmin, surface.paths[i].coords[j].x)
                    mbr.ymin = cmin(mbr.ymin, surface.paths[i].coords[j].y)
                    mbr.xmax = cmax(mbr.xmax, surface.paths[i].coords[j].x)
                    mbr.ymax = cmax(mbr.ymax, surface.paths[i].coords[j].y)

#==============================================================================
cdef class Geometry:
    """
    Abstract Geometry class
    """
    def __init__(self):
        raise ValueError("Geometry is abstract and cannot be instantiated")
    
    # {{{
    # Conform to PsycoPG2's protocol, for quoting into SQL statements
    def __conform__(self, protocol):
        if HAS_PSYCOPG2 and protocol is psycopg2.extensions.ISQLQuote:
            return self

    # This method also needs to be there for object conforming to ISQLQuote
    def getquoted(self):
        return "'{}'".format(dumps(self))
    # }}}

    property area:
        """Returns the areal size of this Geometry.
        """
        def __get__(self):
            return 0.

    property length:
        """Returns the length of this Geometry.
        """
        def __get__(self):
            return 0.

    property geom_type:
        """Returns the type of this Geometry.
        """
        def __get__(Geometry self):
            return self.__class__.__name__

    property has_z:
        """Boolean read-only property indicating whether the geometry object 
        has a *z* coordinate.
        
        .. note ::
            always returns False
        """
        def __get__(Geometry self):
            return False

    property has_m:
        """Boolean read-only property indicating whether the geometry object 
        has a *m* coordinate.
        
        .. note ::
            always returns False
        """
        def __get__(Geometry self):
            return False

    property wkt:
        """Returns the WKT string for this Geometry.
        """
        def __get__(Geometry self):
            return str(self)

    property wkb:
        """Returns the HEXEWKB string for this Geometry.
        """
        def __get__(Geometry self):
            return dumps(self)

    property srid:
        def __get__(Geometry self):
            return self._srid

        def __set__(Geometry self, int srid):
            self._srid = srid

cdef class Point(Geometry):
    """
    Point class
    """
    def __cinit__(Point self):
        try:
            self._coord = coord_new()
        except MemoryError:
            raise
        self._xinit = False
        self._yinit = False
        self._geom_type = WKB_POINT
    
    def __init__(Point self, x = None, y = None, int srid = 0):
        """
        :Example:
        
        >>> from simplegeo.geometry import Point
        >>> Point(5, 0)
        Point(x=5.0, y=0.0, srid=0)
        >>> Point(5, 0, srid=28992)
        Point(x=5.0, y=0.0, srid=28992)
        >>> 
        """
        if x != None:
            self._coord.x = x
            self._xinit = True
        if y != None:
            self._coord.y = y
            self._yinit = True
        self.srid = srid
    
    def __dealloc__(Point self):
        coord_dealloc(self._coord)
    
    def __str__(Point self):
        if self._inited == False:
            return "SRID={};POINT EMPTY".format(self.srid)
        else:
            return "SRID={};POINT({} {})".format(self.srid, self.x, self.y)
    
    def __repr__(Point self):
        if self._inited == False:
            return "Point(srid={})".format(self.srid)
        else:
            return "Point(x={}, y={}, srid={})".format(self.x, self.y, self.srid)
    
    def __richcmp__(Point self, Point other not None, int op):
        # ==
        if op == 2:
            if isinstance(other, self.__class__) and \
            self.x == other.x and self.y == other.y:
                return True
            else:
                return False
        elif op == 3:
            if isinstance(other, self.__class__) and \
            self.x != other.x or self.y != other.y:
                return True
            else:
                return False
        else:
            raise NotImplementedError('comparison op ({0}) not implemented'.format(op))
    
    
    def __hash__(Point self):
#      """Returns a 32-bit integer hash of this Point.
#
#      Implements Python's hash protocol so that Point may be used in sets and
#      as dictionary keys.
#
#      Returns:
#        int
#      """
      return hash((self._coord.x, self._coord.y))

    
    def __getitem__(Point self, unsigned int i):
        if i == 0:
            return self.x
        elif i == 1:
            return self.y
        else:
            raise IndexError("Getitem key")
    
    def __setitem__(Point self, unsigned int i, double val):
        if i == 0:
            self._coord.x = val
        elif i == 1:
            self._coord.y = val
        else:
            raise IndexError("Setitem key")
    
    def __delitem__(Point self, int key):
        raise NotImplementedError
    
    property x:
        """
        The x-ordinate of the Point
        """
        def __get__(Point self):
            if not self._inited:
                raise ValueError("x or y not set")
            return self._coord.x
        def __set__(Point self, double x):
            self._coord.x = x
            self._xinit = True
    
    property y:
        """
        The y-ordinate of the Point
        """
        def __get__(Point self):
            if not self._inited:
                raise ValueError("x or y not set")
            return self._coord.y
        def __set__(Point self, double y):
            self._coord.y = y
            self._yinit = True
    
    property _inited:
        def __get__(Point self):
            return (self._xinit and self._yinit)
    
    property is_empty:
        """
        Returns whether both the x- and y-ordinate of this Point are set
        """
        def __get__(Point self):
            return not self._inited
    
    property envelope:
        """
        Returns an Envelope (axis-aligned bounding box) for this Point.
        """
        def __get__(Point self):
            cdef Envelope ev
            if self._inited:
                ev = Envelope(srid=self.srid)
                ev._mbr.xmin = self._coord.x
                ev._mbr.ymin = self._coord.y
                ev._mbr.xmax = self._coord.x
                ev._mbr.ymax = self._coord.y                
                return ev
            else:
                raise ValueError("Point empty -> no Envelope")

#==============================================================================
cdef class LineString(Geometry):
    """
    LineString class
    """
    def __cinit__(LineString self):
        try:
            self._path = path_new()
        except MemoryError:
            raise
        try:
            path_new_coords(self._path)
        except MemoryError:
            raise
        self._geom_type = WKB_LINE
    
    def __init__(LineString self, coords = None, int srid = 0):
        """
        :Example:
        
        >>> from simplegeo.geometry import LineString
        >>> LineString(((0,0), [10,10]))
        LineString([Point(x=0.0, y=0.0, srid=0), Point(x=10.0, y=10.0, srid=0)], srid=0)
        >>> 
        """
        if coords is not None:
            try:
                for c in coords:
                    self.append(Point(c[0], c[1])) 
            except:
                raise ValueError('Incorrect coords found')
        self.srid = srid

    def __dealloc__(LineString self):
        path_dealloc(self._path)
    
    def __len__(LineString self):
        return self._path.items
    
    def __str__(LineString self):
        cdef int i
        if self._path.items == 0:
            return "SRID={};LINESTRING EMPTY".format(self.srid)
        else:
            ret = []
            for i from 0 <= i < self._path.items:
                ret.append("{} {}".format(self._path.coords[i].x, \
                    self._path.coords[i].y))
            return "SRID={};LINESTRING({})".format(self.srid, ', '.join(ret))
    
    def __repr__(LineString self):
        cdef int i
        if self._path.items == 0:
            return "LineString(srid={})".format(self.srid)
        else:
            ret = []
            for i from 0 <= i < self._path.items:
                ret.append("Point(x={}, y={}, srid={})".format(
                    self._path.coords[i].x,
                    self._path.coords[i].y,
                    self.srid))
            return "LineString([{}], srid={})".format(', '.join(ret), self.srid)
    
    def __richcmp__(LineString self, LineString other not None, int op):
        if op == 2: # ==
            if isinstance(other, self.__class__):
                if not path_eq(self._path, other._path):
                    return False
                else:
                    return True
            else:
                return False
        elif op == 3:
            if isinstance(other, self.__class__) and \
            path_eq(self._path, other._path):
                return False
            else:
                return True
        else:
            raise NotImplementedError('comparison op ({0}) not implemented'.format(op))
    
    def __getitem__(LineString self, object which):
        cdef int i, j
        cdef path_t *path
        cdef LineString ln
        cdef int ct
        if isinstance(which, int):
            #
            # TODO: accept negative indices (just like list!!!)
            #
            if which < 0:
                which += self._path.items
            if which < 0 or which >= self._path.items:
                raise IndexError("No point there (#%d) for %s" % (which, self) )
            else:
                return Point(self._path.coords[which].x,
                             self._path.coords[which].y)
        elif isinstance(which, slice):
            # find number of items that will be result of slicing
            ln = LineString()
            ct = 0
            start, stop, step, = which.indices(self._path.items)
            for i in range(start, stop, step):
                ct += 1
            # ensure that path of new linestring has enough space for
            # number of coordinates to be sliced
            try:
                path_grow(ln._path, ct)
            except MemoryError:
                raise                
            # fill path with items asked for by slice
            ln._path.items = ct
            for i, j in enumerate(range(start, stop, step)):
                path_set_coord(ln._path, i, 
                               self._path.coords[j].x, self._path.coords[j].y)
            return ln
        else:
            raise ValueError("Unknown type encountered in __getitem__")
    
    def __setitem__(LineString self, int key, Point item):
        # TODO: method should also accept slice for replacing points !
        #       but this is a major revision => 0.6 Release
        #       as this can also change the length -> should be reallocated
        if key < 0 or key >= self._path.items:
            raise IndexError
        else:
            path_set_coord(self._path, key, item.x, item.y)
    
    def __delitem__(LineString self, int key):
        raise NotImplementedError
    
    def __reduce__(self):
        ret = []
        for i from 0 <= i < self._path.items:
            ret.append((self._path.coords[i].x, self._path.coords[i].y))
        return (LineString, (ret,)) 

    def index(LineString self, Point pt):
        """
        Return the index in the LineString of the first Point found.
        
        :param pt: Point to get the index for
        :type pt: Point
        :returns: int
        :raises: ValueError
        
        It is an error if there is no such Point.

        :Example:
        
        >>> from simplegeo.geometry import LineString, Point
        >>> ln = LineString([(0,0), (10,10)])
        >>> pt = Point(10,10)
        >>> ln.index(pt)
        1
        >>> 
        """
        for i from 0 <= i < self._path.items:
            if self._path.coords[i].x == pt.x and \
               self._path.coords[i].y == pt.y:
                return i
        else:
            raise ValueError, "LineString.index(x): x not in list"
    
    def append(LineString self, Point pt):
        """
        Add a Point to the end of the LineString
        
        :param pt: The Point to append
        :type pt: Point
        :returns: void
        :raises: MemoryError
        
        
        :Example:

        >>> from simplegeo.geometry import LineString, Point
        >>> ln = LineString()
        >>> ln.append(Point(10,10))
        >>> 
        """
        try:
            path_add_coord(self._path, pt.x, pt.y)
        except MemoryError:
            raise
    
    def extend(LineString self, LineString ln, slice portion = None):
        """
        Extend the LineString by appending (a portion of) the coordinates in 
        the given LineString.
        
        :param ln: The LineString to add
        :param portion: A slice object (optional) that says which portion of *ln* to add
        
        :type ln: LineString
        :type portion: slice
        
        :returns: void
        :raises: MemoryError
        """
        if portion is None:
            try:
                path_extend(self._path, ln._path)
            except MemoryError:
                raise
        else:
            extend_slice(self, ln, portion)

    def reverse(LineString self):
        """
        Reverse the coordinates of the LineString, in place.
        """
        # create new path
        cdef path_t * path
        try:
            path = path_new()
        except MemoryError:
            raise
        try:
            path_new_coords(path, self._path.items)
        except MemoryError:
            raise
        # add coordinates in reversed order
        # (see: 2nd argument for path_set_coord)
        path.items = self._path.items
        for i from 0 <= i < self._path.items:
            path_set_coord(path, 
                           self._path.items - 1 - i, # make reverse of index i
                           self._path.coords[i].x, self._path.coords[i].y)
        # free current path and set to newly created one
        path_dealloc(self._path)
        self._path = path
    
    property is_empty:
        """
        Returns whether this LineString has coordinates or not.
        """
        def __get__(LineString self):
            return self._path.items == 0
    
    property envelope:
        """
        Returns an Envelope (axis-aligned bounding box) for this LineString.
        """
        def __get__(LineString self):
            cdef Envelope ev
            if self._path.items > 0:
                ev = Envelope(srid=self.srid)
                path_box(self._path, ev._mbr)
                return ev
            else:
                raise ValueError("LineString empty -> no Envelope")
    
    property length:
        def __get__(self):
            return path_length(self._path)


cdef class LinearRing(LineString):
    """LinearRing class"""
    def __init__(LineString self, coords = None, srid = 0):
        if coords is not None:
            if not len(coords) > 3:
                raise ValueError("Too little coordinates in LinearRing")
            if not coords[0] == coords[-1]:
                raise ValueError("Start coordinate does not match end coordinate")
        super(LinearRing, self).__init__(coords)
        self.srid = srid

    def signed_area(self):
        """Returns the area together with a sign (+ or -) of its size.
        """
        return path_signed_area(self._path)

    def __repr__(LinearRing self):
        cdef int i
        if self._path.items == 0:
            return "LinearRing(srid={})".format(self.srid)
        else:
            ret = []
            for i from 0 <= i < self._path.items:
                ret.append("Point(x={}, y={}, srid={})".format(
                    self._path.coords[i].x,
                    self._path.coords[i].y,
                    self.srid))
            return "LinearRing([{}], srid={})".format(', '.join(ret), self.srid)

    property is_ccw:
        def __get__(self):
            return is_ccw(self)


cdef class Polygon(Geometry):
    """
    Polygon class
    """
    def __cinit__(Polygon self):
        try:
            self._surface = surface_new()
        except MemoryError:
            raise
        try:
            surface_new_paths(self._surface)
        except MemoryError:
            raise
        self._geom_type = WKB_POLY
    
    def __init__(Polygon self, shell = None, holes = None, srid = 0):
        """Inits a polygon with one exterior ring (shell) 
        and zero or more inner rings (holes)
        """
        try:
            if shell is not None:
                self.append(shell)
        except:
            raise ValueError('Incorrect shell found, should be of type LineString')
        
        try:
            if holes is not None:
                for hole in holes:
                    self.append(hole)
        except:
            raise ValueError('Incorrect hole found, all should be of type LineString')
        self.srid = srid

    def __dealloc__(Polygon self):
        surface_dealloc(self._surface)
    
    def __len__(Polygon self):
        return self._surface.items
    
    def __richcmp__(Polygon self, Polygon other not None, int op):
        # ==
        if op == 2:
            if isinstance(other, self.__class__) and \
                surface_eq(self._surface, other._surface):
                return True
            else:
                return False
#
    def __getitem__(Polygon self, int key):
        cdef LineString l = LineString()
        cdef int j
        
        if key < 0 or key >= self._surface.items:
            raise IndexError
        else:
            try:
                path_extend(l._path, self._surface.paths[key])
            except MemoryError:
                raise
            return l
#
#    def __setitem__(Polygon self, int key, LineString item not None):
#        cdef int j
#        if key < 0 or key >= self._surface.items:
#            raise IndexError
#        else:
#            self._surface.paths[key].items = 0
#            for j from 0 <= j < item._path.items:
#                path_add_coord(self._surface.paths[key], \
#                                    item._path.coords[j].x, \
#                                    item._path.coords[j].y)
#            surface_box(self._surface, self._envelope._mbr)
#

    def __delitem__(Polygon self, int key):
        raise NotImplementedError

#    def __delitem__(Polygon self, int key):
#        if key < 0 or key >= self._surface.items:
#            raise IndexError
#        else:
#            surface_delete_path(self._surface, key)
#            surface_box(self._surface, self._envelope._mbr)

    def __reduce__(Polygon self):
        cdef int i, j
        if self._surface.items == 0:
            rings = []
        else:
            rings = []
            for i from 0 <= i < self._surface.items:
                ring = LineString()
                for j from 0 <= j < self._surface.paths[i].items:
                    ring.append(Point(self._surface.paths[i].coords[j].x,
                                           self._surface.paths[i].coords[j].y))
                rings.append(ring)
        if len(rings) == 0:
            return (Polygon, tuple())
        elif len(rings) == 1:
            return (Polygon, (rings[0],))
        else: 
            return (Polygon, (rings[0], rings[1:]))

    def __str__(Polygon self):
        cdef int i, j
        if self._surface.items == 0:
            return "SRID={};POLYGON EMPTY".format(self.srid)
        else:
            rings = []
            for i from 0 <= i < self._surface.items:
                ring = []
                for j from 0 <= j < self._surface.paths[i].items:
                    ring.append("{} {}".format(self._surface.paths[i].coords[j].x,
                                           self._surface.paths[i].coords[j].y))
                rings.append("({})".format(', '.join(ring)))
            return "SRID={};POLYGON({})".format(self.srid, ', '.join(rings))
    
    def append(Polygon self, LinearRing ring):
        """Add a LinearRing to the Polygon.
        
        :param ring: The LinearRing to add
        :type ring: LinearRing
        :returns: void
        :raises: MemoryError
        
        The first LinearRing added is the outer ring. All other LinearRing
        appended (automatically) are seen as inner rings.
        """
        # TODO:
        # is this what we want (validation for input?):
        #     if ln._path.items <= 4:
        #        raise ValueError("LineString should have at least 4 coords")
        # then probably we should test whether start == end as well
        
        # allocate space for a path and for the number of items now in ln
        cdef path_t * path
        try:
            path = path_new()
        except MemoryError:
            raise
        try:
            path_new_coords(path, ring._path.items)
        except MemoryError:
            raise
        # add the path to the surface_t struct
        try:
            surface_add_path(self._surface, path)
        except MemoryError:
            raise
        # copy the coordinates from the line to the newly added path
        try:
            path_extend(self._surface.paths[self._surface.items - 1],
                        ring._path)
        except MemoryError:
            raise

    property is_empty:
        """Returns whether this Polygon has any rings and if so, it is
        checked whether these rings (LinearRings) are empty.
        """
        def __get__(Polygon self):
            if self._surface.items == 0:
                return True
            else:
                for i from 0 <= i < self._surface.items:
                    if self._surface.paths[i].items == 0:
                        return True
                return False

    property envelope:
        """Returns an Envelope (axis-aligned bounding box) for this Polygon.
        """
        # TODO:
        # deal with case that there are only linestrings with one coordinate
        # -> will give invalid envelope, while surface.items > 0
        def __get__(Polygon self):
            cdef Envelope ev
            if self._surface.items > 0:
                ev = Envelope(srid=self.srid)
                surface_box(self._surface, ev._mbr)
                return ev
            else:
                raise ValueError("Polygon empty -> no Envelope")

    def representative_point(Polygon self):
        """Returns a Point **guaranteed** to be on the interior 
        of the Polygon.
        """
        # TODO:
        # deal with case that there are only linestrings with one coordinate
        # -> will give invalid surface, while surface.items > 0
        if not self.is_empty:
            return point_in_polygon(self)
        else:
            raise ValueError("Polygon empty -> no Point")

    property area:
        """Returns the size of the Polygon.
        
        It is assumed that the Polygon is valid according to the
        Simple Feature definitions.
        """
        def __get__(Polygon self):
            return surface_area(self._surface)
#            raise NotImplementedError("Not there yet")

    property centroid:
        """Returns a Point being the centroid of the Polygon.
        
        .. warning ::
            The computed Point can be outside the interior of the Polygon.
        """
        def __get__(Polygon self):
            raise NotImplementedError("Not there yet")

cdef class Envelope(Geometry):
    """
    Envelope (axis-aligned bounding box) class
    """
    def __cinit__(Envelope self):
        try:
            self._mbr = box_new()
        except MemoryError:
            raise
        self._geom_type = WKB_ENVELOPE
    
    def __init__(Envelope self, xmin = None, ymin = None,
                                xmax = None, ymax = None, srid = 0):
        if xmin is not None and \
           ymin is not None and \
           xmax is not None and \
           ymax is not None:
            if xmax < xmin:
                raise RuntimeError("Invalid BBox given, x direction")
            if ymax < ymin:
                raise RuntimeError("Invalid BBox given, y direction")
            self._mbr.xmin = xmin
            self._mbr.ymin = ymin
            self._mbr.xmax = xmax
            self._mbr.ymax = ymax
            self.srid = srid
    
    def __getitem__(Envelope self, unsigned int i):
        if i == 0:
            return Point(self.xmin, self.ymin)
        elif i == 1:
            return Point(self.xmax, self.ymax)
        else:
            raise IndexError("Getitem key")
    
    def __dealloc__(Envelope self):
        box_dealloc(self._mbr)
    
    def __richcmp__(Envelope self, Envelope other not None, int op):
        # ==
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        if box_inited(other._mbr) == False:
            raise RuntimeError("Box not inited")
        if op == 2:
            if isinstance(other, self.__class__) and \
                box_eq(self._mbr, other._mbr):
                return True
            else:
                return False
    
    def __repr__(Envelope self):
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        return "SRID={};BOX({} {}, {} {})".format(self.srid,
            self._mbr.xmin,
            self._mbr.ymin,
            self._mbr.xmax,
            self._mbr.ymax)
    
    def __str__(Envelope self):
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        return "SRID={};POLYGON(({} {}, {} {}, {} {}, {} {}, {} {}))".format(self.srid,
            self._mbr.xmin, self._mbr.ymin,
            self._mbr.xmin, self._mbr.ymax,
            self._mbr.xmax, self._mbr.ymax,
            self._mbr.xmax, self._mbr.ymin,
            self._mbr.xmin, self._mbr.ymin)

    property polygon:
        def __get__(Envelope self):
            cdef Polygon pl 
            cdef LinearRing ln
            pl = Polygon(srid = self.srid)
            ln = LinearRing() 
            ln.append(Point(self._mbr.xmin, self._mbr.ymin))
            ln.append(Point(self._mbr.xmin, self._mbr.ymax))
            ln.append(Point(self._mbr.xmax, self._mbr.ymax))
            ln.append(Point(self._mbr.xmax, self._mbr.ymin))
            ln.append(Point(self._mbr.xmin, self._mbr.ymin))
            pl.append(ln)
            return pl
    
    def enlarge_by(Envelope self, Envelope other):
        """
        Enlarges the extent of this Envelope with the given Envelope.
        It is an error if one of both Envelopes is not inited.
        """
        # TODO: 
        # make it also possible to give other types to enlarge envelope by?
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        if box_inited(other._mbr) == False:
            raise RuntimeError("Box not inited")
        box_box_merge(self._mbr, other._mbr)

    # Binary topological relations
    def contains(Envelope self, Geometry other):
        """Tests if Geometry *other* lies completely inside this Envelope 
        *self* (boundary is considered inclusive).
        
        """
#        cdef bint inside
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        
        if isinstance(other, Point):
            if (other.x < self._mbr.xmin or \
                other.x > self._mbr.xmax or \
                other.y < self._mbr.ymin or \
                other.y > self._mbr.ymax):
                return False
            else:
                return True
        elif isinstance(other, Envelope):
            if (other.xmin < self._mbr.xmin or \
                other.xmax > self._mbr.xmax or \
                other.ymin < self._mbr.ymin or \
                other.ymax > self._mbr.ymax):
                return False
            else:
                return True
        else:
            raise NotImplementedError("Unknown type given for contains")

    def covers(Envelope self, Geometry other):
        """Synonym for contains
        """
        return self.contains(other)
    
    def contains_properly(Envelope self, Geometry other):
        """Returns true if *other* intersects the interior of *self* but not 
        the boundary (or exterior).
        
        """
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        
        if isinstance(other, Point):
            if self._mbr.xmin < other.x and \
               self._mbr.xmax > other.x and \
               self._mbr.ymin < other.y and \
               self._mbr.ymax > other.y:
                return True
            else:
                return False
        elif isinstance(other, Envelope):
            if self._mbr.xmin < other.xmin and \
               self._mbr.xmax > other.xmax and \
               self._mbr.ymin < other.ymin and \
               self._mbr.ymax > other.ymax:
                return True
            else:
                return False
        else:
            raise NotImplementedError("Unknown type given for contains")
        
    def intersects(Envelope self, object other):
        """Tests whether objects are _not_ disjoint
        """
        if box_inited(self._mbr) == False:
            raise RuntimeError("Box not inited")
        if isinstance(other, Envelope):
            if (other.xmax < self._mbr.xmin or \
                other.ymax < self._mbr.ymin or \
                other.xmin > self._mbr.xmax or \
                other.ymin > self._mbr.ymax):
                return False
            else:
                return True
        if isinstance(other, tuple):
            if (other[2] < self._mbr.xmin or \
                other[3] < self._mbr.ymin or \
                other[0] > self._mbr.xmax or \
                other[1] > self._mbr.ymax):
                return False
            else:
                return True

    def disjoint(Envelope self, object other):
        """Tests whether objects are disjoint
        """
        return not self.intersects(self, other)
    
    property area:
        def __get__(self):
            if box_inited(self._mbr) == False:
                raise RuntimeError("Box not inited")
            return box_area(self._mbr)
    
    property xmin:
        """
        Returns the value of the smallest ordinate in x-direction
        """
        def __get__(Envelope self):
            if box_inited(self._mbr) == False:
                raise RuntimeError("Box not inited")
            return self._mbr.xmin
        def __set__(Envelope self, xmin):
            self._mbr.xmin = xmin
    
    property ymin:
        """
        Returns the value of the smallest ordinate in y-direction
        """
        def __get__(Envelope self):
            if box_inited(self._mbr) == False:
                raise RuntimeError("Box not inited")
            return self._mbr.ymin
        def __set__(Envelope self, ymin):
            self._mbr.ymin = ymin
    
    property xmax:
        """
        Returns the value of the largest ordinate in x-direction
        """
        def __get__(Envelope self):
            if box_inited(self._mbr) == False:
                raise RuntimeError("Box not inited")
            return self._mbr.xmax
        def __set__(Envelope self, xmax):
            self._mbr.xmax = xmax
    
    property ymax:
        """
        Returns the value of the largest ordinate in y-direction
        """
        def __get__(Envelope self):
            if box_inited(self._mbr) == False:
                raise RuntimeError("Box not inited")
            return self._mbr.ymax
        def __set__(Envelope self, ymax):
            self._mbr.ymax = ymax
    
    property width:
        """
        Returns the value of the largest ordinate in y-direction
        """
        def __get__(Envelope self):
            if not box_inited(self._mbr):
                raise RuntimeError("Box not inited")
            return self._mbr.xmax - self._mbr.xmin
    
    property height:
        """
        Returns the value of the largest ordinate in y-direction
        """
        def __get__(Envelope self):
            if not box_inited(self._mbr):
                raise RuntimeError("Box not inited")
            return self._mbr.ymax - self._mbr.ymin
    
    property is_empty:
        """Returns whether this Envelope is inited.
        """
        def __get__(Envelope self):
            return box_inited(self._mbr) == False


cdef class Segment(Geometry):
    """Line Segment
    """
    def __cinit__(Segment self):
        try:
            self._start = coord_new()
        except MemoryError:
            raise
        try:
            self._end = coord_new()
        except MemoryError:
            raise   

    def __dealloc__(Segment self):
        coord_dealloc(self._start)
        coord_dealloc(self._end)

    def __init__(Segment self, Point start, Point end):
        self._start.x = start._coord.x
        self._start.y = start._coord.y
        self._end.x = end._coord.x
        self._end.y = end._coord.y

    def __repr__(Segment self):
        return "Segment(%s %s, %s %s)" % (self._start.x, self._start.y, 
                                          self._end.x, self._end.y)

    def __str__(Segment self):
        return "LINESTRING(%.6f %.6f, %.6f %.6f)" % (self._start.x, self._start.y, 
                                          self._end.x, self._end.y)

    def reverse(Segment self):
        cdef double x, y
        x = self._start.x
        y = self._start.y
        self._start.x = self._end.x
        self._start.y = self._end.y
        self._end.x = x
        self._end.y = y

    def __getitem__(Segment self, unsigned int i):
        if i == 0:
            return self.start
        elif i == 1:
            return self.end
        else:
            raise IndexError("Getitem key")
    

    property envelope:
        def __get__(Segment self):
            cdef Envelope env = Envelope(srid=self.srid)
            env._mbr.xmin = cmin(self._start.x, self._end.x)
            env._mbr.xmax = cmax(self._start.x, self._end.x)
            env._mbr.ymin = cmin(self._start.y, self._end.y)
            env._mbr.ymax = cmax(self._start.y, self._end.y)
            return env

    property start:
        def __get__(Segment self):
            return Point(self._start.x, self._start.y)

    property end:
        def __get__(Segment self):
            return Point(self._end.x, self._end.y)

#            return Envelope(xmin = cmin(self._start.x, self._end.x), 
#                            ymin = cmin(self._start.y, self._end.y),
#                            xmax = cmax(self._start.x, self._end.x), 
#                            ymax = cmax(self._start.y, self._end.y))





cpdef Point point_in_polygon(Polygon poly):
    """Returns a `point', guaranteed to be situated on the interior of `poly'.
    
    Assumed is that the polygon is valid according to the Simple Feature Spec.
    
    The function follows the following logic:
    - Half way at the y-axis of the envelope, shoot a ray through the 
      polygon, from left to right
    - Intersections where the segments crosses the ray are used to find when 
      the ray is inside or outside:
      - Start on the ray (from the left, outside) and walk to the right
      - The largest part of the ray that is inside the polygon determines
        the returned point
      - Number of crossings per ring are kept to see whether a ring is only
        crossing the ray in exactly one point
    """
    cdef int i, j
    cdef double ray_x, ray_y, x0, y0, x1, y1, max_dist, dist
    cdef double eps = 1e-8   
    cdef object ray_x_cross, crossings_per_ring

    ray_x_cross = []
    crossings_per_ring = {}
    ray_y = poly.envelope.ymin + \
            ((poly.envelope.ymax - poly.envelope.ymin) / 2)
    if poly._surface.items == 0:
        raise ValueError("Polygon Empty")
    else:
        # Calculate intersections where segments cross the ray and 
        # store x ordinate of intersection and the ring number of the segment
        # Also keep number of crossings per ring (to see whether 
        # a crossing is a singularity)
        for i from 0 <= i < poly._surface.items:
            if poly._surface.paths[i].items <= 3:
                raise ValueError("Ring [%d] not enough coords" % (i))
            crossings_per_ring[i] = 0
            for j from 1 <= j < poly._surface.paths[i].items:
                # TODO: introduce tolerance here?
                y0 = poly._surface.paths[i].coords[j - 1].y
                y1 = poly._surface.paths[i].coords[j].y
                if (not ((y0 > ray_y and y1 >= ray_y) or \
                         (y0 < ray_y and y1 <= ray_y))):
                    crossings_per_ring[i] += 1
                    if y0 == ray_y:
                        x0 = poly._surface.paths[i].coords[j - 1].x
                        ray_x_cross.append((x0, i))
                    else:
                        x0 = poly._surface.paths[i].coords[j - 1].x
                        x1 = poly._surface.paths[i].coords[j].x
                        ray_x_cross.append((x_intersection_at_ray(x0, y0, 
                                                                  x1, y1,
                                                                  ray_y), i))

        if len(ray_x_cross) < 2:
            raise ValueError("Ray should intersect at least twice the polygon")
        
        # Sort intersections
        # First on x ordinate, then on ring number
        ray_x_cross.sort()

        # Walk over ray, with segment crossings,
        # from left to right to find largest piece of ray that is inside
        # the polygon        
        max_dist = -1
        ray_x = -1
        j = 0
        for i in xrange(0, len(ray_x_cross) - 1):
            if (crossings_per_ring[ray_x_cross[i][1]] != 1):
                j += 1
            if (j % 2): # only after an odd number of crossings we're inside
                dist = ray_x_cross[i + 1][0] - ray_x_cross[i][0]
                if (dist > eps) and (dist > max_dist):
                    # here we are on a piece of the ray,
                    # that lies on the interior of the polygon
                    ray_x = ray_x_cross[i][0] + (dist / 2)
                    max_dist = dist

        if max_dist == -1:
            raise ValueError("No place on ray found for putting point")

        return Point(ray_x, ray_y)

cdef inline double x_intersection_at_ray(double x0, double y0, 
                                         double x1, double y1, 
                                         double ray_y):
    """Return `x ordinate' of point where segment, defined by (`x0', `y0') 
    and (`x1', `y1')  overlaps `ray_y'.
    
    A check if the segment overlaps `ray_y' is up to the caller.
    
    If the segment is collinear with the ray, `x-ordinate' will be 
    equal to `x0'.
    """
    cdef double u
    if (y1 - y0) == 0:
        u = 0
    else:
        u = (ray_y - y0) / (y1 - y0)
    return x0 + u * (x1 - x0)



cdef double path_signed_area(path_t *path):
    cdef int npts
    cdef int i
    cdef double bx
    cdef double by
    cdef double cx
    cdef double cy
    cdef double sum

    npts = path.items 
    if (npts < 3):
        return 0.0

    sum = 0.0
    for i in range(npts - 1):
        bx = path.coords[i].x
        by = path.coords[i].y        
        cx = path.coords[i+1].x
        cy = path.coords[i+1].y
        sum += (bx+cx)*(cy-by)
    return sum * 0.5

#cpdef double signed_area(LineString ring):
#    """Returns signed area of a ring
#    """
#    cdef int i, j
#    cdef double area = 0.0
#    i = 0
#    j = 0
#    for i in xrange(ring._path.items - 1):
#        j = i + 1
#        area += ring._path.coords[i].x * ring._path.coords[j].y
#        area -= ring._path.coords[i].y * ring._path.coords[j].x
#    return area / 2.0


cpdef bint is_ccw(LinearRing ring):
    """Returns True when a ring is oriented counterclockwise

    This is based on the signed area:

     > 0 for counterclockwise
     = 0 for none (degenerate)
     < 0 for clockwise
    """
    cdef double area = ring.signed_area()
    if area > 0:
        return True
    elif area < 0:
        return False
    else:
        raise ValueError("Degenerate ring has no orientation")

cdef extend_slice(LineString to_ln, LineString from_ln, slice slice):
    cdef int ct, i, j, start, stop, step
    cdef int orig_ct = to_ln._path.items
    # get range for values to copy
    start, stop, step, = slice.indices(from_ln._path.items)
#    print start, stop, step, from_ln, range(start, stop, step)
    ct = 0
    for i in range(start, stop, step):
        ct += 1
    try:
        path_grow(to_ln._path, ct)
        to_ln._path.items += ct            
    except MemoryError:
        raise
    # fill path with items asked for by slice
    for i in range(start, stop, step):
        path_set_coord(to_ln._path, orig_ct, 
                       from_ln._path.coords[i].x,
                       from_ln._path.coords[i].y)
        orig_ct += 1