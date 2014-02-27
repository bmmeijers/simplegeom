from simplegeom.geometry import Point, LineString, LinearRing, Polygon
from cPickle import dumps, loads
import unittest


class testPickleSupport(unittest.TestCase):

    """Test pickling support of the classes"""

    def test_pt(self):
        pt = Point(0, 0)
        assert loads(dumps(pt)) == pt

    def test_line(self):
        line = LineString([Point(0, 0), Point(10, 0)])
        assert loads(dumps(line)) == line

    def test_linear(self):
        line = LinearRing(
            [Point(0, 0), Point(10, 0), Point(5, 5), Point(0, 0)])
        assert loads(dumps(line)) == line

    def test_poly(self):
        poly = Polygon(
            LinearRing([Point(0, 0), Point(10, 0), Point(9, 1), Point(5, 5), Point(0, 0)]))
        assert loads(dumps(poly)) == poly

if __name__ == '__main__':
    unittest.main()
