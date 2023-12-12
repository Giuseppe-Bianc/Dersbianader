include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(Dersbianader_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(Dersbianader_setup_options)
  option(Dersbianader_ENABLE_HARDENING "Enable hardening" ON)
  option(Dersbianader_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    Dersbianader_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    Dersbianader_ENABLE_HARDENING
    OFF)

  Dersbianader_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR Dersbianader_PACKAGING_MAINTAINER_MODE)
    option(Dersbianader_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(Dersbianader_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(Dersbianader_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Dersbianader_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Dersbianader_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Dersbianader_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(Dersbianader_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(Dersbianader_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Dersbianader_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(Dersbianader_ENABLE_IPO "Enable IPO/LTO" ON)
    option(Dersbianader_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(Dersbianader_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(Dersbianader_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(Dersbianader_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(Dersbianader_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(Dersbianader_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(Dersbianader_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(Dersbianader_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(Dersbianader_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(Dersbianader_ENABLE_PCH "Enable precompiled headers" OFF)
    option(Dersbianader_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      Dersbianader_ENABLE_IPO
      Dersbianader_WARNINGS_AS_ERRORS
      Dersbianader_ENABLE_USER_LINKER
      Dersbianader_ENABLE_SANITIZER_ADDRESS
      Dersbianader_ENABLE_SANITIZER_LEAK
      Dersbianader_ENABLE_SANITIZER_UNDEFINED
      Dersbianader_ENABLE_SANITIZER_THREAD
      Dersbianader_ENABLE_SANITIZER_MEMORY
      Dersbianader_ENABLE_UNITY_BUILD
      Dersbianader_ENABLE_CLANG_TIDY
      Dersbianader_ENABLE_CPPCHECK
      Dersbianader_ENABLE_COVERAGE
      Dersbianader_ENABLE_PCH
      Dersbianader_ENABLE_CACHE)
  endif()

  Dersbianader_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (Dersbianader_ENABLE_SANITIZER_ADDRESS OR Dersbianader_ENABLE_SANITIZER_THREAD OR Dersbianader_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(Dersbianader_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(Dersbianader_global_options)
  if(Dersbianader_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    Dersbianader_enable_ipo()
  endif()

  Dersbianader_supports_sanitizers()

  if(Dersbianader_ENABLE_HARDENING AND Dersbianader_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Dersbianader_ENABLE_SANITIZER_UNDEFINED
       OR Dersbianader_ENABLE_SANITIZER_ADDRESS
       OR Dersbianader_ENABLE_SANITIZER_THREAD
       OR Dersbianader_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${Dersbianader_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${Dersbianader_ENABLE_SANITIZER_UNDEFINED}")
    Dersbianader_enable_hardening(Dersbianader_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(Dersbianader_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(Dersbianader_warnings INTERFACE)
  add_library(Dersbianader_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  Dersbianader_set_project_warnings(
    Dersbianader_warnings
    ${Dersbianader_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(Dersbianader_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(Dersbianader_options)
  endif()

  include(cmake/Sanitizers.cmake)
  Dersbianader_enable_sanitizers(
    Dersbianader_options
    ${Dersbianader_ENABLE_SANITIZER_ADDRESS}
    ${Dersbianader_ENABLE_SANITIZER_LEAK}
    ${Dersbianader_ENABLE_SANITIZER_UNDEFINED}
    ${Dersbianader_ENABLE_SANITIZER_THREAD}
    ${Dersbianader_ENABLE_SANITIZER_MEMORY})

  set_target_properties(Dersbianader_options PROPERTIES UNITY_BUILD ${Dersbianader_ENABLE_UNITY_BUILD})

  if(Dersbianader_ENABLE_PCH)
    target_precompile_headers(
      Dersbianader_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(Dersbianader_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    Dersbianader_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(Dersbianader_ENABLE_CLANG_TIDY)
    Dersbianader_enable_clang_tidy(Dersbianader_options ${Dersbianader_WARNINGS_AS_ERRORS})
  endif()

  if(Dersbianader_ENABLE_CPPCHECK)
    Dersbianader_enable_cppcheck(${Dersbianader_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(Dersbianader_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    Dersbianader_enable_coverage(Dersbianader_options)
  endif()

  if(Dersbianader_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(Dersbianader_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(Dersbianader_ENABLE_HARDENING AND NOT Dersbianader_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR Dersbianader_ENABLE_SANITIZER_UNDEFINED
       OR Dersbianader_ENABLE_SANITIZER_ADDRESS
       OR Dersbianader_ENABLE_SANITIZER_THREAD
       OR Dersbianader_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    Dersbianader_enable_hardening(Dersbianader_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
