## Requirements
* ffmpeg
* python
* latexmk
* lualatex
* sciffi
* uv
* gtk (if you want to use pympress)

## How to run

```bash
uv sync
source .venv/bin/activate
python getframes.py
latexmk -lualatex -shell-escape apple.tex
```

After that you should have apple.pdf in this directory, open pympyress by
```bash
python -m pympress apple.pdf
```
