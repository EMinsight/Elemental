# This will handle the logic surrounding BLAS/LAPACK
#
# Options that affect the choices made here:
#
#   BLA_VENDOR -- If set, use this value and ignore all other options.
#   Hydrogen_USE_MKL -- If set, look for MKL installations.
#   Hydrogen_USE_OpenBLAS -- If set, look for OpenBLAS implementation.
#   Hydrogen_BUILD_OpenBLAS_IF_NOTFOUND -- If set, download and build
#       OpenBLAS from source.
#   Hydrogen_USE_ACCELERATE -- If set, skip other searches in favor of
#       Apple's accelerate framework
#   Hydrogen_USE_GENERIC_LAPACK -- If set, skip other searches in
#       favor of a generic LAPACK library
#   Hydrogen_GENERAL_LAPACK_FALLBACK -- If set and no other LAPACK
#       library has been found, this will call "find_package(LAPACK)"
#       with all influential variables to that module cleared.
#
# In addition to the variables set by the standard FindBLAS and
# FindLAPACK modules, this module also defines the IMPORTED library
# "LAPACK::lapack" and might output the variable
#
#   HYDROGEN_BLAS_SUFFIX -- Only defined if BLAS requires a suffix, usually "_".
#   HYDROGEN_LAPACK_SUFFIX -- Only defined if LAPACK requires a suffix, usually "_".
#
# This will prioritize BLA_VENDOR, MKL, OpenBLAS, Apple, Generic, and
# setting multiple options above will cause a short-circuit if any are
# found in that order.
#
# Ultimately, this boils down to repeated calls to
# "find_package(LAPACK)" with changes to the environment. These calls,
# of course, can be avoided if LAPACK_LIBRARIES and related variables
# are set on the command line.


# Check straight-away if BLA_VENDOR is already set
if (BLA_VENDOR)
  find_package(LAPACK QUIET)
endif (BLA_VENDOR)

# Check for MKL
# TODO (trb 10.26.2017): add LP model support if 64bit indices
if (${PROJECT_NAME}_USE_MKL AND NOT LAPACK_FOUND)
  set(BLA_VENDOR "Intel10_64")
  find_package(LAPACK QUIET)
endif (${PROJECT_NAME}_USE_MKL AND NOT LAPACK_FOUND)

# Check for OpenBLAS
if (${PROJECT_NAME}_USE_OpenBLAS AND NOT LAPACK_FOUND)
  set(BLA_VENDOR "OpenBLAS")
  find_package(LAPACK QUIET)

  # Build OpenBLAS if requested
  if (NOT LAPACK_FOUND AND ${PACKAGE_NAME}_BUILD_OpenBLAS_IF_NOTFOUND)
    include(BuildOpenBLAS)
  endif()
endif (${PROJECT_NAME}_USE_OpenBLAS AND NOT LAPACK_FOUND)

# Check for Accelerate
if (APPLE AND ${PROJECT_NAME}_USE_ACCELERATE AND NOT LAPACK_FOUND)
  set(BLA_VENDOR "Apple")
  find_package(LAPACK QUIET)
endif (APPLE AND ${PROJECT_NAME}_USE_ACCELERATE AND NOT LAPACK_FOUND)

# Check for a generic lapack build
if (${PROJECT_NAME}_USE_GENERIC_LAPACK AND NOT LAPACK_FOUND)
  set(BLA_VENDOR "Generic")
  find_package(LAPACK QUIET)
endif (${PROJECT_NAME}_USE_GENERIC_LAPACK AND NOT LAPACK_FOUND)

# Check for a fallback if requested
if (${PROJECT_NAME}_GENERAL_LAPACK_FALLBACK AND NOT LAPACK_FOUND)
  set(BLA_VENDOR "All")
  find_package(LAPACK QUIET)
endif (${PROJECT_NAME}_GENERAL_LAPACK_FALLBACK AND NOT LAPACK_FOUND)

# Wrap-up
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(HydrogenLAPACK
  DEFAULT_MSG
  LAPACK_FOUND LAPACK_LIBRARIES)

if (LAPACK_FOUND)
  message(STATUS "Found LAPACK: ${LAPACK_LIBRARIES}")
else ()
  message(FATAL_ERROR "No LAPACK library found!")
endif ()

# Define the imported target
if (NOT TARGET LAPACK::lapack)
  add_library(LAPACK::lapack INTERFACE IMPORTED)

  # This only uses the LAPACK_* variables. LAPACK_LIBRARIES _should_
  # include BLAS_LIBRARIES and LAPACK_LINKER_FLAGS _should_ include
  # BLAS_LINKER_FLAGS. If it is ever discovered that this isn't true,
  # it can be fixed.
  if (LAPACK_LINKER_FLAGS)
    if (UNIX)# Or we could force CMake 3.9 and use NATIVE_COMMAND!
      separate_arguments(__link_flags UNIX_COMMAND "${LAPACK_LINKER_FLAGS}")
    else ()
      separate_arguments(__link_flags WINDOWS_COMMAND "${LAPACK_LINKER_FLAGS}")
    endif ()
  endif ()
  list(APPEND __link_flags "${LAPACK_LIBRARIES}")

  set_property(TARGET LAPACK::lapack PROPERTY
    INTERFACE_LINK_LIBRARIES "${__link_flags}")

endif (NOT TARGET LAPACK::lapack)

# Detect the suffix
include(CheckFunctionExists)


set(CMAKE_REQUIRED_LIBRARIES "${BLAS_LINKER_FLAGS}" "${BLAS_LIBRARIES}")
check_function_exists(dgemm BLAS_NO_USE_UNDERSCORE)
check_function_exists(dgemm_ BLAS_USE_UNDERSCORE)

set(CMAKE_REQUIRED_LIBRARIES "${LAPACK_LINKER_FLAGS}" "${LAPACK_LIBRARIES}")
check_function_exists(dgetrs LAPACK_NO_USE_UNDERSCORE)
check_function_exists(dgetrs_ LAPACK_USE_UNDERSCORE)

# If both dgemm and dgemm_ are found, don't use the suffix
if (BLAS_NO_USE_UNDERSCORE)
  unset(${UPPER_PROJECT_NAME}_BLAS_SUFFIX)
  message(STATUS "Using BLAS with no symbol mangling.")
elseif (BLAS_USE_UNDERSCORE)
  set(${UPPER_PROJECT_NAME}_BLAS_SUFFIX "_")
  message(STATUS "Using BLAS with trailing underscore.")
else ()
  message(FATAL_ERROR "Could not determine BLAS suffix!")
endif ()

if (LAPACK_NO_USE_UNDERSCORE)
  unset(${UPPER_PROJECT_NAME}_LAPACK_SUFFIX)
  message(STATUS "Using LAPACK with no symbol mangling.")
elseif (LAPACK_USE_UNDERSCORE)
  set(${UPPER_PROJECT_NAME}_LAPACK_SUFFIX "_")
  message(STATUS "Using LAPACK with trailing underscore.")
else ()
  message(FATAL_ERROR "Could not determine LAPACK suffix!")
endif ()

