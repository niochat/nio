Olm
===

An implementation of the Double Ratchet cryptographic ratchet described by
https://whispersystems.org/docs/specifications/doubleratchet/, written in C and
C++11 and exposed as a C API.

The specification of the Olm ratchet can be found in `<docs/olm.rst>`_.

This library also includes an implementation of the Megolm cryptographic
ratchet, as specified in `<docs/megolm.rst>`_.

Building
--------

To build olm as a shared library run either:

.. code:: bash

    cmake . -Bbuild
    cmake --build build

or:

.. code:: bash

    make

Using cmake is the preferred method for building the shared library; the
Makefile may be removed in the future.

To run the tests when using cmake, run:

.. code:: bash

    cd build/tests
    ctest .

To run the tests when using make, run:

.. code:: bash

    make test

To build the JavaScript bindings, install emscripten from http://kripken.github.io/emscripten-site/ and then run:

.. code:: bash

    make js

Note that if you run emscripten in a docker container, you need to pass through
the EMCC_CLOSURE_ARGS environment variable.

To build the android project for Android bindings, run:

.. code:: bash

    cd android
    ./gradlew clean assembleRelease

To build the Xcode workspace for Objective-C bindings, run:

.. code:: bash

    cd xcode
    pod install
    open OLMKit.xcworkspace

To build the Python bindings, first build olm as a shared library as above, and
then run:

.. code:: bash

    cd python
    make

to make both the Python 2 and Python 3 bindings.  To make only one version, use
``make olm-python2`` or ``make olm-python3`` instead of just ``make``.

To build olm as a static library (which still needs libstdc++ dynamically) run
either:

.. code:: bash

    cmake . -Bbuild -DBUILD_SHARED_LIBS=NO
    cmake --build build

or

.. code:: bash

    make static

The library can also be used as a dependency with CMake using:

.. code:: cmake

    find_package(Olm::Olm REQUIRED)
    target_link_libraries(my_exe Olm::Olm)


Release process
---------------

First: bump version numbers in ``common.mk``, ``CMakeLists.txt``,
``javascript/package.json``, ``python/olm/__version__.py``, ``OLMKit.podspec``,
and ``android/olm-sdk/build.gradle`` (``versionCode``, ``versionName`` and
``version``).

Also, ensure the changelog is up to date, and that everyting is committed to
git.

It's probably sensible to do the above on a release branch (``release-vx.y.z``
by convention), and merge back to master once the release is complete.

.. code:: bash

    make clean

    # build and test C library
    make test

    # build and test JS wrapper
    make js
    (cd javascript && npm run test)
    npm pack javascript

    VERSION=x.y.z
    scp olm-$VERSION.tgz packages@ares.matrix.org:packages/npm/olm/
    git tag $VERSION -s
    git push --tags

    # OLMKit CocoaPod release
    # Make sure the version OLMKit.podspec is the same as the git tag
    # (this must be checked before git tagging)
    pod spec lint OLMKit.podspec --use-libraries --allow-warnings
    pod trunk push OLMKit.podspec --use-libraries --allow-warnings
    # Check the pod has been successully published with:
    pod search OLMKit


Design
------

Olm is designed to be easy port to different platforms and to be easy
to write bindings for.

It was originally implemented in C++, with a plain-C layer providing the public
API. As development has progressed, it has become clear that C++ gives little
advantage, and new functionality is being added in C, with C++ parts being
rewritten as the need ariases.

Error Handling
~~~~~~~~~~~~~~

All C functions in the API for olm return ``olm_error()`` on error.
This makes it easy to check for error conditions within the language bindings.

Random Numbers
~~~~~~~~~~~~~~

Olm doesn't generate random numbers itself. Instead the caller must
provide the random data. This makes it easier to port the library to different
platforms since the caller can use whatever cryptographic random number
generator their platform provides.

Memory
~~~~~~

Olm avoids calling malloc or allocating memory on the heap itself.
Instead the library calculates how much memory will be needed to hold the
output and the caller supplies a buffer of the appropriate size.

Output Encoding
~~~~~~~~~~~~~~~

Binary output is encoded as base64 so that languages that prefer unicode
strings will find it easier to handle the output.

Dependencies
~~~~~~~~~~~~

Olm uses pure C implementations of the cryptographic primitives used by
the ratchet. While this decreases the performance it makes it much easier
to compile the library for different architectures.

Contributing
------------
Please see `<CONTRIBUTING.rst>`_ when making contributions to the library.

Security assessment
-------------------

Olm 1.3.0 was independently assessed by NCC Group's Cryptography Services
Practive in September 2016 to check for security issues: you can read all
about it at
https://www.nccgroup.trust/us/our-research/matrix-olm-cryptographic-review/
and https://matrix.org/blog/2016/11/21/matrixs-olm-end-to-end-encryption-security-assessment-released-and-implemented-cross-platform-on-riot-at-last/

Bug reports
-----------
Please file bug reports at https://github.com/matrix-org/olm/issues

What's an olm?
--------------

It's a really cool species of European troglodytic salamander.
http://www.postojnska-jama.eu/en/come-and-visit-us/vivarium-proteus/

Legal Notice
------------

The software may be subject to the U.S. export control laws and regulations
and by downloading the software the user certifies that he/she/it is
authorized to do so in accordance with those export control laws and
regulations.
