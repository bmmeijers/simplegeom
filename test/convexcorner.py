from simplegeom.geometry import Polygon, LinearRing

# FIXME: make this method on LinearRing

def find_lr(ring):
    """Finds index of lowest right point in ring"""
    assert ring[0] == ring[-1]
    idx = 0
    lr = ring[idx]
    for i, pt in enumerate(ring[1:-1], start=1):
        print pt.x, pt.y
        if (pt.y < lr.y) or (pt.y == lr.y and pt.x > lr.x):
            lr = pt
            idx = i
    return idx

def ccw(ring, item):
    """Calculates cross product for point indicated by item in the ring
    
    Returns 1 if cross product > 0 (hence corner is ccw)
    Returns -1 if cross product < 0 (hence corner is cw)
    Returns 0 if cross product == 0 (hence corner is flat)
    """
    if item == 0:
        prev = -2
    else:
        prev = item - 1
    next = item + 1
    a, b, c = ring[prev], ring[item], ring[next]
    # FIXME:
    # make sure that location of a != b and b != c
    cross = a.x * b.y - a.y * b.x + a.y * c.x - a.x * c.y + b.x * c.y - c.x * b.y
    if cross > 0:
        return 1
    elif cross < 0:
        return -1
    else:
        return 0

if __name__ == "__main__":
    poly = Polygon(LinearRing([(11, -1), (10, 10), (0, 10), (0, 0), (10, 0), (11, -1)]))
    assert ccw(poly[0], find_lr(poly[0])) == 1
    
