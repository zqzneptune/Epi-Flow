# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Epi-Flow'
copyright = '2025, Qingzhou Zhang'
author = 'Qingzhou Zhang'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration



templates_path = ['_templates']
exclude_patterns = []



# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = 'alabaster'
html_static_path = ['_static']

import os
import sys

# -- General configuration ---------------------------------------------------
extensions = [
    'myst_parser',      # Enable Markdown support
    'sphinx_rtd_theme', # Enable the theme
]

source_suffix = {
    '.rst': 'restructuredtext',
    '.txt': 'markdown',
    '.md': 'markdown',
}

# -- Options for HTML output -------------------------------------------------
html_theme = 'sphinx_rtd_theme'

# Add the "Edit on GitHub" link (optional, adjust to your repo)
html_context = {
  'display_github': True,
  'github_user': 'zqzneptune',
  'github_repo': 'epi-flow',
  'github_version': 'main/docs/source/',
}
