from jinja2 import Template
from pathlib import Path
from itertools import groupby
from operator import itemgetter

import glob
import re

def get_icds(files):
  for file in files:
    name = re.sub(r"_icd.i686.json$", "", file.name)
    yield {
      "libname": f"/usr/local/lib/libvulkan_{name}.so",
      "jsonname": file.name,
      "json": file.read_bytes(),
      "prefix": name
    }

files = Path("/usr/local/share/vulkan/icd.d").glob("*_icd.i686.json")

template = Template((Path(__file__).parent / "static_icds_h.template").read_text(),
                    trim_blocks=True, lstrip_blocks=True)
print(template.render(icds=list(get_icds(files))))

