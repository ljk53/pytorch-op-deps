# What is this?

This is a clone of the deprecated LLVM-based static analyzer from the PyTorch repo, which can be used to produce the PyTorch operator dependency graph.

# Where to download the op dependency graph?

GitHub Actions CI job will automatically generate and upload the dependency graph to the [Releases](https://github.com/ljk53/pytorch-op-deps/releases) page.

# How to read the graph?

* In the output yaml file, it lists all the ops that an op might call. For example, the following section shows that `quantized::add` might call `aten::_empty_affine_quantized` and etc.

```
- name: quantized::add
  depends:
  - name: aten::_empty_affine_quantized
  - name: aten::as_strided_
  - name: aten::contiguous
  - name: aten::copy_
...
```

* If you turn on the debug mode, it will also show why op A calls op B. For example, the following section shows a call path between `quantized::add` and `aten::_empty_affine_quantized`.

```
- name: quantized::add
  depends:
  - name: aten::_empty_affine_quantized
    path:
    - quantized::add
    - at::Tensor at::native::(anonymous namespace)::qadd<false>(at::Tensor, at::Tensor, double, long)
    - at::_empty_affine_quantized(c10::ArrayRef<long>, c10::TensorOptions, double, long, c10::optional<c10::MemoryFormat>)
    - at::_ops::_empty_affine_quantized::call(c10::ArrayRef<long>, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, double, long, c10::optional<c10::MemoryFormat>)
    - at::_ops::create__empty_affine_quantized_typed_handle()
    - aten::_empty_affine_quantized
```

* It also includes a `__ROOT__` section at the beginning, which shows operators that might be called by the runtime directly. For example, the following snippet shows why `torch::jit::Unpickler::readInstruction` might call `aten::_empty_affine_quantized`.

```
- name: __ROOT__
  depends:
  - name: aten::_empty_affine_quantized
    path:
    - __ROOT__
    - torch::jit::Unpickler::readInstruction()
    - at::_empty_affine_quantized(c10::ArrayRef<long>, c10::TensorOptions, double, long, c10::optional<c10::MemoryFormat>)
    - at::_ops::_empty_affine_quantized::call(c10::ArrayRef<long>, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, double, long, c10::optional<c10::MemoryFormat>)
    - at::_ops::create__empty_affine_quantized_typed_handle()
    - aten::_empty_affine_quantized
```

# How to run it locally?

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

# How is it implemented?

See original PRs:
* LLVM pass: https://github.com/pytorch/pytorch/pull/29550
* Test project: https://github.com/pytorch/pytorch/pull/29716
* Bash driver: https://github.com/pytorch/pytorch/pull/29718
