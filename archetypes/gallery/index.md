---
title: "{{ replace .File.ContentBaseName "-" " " | title }}"
layout: gallery
date: {{ .Date }}
draft: false
# Drop .jpg/.png files next to this index.md; each becomes a card (resized to 1200px wide, linking to the original).
# List them here to control order and captions. Files you don't list are appended alphabetically
# with a caption made from the filename ("sourdough-boule.jpg" -> "Sourdough boule").
images:
  # - file: sourdough-boule.jpg
  #   caption: "Sourdough Boule!"
---

Optional intro text goes here (delete for images only).
