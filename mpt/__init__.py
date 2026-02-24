import os
from pathlib import Path

_root_dir = os.getenv('ROOT_DIR')
if _root_dir:
    root_dir = Path(_root_dir)
else:
    root_dir = Path(__file__).parent.parent

__all__ = ['root_dir']
