API
=====================================

The Application Programming Interface of *simplegeom*.

Inheritance of classes
-----------------------
All geometry classes inherit from the **abstract** Geometry class, as follows:

.. inheritance-diagram:: 
	simplegeo.geometry.Geometry
	simplegeo.geometry.Point
	simplegeo.geometry.LineString
	simplegeo.geometry.LinearRing
	simplegeo.geometry.Polygon
	simplegeo.geometry.Envelope

Simple Feature Geometry
-----------------------

.. automodule:: simplegeo.geometry
   :members:
   :inherited-members:
   :show-inheritance:

Input / Output
-----------------------

Well Known Binary
^^^^^^^^^^^^^^^^^^^^^^^

.. automodule:: simplegeo.wkb
   :members:

Well Known Text
^^^^^^^^^^^^^^^^^^^^^^^

.. automodule:: simplegeo.wkt
   :members:

PostGIS / Psycopg2
-----------------------

.. automodule:: simplegeo.postgis
   :members:
