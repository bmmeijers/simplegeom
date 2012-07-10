import logging
import psycopg2.extensions
from connection.connect import ConnectionFactory
import sys

log = logging.getLogger(__name__)
from wkb import loads

def register():
    """Find the correct OID and register the input/output function
     as psycopg2 extension type for automatic type conversion to happen.
    
    .. note::
        Should be called once
    """
    from connection.connect import ConnectionFactory
    factory = ConnectionFactory()
    connection = factory.connection()
    cursor = connection.cursor()
    cursor.execute("SELECT NULL::geometry")
    geom_oid = cursor.description[0][1]
    cursor.close()
    connection.close()
    log.debug("Registering Geometry Type (OID {}) for PostGIS".format(geom_oid))
    GEOMETRY = psycopg2.extensions.new_type((geom_oid, ), "GEOMETRY", loads)
    psycopg2.extensions.register_type(GEOMETRY)

def _test():
    from connection.stateful import irecordset, record
    register()
    
    print "point"
    pt, = record("SELECT '01010000200000000000000000000014400000000000001840'::geometry;")
    print pt

    print "point"
    for item, in irecordset("SELECT 'POINT (10 40)'::geometry;"):
        print str(item)

    print "linestring"
    for item, in irecordset("SELECT 'LINESTRING (10 40, 50 50)'::geometry;"):
        print str(item)
    
    print "polygon"
    for item, in irecordset("SELECT 'POLYGON ((10 40, 50 50, 0 100, 10 40))'::geometry;"):
        for ring in item:
            print ring

    print "polygon 2 rings, invalid"
    for item, in irecordset("""SELECT 'POLYGON ((10 40, 50 50, 0 100, 10 40),
    (10 40, 50 50, 0 100, 10 40))'::geometry;"""):
        for ring in item:
            print ring    

    print "multipoint"
    for item, in irecordset("SELECT 'MULTIPOINT (10 40, 40 30, 20 20, 30 10)'::geometry;"):
        for sub in item:
            print sub

    print "multipoint"
    for item, in irecordset("SELECT 'MULTIPOINT ((10 40), (40 30), (20 20), (30 10))'::geometry;"):
        for sub in item:
            print sub

    print "multilinestring"
    for item, in irecordset("SELECT 'MULTILINESTRING ((10 10, 20 20, 10 40), (40 40, 30 30, 40 20, 30 10))'::geometry;"):
        for sub in item:
            print sub 

    print "multipoly"
    for item, in irecordset("SELECT 'MULTIPOLYGON (((40 40, 20 45, 45 30, 40 40)), ((20 35, 45 20, 30 5, 10 10, 10 30, 20 35), (30 20, 20 25, 20 15, 30 20)))'::geometry;"):
        for sub in item:
            print sub

    print "collection"
    for item, in irecordset("SELECT 'GEOMETRYCOLLECTION(POINT(4 6),LINESTRING(4 6,7 10))'::geometry;"):
        for sub in item:
            print sub

    print "collection of collection + a point"
    for item in irecordset("SELECT 'GEOMETRYCOLLECTION(GEOMETRYCOLLECTION(POINT(4 6),LINESTRING(4 6,7 10)), POINT(0 0))'::geometry;"):
        for sub in item:
            print sub

#    for oid, item, in irecordset("SELECT oid, geometrie_vlak::geometry FROM top10nl LIMIT 100"):
#        print oid, item, item.envelope, item.area
#    for item, in irecordset("SELECT geometry::geometry FROM tp_top10nl_edge LIMIT 100"):
#        print item, item.envelope
#    for item, in irecordset("SELECT geometry::geometry FROM tp_top10nl_node LIMIT 100"):
#        print item, item.envelope

if __name__ == "__main__":
    _test()



#POINT ZM (1 1 5 60)
#POINT M (1 1 80)
#POINT EMPTY
#MULTIPOLYGON EMPTY
        
# MULTILINESTRING ((10 10, 20 20, 10 40), (40 40, 30 30, 40 20, 30 10))
# MULTIPOLYGON (((30 20, 10 40, 45 40, 30 20)), ((15 5, 40 10, 10 20, 5 10, 15 5)))
# MULTIPOLYGON (((40 40, 20 45, 45 30, 40 40)), ((20 35, 45 20, 30 5, 10 10, 10 30, 20 35), (30 20, 20 25, 20 15, 30 20)))
