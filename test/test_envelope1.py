from simplegeom.geometry import Envelope, LineString
import unittest

class testSegfault(unittest.TestCase):
    
    """Test for segfault when enlarge_by is given None as argument"""

    def test_segfault(self):
        e = Envelope(0, 0, 10, 10)
        self.assertRaises(TypeError, e.enlarge_by, None)

    def test_enlarge_by_unknown_type(self):
        e = Envelope(0, 0, 10, 10)
        ln = LineString([(0,0), (20,20)])
        self.assertRaises(TypeError, e.enlarge_by, ln)

if __name__ == '__main__':
    unittest.main()
