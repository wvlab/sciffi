# sciffi

A LuaTeX package that provides the foundation for building custom bridges
between LuaTeX and external languages with their ecosystems, enabling advanced
cross-language workflows

## Installation

**CTAN** Coming soon!

**Manual Installation:**

1. Navigate to the root directory in your terminal and run 
```sh
l3build compile
l3build install
```

## Usage

> [!IMPORTANT]
> For saving code snippets sciffi uses `os.tmpname()`, which creates global
> path. By default MikTeX doesn't allow to write there, so in order to use
> sciffi environment set `AllowUnsafeOutputFiles` to true
> ```bash
> initexmf --set-config-value=[Core]AllowUnsafeOutputFiles=t
> ```

**Example: Python**

```latex
\begin{sciffi}{python}
    print("Hello from Python")
\end{sciffi}
```
