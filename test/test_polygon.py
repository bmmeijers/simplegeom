from simplegeo.geometry import LinearRing, Polygon, Point

def _test():
    poly = Polygon()
    assert poly.wkt == "POLYGON EMPTY"

    lr = LinearRing([(0, 0), (12, 0), (5, 10), (0, 0)])
    print lr
    poly = Polygon(lr)
    print poly
    print poly.envelope
    assert poly.geom_type == "Polygon"

    lr0 = LinearRing([(0,0, 10), (10, 0, 2), (5, 10, 2), (0, 0, 10)])
    lr1 = LinearRing([(0,0, 10), (10, 0, 2), (5, 10, 2), (0, 0, 10)])
    lr2 = LinearRing([(0,0, 10), (10, 0, 2), (5, 10, 2), (0, 0, 10)])

    assert lr0.geom_type == "LinearRing"
    assert lr0 == lr1
    assert lr0 == lr2
    
    lri = LinearRing([(100, 0, 10), (10, 0, 2), (5, 10, 2), (100, 0, 10)])
    try:
        print lri.area
    except NotImplementedError:
        pass
    print lri.signed_area()
    poly = Polygon(lr, [lri])
    print poly.envelope
    
    try:
        print poly.area
    except NotImplementedError:
        pass
    
    lr = LinearRing([(0, 0), (10, 0), (10, 10), (0, 0)])
    print lr
    assert lr.signed_area() == 50.
    poly = Polygon(lr)
    assert poly.representative_point() == Point(7.5, 5.0)
    
    lr = LinearRing([(0, 0), (10, 0), (10, 10), (0,10), (0, 0)])
    print lr
    assert lr.signed_area() == 100.
    
    lr = LinearRing([(0, 0), (10, 0), (5, 10), (0, 0)])
    assert lr.signed_area() == +50.
    assert lr.is_ccw
    lr.reverse()
    assert lr.signed_area() == -50.
    assert not lr.is_ccw
    
    print poly.wkb
    
    lr = LinearRing([(0,0), (10, 0), (10,10), (0,0)])
    assert lr.signed_area() == 50.
    lr = LinearRing([(0,0), (10, 0), (10,10), (0,10), (0,0)])
    assert lr.signed_area() == 100.
    lr.reverse()
    assert lr.signed_area() == -100.

    
#    >>> ln = geom_from_text("LINESTRING(80798.481 449486.894, 80803.21625 449477.388, 80807.9515 449467.882, 80817.422 449448.87, 80824.52575 449435.62775, 80831.6295 449422.3855, 80838.73325 449409.14325, 80845.837 449395.901, 80852.94075 449382.65875, 80860.0445 449369.4165, 80867.14825 449356.17425, 80870.700125 449349.553125, 80874.252 449342.932, 80877.41 449337.058, 80880.596 449331.133, 80882.092 449331.998, 80884.255 449333.25, 80879.96375 449341.435875, 80875.6725 449349.62175, 80871.38125 449357.807625, 80867.09 449365.9935, 80862.79875 449374.179375, 80858.5075 449382.36525, 80854.21625 449390.551125, 80849.925 449398.737, 80841.627875 449414.473125, 80837.4793125 449422.341188, 80833.33075 449430.20925, 80829.1821875 449438.077312, 80825.033625 449445.945375, 80820.8850625 449453.813438, 80816.7365 449461.6815, 80812.5879375 449469.549562, 80808.439375 449477.417625, 80804.2908125 449485.285688, 80800.14225 449493.15375, 80795.9936875 449501.021812, 80791.845125 449508.889875, 80787.6965625 449516.757938, 80783.548 449524.626, 80781.657 449523.856, 80779.537 449522.992, 80784.273 449513.9675, 80789.009 449504.943, 80793.745 449495.9185, 80798.481 449486.894)")
#    >>> from brep.util import signed_area
#    >>> signed_area(ln)
#    1030.1212365749525

    
if __name__ == "__main__":
    _test()