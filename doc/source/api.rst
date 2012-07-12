API
=====================================

The Application Programming Interface of *simplegeom*.

Inheritance of classes
-----------------------
All geometry classes inherit from the **abstract** Geometry class, as follows:

.. inheritance-diagram:: 
	simplegeom.geometry.Geometry
	simplegeom.geometry.Point
	simplegeom.geometry.LineString
	simplegeom.geometry.LinearRing
	simplegeom.geometry.Polygon
	simplegeom.geometry.Envelope

Simple Feature Geometry
-----------------------

.. automodule:: simplegeom.geometry
   :members:
   :inherited-members:
   :show-inheritance:

Input / Output
-----------------------

Well Known Binary
^^^^^^^^^^^^^^^^^^^^^^^

.. automodule:: simplegeom.wkb
   :members:

Well Known Text
^^^^^^^^^^^^^^^^^^^^^^^

.. automodule:: simplegeom.wkt
   :members:

PostGIS / Psycopg2
-----------------------

.. automodule:: simplegeom.postgis
   :members:
