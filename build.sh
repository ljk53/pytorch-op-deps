#!/bin/bash
##############################################################################
# Build LLVM code analyzer and analyze torch code dependency.
##############################################################################

set -ex

ROOT="$( cd "$(dirname "$0")" ; pwd -P)"
PYTORCH_ROOT="${PYTORCH_ROOT:-$ROOT/pytorch}"
BUILD_ROOT="${BUILD_ROOT:-${ROOT}/build}"
WORK_DIR="${BUILD_ROOT}/work"

# Clang/LLVM path
export LLVM_DIR="${LLVM_DIR:-/usr/lib/llvm-8}"
export CC="${LLVM_DIR}/bin/clang"
export CXX="${LLVM_DIR}/bin/clang++"
EXTRA_ANALYZER_FLAGS=$@

mkdir -p "${BUILD_ROOT}"
mkdir -p "${WORK_DIR}"
cd "${BUILD_ROOT}"

install_dependencies() {
  # Follow PyTorch local build instruction: https://github.com/pytorch/pytorch#from-source
  echo "Install conda dependencies..."
  conda install numpy ninja pyyaml mkl mkl-include setuptools cmake cffi
}

checkout_pytorch() {
  if [ ! -d "$PYTORCH_ROOT" ]; then
    echo "PyTorch src folder doesn't exist: $PYTORCH_ROOT. Downloading..."
    echo "You can use existing PyTorch src by 'export PYTORCH_ROOT=<path>'"
    mkdir -p "$PYTORCH_ROOT"
    git clone --recursive https://github.com/pytorch/pytorch "$PYTORCH_ROOT"
  else
    echo "Using PyTorch source code at: $PYTORCH_ROOT"
  fi
}

build_analyzer() {
  cmake "${ROOT}" -DCMAKE_BUILD_TYPE=Release

  if [ -z "${MAX_JOBS}" ]; then
    if [ "$(uname)" == 'Darwin' ]; then
      MAX_JOBS=$(sysctl -n hw.ncpu)
    else
      MAX_JOBS=$(nproc)
    fi
  fi

  make "-j${MAX_JOBS}"
}

build_torch_mobile() {
  TORCH_BUILD_ROOT="${BUILD_ROOT}/build_mobile"
  TORCH_INSTALL_PREFIX="${TORCH_BUILD_ROOT}/install"

  BUILD_ROOT="${TORCH_BUILD_ROOT}" "${PYTORCH_ROOT}/scripts/build_mobile.sh" \
    -DCMAKE_CXX_FLAGS="-S -emit-llvm -DSTRIP_ERROR_MESSAGES" \
    ${MOBILE_BUILD_FLAGS}
}

build_test_project() {
  TEST_SRC_ROOT="${ROOT}/test"
  TEST_BUILD_ROOT="${BUILD_ROOT}/build_test"
  TEST_INSTALL_PREFIX="${TEST_BUILD_ROOT}/install"

  BUILD_ROOT="${TEST_BUILD_ROOT}" \
    TORCH_INSTALL_PREFIX="${TORCH_INSTALL_PREFIX}" \
    "${TEST_SRC_ROOT}/build.sh" \
    -DCMAKE_CXX_FLAGS="-S -emit-llvm -DSTRIP_ERROR_MESSAGES"
}

call_analyzer() {
  ANALYZER_BIN="${BUILD_ROOT}/analyzer" \
    INPUT="${INPUT}" OUTPUT="${OUTPUT}" \
    EXTRA_ANALYZER_FLAGS="${EXTRA_ANALYZER_FLAGS}" \
    "${ROOT}/run_analyzer.sh"
}

analyze_torch_mobile() {
  INPUT="${WORK_DIR}/torch.ll"
  OUTPUT="${WORK_DIR}/torch_op_deps.yaml"

  if [ ! -f "${INPUT}" ]; then
    # Link libtorch into a single module
    # TODO: invoke llvm-link from cmake directly to avoid this hack.
    # TODO: include *.c.o when there is meaningful fan-out from pure-c code.
    "${LLVM_DIR}/bin/llvm-link" -S \
    $(find "${TORCH_BUILD_ROOT}" -name '*.cpp.o' -o -name '*.cc.o') \
    -o "${INPUT}"
  fi

  # Analyze dependency
  call_analyzer
}

print_output_file_path() {
  echo "Deployed file at: ${OUTPUT}"
}

analyze_test_project() {
  INPUT="${WORK_DIR}/test.ll"
  OUTPUT="${WORK_DIR}/test_result.yaml"

  # Link into a single module (only need c10 and OpLib srcs)
  # TODO: invoke llvm-link from cmake directly to avoid this hack.
  "${LLVM_DIR}/bin/llvm-link" -S \
  $(find "${TORCH_BUILD_ROOT}" -path '*/c10*' \( -name '*.cpp.o' -o -name '*.cc.o' \)) \
  $(find "${TEST_BUILD_ROOT}" -path '*/OpLib*' \( -name '*.cpp.o' -o -name '*.cc.o' \)) \
  -o "${INPUT}"

  # Analyze dependency
  call_analyzer
}

check_test_result() {
  if cmp -s "${OUTPUT}" "${TEST_SRC_ROOT}/expected_deps.yaml"; then
    echo "Test result is the same as expected."
  else
    echo "Test result is DIFFERENT from expected!"
    diff -u "${TEST_SRC_ROOT}/expected_deps.yaml" "${OUTPUT}"
    exit 1
  fi
}

# install_dependencies
checkout_pytorch
build_analyzer

if [ -n "${ANALYZE_TORCH}" ]; then
  build_torch_mobile
  analyze_torch_mobile
  if [ -n "${DEPLOY}" ]; then
    print_output_file_path
  fi
fi

if [ -n "${ANALYZE_TEST}" ]; then
  build_torch_mobile
  build_test_project
  analyze_test_project
  check_test_result
fi
