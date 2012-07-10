from simplegeo.geometry import LineString
    
if __name__ == "__main__":
    empty = LineString()
    assert empty.is_empty
    print empty
    a = LineString([(0,0), (1,2)])
    b = LineString([(0,0), (1,2)])
    print a.length
    assert a == b
    lnz = LineString([(0,0,0), (1,2,3)])
    print lnz
    lnm = LineString([(0,0,0), (1,2,3)])
    assert lnz == lnm
    print lnm[-1]
    ln = LineString([(0,0,0,4), (1,2,3,4)])
    print ln
    print ln[1]
    