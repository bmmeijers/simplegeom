from _geom2d cimport Point
from libc.math cimport atan2, M_PI

cpdef double angle(Point a, Point b)
cpdef bint coincident(Point a, Point b)
