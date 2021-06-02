from simplegeom.geometry import Point

if __name__ == "__main__":
    empty = Point()
    assert empty.is_empty
    assert empty.geom_type == "Point"
    
    pt = Point(1, 2)
    assert pt.x == 1
    assert pt.y == 2
    
    assert pt.area == 0.
    
    pt[0] = 5
    pt[1] = 6
    
    assert pt.x == 5
    assert pt.y == 6
    
    print( pt.wkb )
    assert str(pt.wkb) == str(b'01010000200000000000000000000014400000000000001840')
