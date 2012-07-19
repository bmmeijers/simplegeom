import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "fake_pyrex"))
from Cython.Distutils import build_ext
from setuptools import setup, Extension

# TODO: Read http://infinitemonkeycorps.net/docs/pph/
# it has useful tips on getting a package out in a versioned way

def get_version():
    """
    Gets the version number. Pulls it from the source files rather than
    duplicating it.
    
    """
    # we read the file instead of importing it as root sometimes does not
    # have the cwd as part of the PYTHONPATH
    fn = os.path.join(os.path.dirname(__file__), 'src', 'simplegeom', '__init__.py')
    try:
        lines = open(fn, 'r').readlines()
    except IOError:
        raise RuntimeError("Could not determine version number"
                           "(%s not there)" % (fn))
    version = None
    for l in lines:
        # include the ' =' as __version__ might be a part of __all__
        if l.startswith('__version__ =', ):
            version = eval(l[13:])
            break
    if version is None:
        raise RuntimeError("Could not determine version number: "
                           "'__version__ =' string not found")
    return version


setup(
    name = "simplegeom",
    version = get_version(),
    author = "Martijn Meijers",
    author_email = "b dot m dot meijers at tudelft dot nl",
    license = "MIT license",
    description = "",
    url = "",
    package_dir = {'':'src'},
    cmdclass = {'build_ext': build_ext},
    packages=['simplegeom'], 
    ext_modules = [
        Extension("simplegeom._geom2d", 
            sources = ["src/simplegeom/_geom2d.pyx",],
            extra_compile_args=[],
            extra_link_args=[],),
        Extension("simplegeom._wkb", 
            sources = ["src/simplegeom/_wkb.pyx",],
            extra_compile_args=[],
            extra_link_args=[],),
        Extension("simplegeom._wkt", 
            sources = ["src/simplegeom/_wkt.pyx",],
            extra_compile_args=[],
            extra_link_args=[],),
        Extension("simplegeom._util", 
            sources = ["src/simplegeom/_util.pyx",],
            extra_compile_args=[],
            extra_link_args=[],),
    ],
    classifiers = [
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Intended Audience :: Information Technology",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: Python",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Cython",
        "Topic :: Software Development :: Libraries",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
)