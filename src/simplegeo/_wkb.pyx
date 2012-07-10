# cython: profile=True
"""EWKB reader and writer functions
"""
import logging
from struct import unpack, pack
from cStringIO import StringIO
from binascii import a2b_hex, b2a_hex

log = logging.getLogger(__name__)

cdef class EWKBReader(object):
    """Reads a HEXEWKB string, constructing known geometries from it
    """
#    cdef bint has_z
#    cdef bint has_m
#    cdef int srid
#    cdef object stream
#    cdef str _endianness 
    
    def __init__(self, stream):
        self.stream = stream

    cpdef object read_geometry(self):
        cdef int tp
        tp = self.read_header()
        if tp == 1:
            return self.read_point()        
        elif tp == 2:
            return self.read_linestring()
        elif tp == 3:
            return self.read_polygon()            
        elif tp == 4:
            geoms = []
            ct = self.read_int()
            for _ in range(ct):
                geoms.append(self.read_geometry())
            return geoms
        elif tp == 5:
            geoms = []
            ct = self.read_int()
            for _ in range(ct):
                self.read_header()
                geoms.append(self.read_linestring())
            return geoms
        elif tp == 6:
            geoms = []
            ct = self.read_int()
            for _ in range(ct):
                self.read_header()
                geoms.append(self.read_polygon())
            return geoms
        elif tp == 7:
            geoms = []
            ct = self.read_int()
            for _ in range(ct):
                geoms.append(self.read_geometry())
            return geoms
        else:
            raise Exception('unsupported geometry type <{0}>'.format(tp))

    cdef read_header(self):
        cdef long tp
        cdef str byte_order = self.stream.read(1)
        if byte_order == '\x00':
            self._endianness = '>'
        elif byte_order == '\x01':
            self._endianness = '<'
        else:
            raise Exception('invalid EWKB encoding')
        tp = self.read_int()
        self.has_z = tp & <long long>0x80000000
        self.has_m = tp & <long long>0x40000000
        if tp & <long long>0x20000000:
            self.srid = self.read_int()
        else:
            self.srid = 0
        tp &= <long long>0x1fffffff
        return tp

    cdef long read_int(self):
        return unpack(self._endianness + 'I', self.stream.read(4))[0]

    cdef double read_double(self):
        return unpack(self._endianness + 'd', self.stream.read(8))[0]

    cdef Point read_point(self):
        x, y = self.read_double(), self.read_double()
        return Point(x, y, srid=self.srid)
        
    cdef LineString read_linestring(self):
        ln = LineString(srid=self.srid)
        sz = self.read_int()
        try:
            path_grow(ln._path, sz)
        except MemoryError:
            raise
        for i from 0 <= i < sz:
            xx = self.read_double()
            yy = self.read_double()
            if self.has_z:
                zz = self.read_double()
            if self.has_m:
                mm = self.read_double()
            path_set_coord(ln._path, i, xx, yy)
        ln._path.items = sz
        return ln
#    
    cdef Polygon read_polygon(self):
        ring_ct = self.read_int()
        shell = None
        holes = []
        for i in range(ring_ct):
            sz = self.read_int()
            ln = LinearRing(srid=self.srid)
            try:
                path_grow(ln._path, sz)
            except MemoryError:
                raise
            for i from 0 <= i < sz:
                xx = self.read_double()
                yy = self.read_double()
                if self.has_z:
                    zz = self.read_double()
                if self.has_m:
                    mm = self.read_double()
                path_set_coord(ln._path, i, xx, yy)
            ln._path.items = sz
            if i == 0:
                shell = ln
            else:
                holes.append( ln )
        return Polygon(shell = shell, holes = holes, srid=self.srid)


cdef class EWKBWriter(object):
    """Convert known geometries to Well Known Binary
    """
#    cdef int tp
#    cdef bint has_z
#    cdef bint has_m
#    cdef int srid
#    cdef object stream
#    cdef Geometry geometry

    def __init__(self, Geometry geometry, int srid = 0, object stream=None):
        self.stream = stream or StringIO()
        self.geometry = geometry
        self.srid = srid
        if self.srid < 0 or self.srid > 999999:
            self.srid = 0
        self.tp = self.geometry._geom_type
        self.stream.write('\x01')
        # We do not do has_z nor has_m currently
#        self.write_int(self.tp |
#            (0x80000000 if self.geometry.has_z else 0) |
#            (0x40000000 if self.geometry.has_m else 0) |
#            (0x20000000)) # we always supply srid
        self.write_int(self.tp |
            (0) |
            (0) |
            (0x20000000)) # we always supply srid
        self.write_int(self.srid)
        self.write_geometry()

    cdef write_geometry(self):
        if self.tp == 1:
            self.write_point()
        elif self.tp == 2:
            self.write_linestring()  
        elif self.tp == 3:
            self.write_polygon()
        else:
            raise NotImplementedError('unsupported geometry class <{0}>'
                .format(self.geometry.__class__.__name__))
    
    cdef write_int(self, value):
        self.stream.write(pack('<I', value))

    cdef write_double(self, value):
        self.stream.write(pack('<d', value))
    
    cdef inline void write_point(self):
        cdef Point pt = self.geometry
        self.write_double(pt._coord.x)
        self.write_double(pt._coord.y)
    
    cdef inline void write_linestring(self):
        cdef LineString ln = self.geometry
        self.write_int(ln._path.items)
        cdef int j
        for j from 0 <= j < ln._path.items:
            self.write_double(ln._path.coords[j].x)
            self.write_double(ln._path.coords[j].y)

    cdef inline void write_polygon(self):
        cdef int k, j
        cdef Polygon pl = self.geometry
        self.write_int(pl._surface.items)
        for k from 0 <= k < pl._surface.items:
            self.write_int(pl._surface.paths[k].items)
            for j from 0 <= j < pl._surface.paths[k].items:
                self.write_double(pl._surface.paths[k].coords[j].x)
                self.write_double(pl._surface.paths[k].coords[j].y)

    cpdef as_hex(self):
        return self.stream.getvalue().encode('hex')

cpdef loads(data, cursor=None):
    """Loads a geometry from *data*"""
    try:
        geom = EWKBReader(StringIO(a2b_hex(data))).read_geometry()
    except:
        raise ValueError(
            "Could not create geometry because of errors while reading input.")
    return geom

cpdef load(fp):
    """Load a geometry from an open file."""
    data = fp.read()
    return loads(data)

cpdef dumps(Geometry ob):
    """Dump a WKB representation of a geometry to a HEXEWKB string."""
    return EWKBWriter(ob, ob.srid).as_hex()

cpdef dump(Geometry ob, fp):
    """Dump a geometry as HEXEWKB string to an open file."""
    fp.write("{}".format(EWKBWriter(ob, ob.srid).as_hex()))
