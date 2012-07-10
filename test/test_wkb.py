from simplegeo.geometry import Point, LineString, Polygon, LinearRing
from simplegeo.wkb import dumps, loads, dump
from cStringIO import StringIO

def _test():


    print dumps(Point(1, 2))
    ln =  LineString([(0, 0, 3), (10, 10, 3)])
    print dumps(ln)
    print dumps(ln)
    fh = StringIO()
    dump(ln, fh)
    print fh.getvalue()
    
    ln =  LineString([(0, 0), (10, 10)])
    print dumps(ln)
    print str(loads(dumps(ln))), str(ln)
    print str(loads(dumps(ln))) == str(ln)

    print loads("010100006040710000000000000000F03F00000000000000400000000000001040")
    print loads("01020000A04071000002000000000000000000000000000000000000000000000000000840000000000000000000000000000008400000000000002440")
    print loads("01020000A00000000002000000000000000000000000000000000000000000000000000840000000000000000000000000000008400000000000002440")
    print loads("01020000A00000000002000000000000000000000000000000000000000000000000000840000000000000000000000000000008400000000000002440")
    print dumps(Polygon())
    print loads("01030000200000000000000000")
    print loads(dumps(Polygon()))

    lr = LinearRing([(0,0), (10, 0), (5, 10), (0, 0)])
    print lr
    
    lr = LinearRing([(0,0, 10), (10, 0, 2), (5, 10, 2), (0, 0, 10)])
    print lr
    
    print loads(dumps(Polygon(lr, [lr])))

if __name__ == "__main__":
    _test()