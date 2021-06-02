'''
Created on Jul 6, 2012

@author: martijn
'''
from simplegeom.geometry import Envelope

def _test():
    ev = Envelope()
    assert ev.is_empty
    ev = Envelope(xmin = 0, ymin = 2, xmax = 10, ymax = 11)
    assert ev.geom_type == "Envelope"
    assert ev.xmin == 0
    assert ev.ymin == 2
    assert ev.xmax == 10
    assert ev.ymax == 11
    
    other = Envelope(xmin=105, ymin = 105, xmax=110, ymax=115)
    ev.enlarge_by(other)
    assert ev.xmin == 0
    assert ev.ymin == 2
    assert ev.xmax == 110
    assert ev.ymax == 115
    
    ev = Envelope(xmin = 0, ymin = 2, xmax = 10, ymax = 11)
    other = Envelope(xmin=-110, ymin = -115, xmax=-100, ymax=-100)
    ev.enlarge_by(other)
    assert ev.xmin == -110
    assert ev.ymin == -115
    assert ev.xmax == 10
    assert ev.ymax == 11
    
    print(ev)
    
if __name__ == "__main__":
    _test()