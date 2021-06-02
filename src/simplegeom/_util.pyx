# cython: language_level=3, boundscheck=False, profile=False
"""
"""

__all__ = ["angle", "coincident"]

cdef double _PI2 = M_PI * 2.

cpdef double angle(Point a, Point b):
    cdef double angle_
    assert a._inited
    assert b._inited
    dx = b._coord.x - a._coord.x
    dy = b._coord.y - a._coord.y
    angle_ = atan2(dy, dx)
    while angle_ < 0:
        angle_ += _PI2
    return angle_

cpdef bint coincident(Point a, Point b):
    assert a._inited
    assert b._inited
    if a._coord.x == b._coord.x and a._coord.y == b._coord.y:
        return True
    else:
        return False
