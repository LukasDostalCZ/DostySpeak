# Contributing

Thanks for helping improve Dosty Speak.

## Development build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build -j"$(nproc)"
./build/dosty-speak
```

## Release build

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
```

## Diagnostics

Use:

```text
Help → Diagnostics
```

and include the copied diagnostic output when reporting issues.
