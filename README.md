This is a clone of the deprecated LLVM-based static analyzer from the PyTorch repo,
which can be used to produce the PyTorch operator dependency graph.

See original PRs:
* LLVM pass: https://github.com/pytorch/pytorch/pull/29550
* Test project: https://github.com/pytorch/pytorch/pull/29716
* Bash driver: https://github.com/pytorch/pytorch/pull/29718

Example usage:

1. Analyze torch and generate yaml file of op dependency transitive closure:
```
LLVM_DIR=/usr/lib/llvm-8 \
ANALYZE_TORCH=1 ./build.sh
```

2. Analyze test project and compare with expected result:
```
LLVM_DIR=/usr/lib/llvm-8 \
ANALYZE_TEST=1 ./build.sh
```

3. Analyze torch and generate yaml file of op dependency with debug path:
```
LLVM_DIR=/usr/lib/llvm-8 \
ANALYZE_TORCH=1 ./build.sh -debug_path=true
```
