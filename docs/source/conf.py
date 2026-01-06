# ./docs/source/conf.py

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = 'Epi-Flow'
copyright = '2025, Qingzhou Zhang'
author = 'Qingzhou Zhang'
release = '1.0.0'

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

# Remove the old theme from the extensions list
extensions = [
    'myst_parser',      # Enable Markdown support
]

templates_path = ['_templates']
exclude_patterns = []

source_suffix = {
    '.rst': 'restructuredtext',
    '.txt': 'markdown',
    '.md': 'markdown',
}

# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

# Set the theme to Furo
html_theme = 'furo'
# html_static_path = ['_static']

# (Optional) Add a logo. Create a `_static` folder in `source` and add your logo.
# html_logo = "_static/logo.png"

# (Optional) Furo theme options
html_theme_options = {
    "light_css_variables": {
        "color-brand-primary": "#007acc",    # A nice blue color
        "color-brand-content": "#007acc",
    },
    "dark_css_variables": {
        "color-brand-primary": "#1a9fff",     # A lighter blue for dark mode
        "color-brand-content": "#1a9fff",
    },
    # Add your GitHub link to the sidebar
    "source_repository": "https://github.com/zqzneptune/epi-flow/",
    "source_branch": "main",
    "source_directory": "docs/source/",
}

# Remove the old html_context for the GitHub link, as Furo handles this better
# via html_theme_options.
html_sidebars = {
    "**": [
        "sidebar/brand.html",         # Renders the logo/title
        "sidebar/search.html",        # Renders the search bar
        "sidebar/navigation.html",    # Renders the main toctree
        "sidebar-links.html",         # Renders our custom links file
        "sidebar/ethical-ads.html",   # Renders Furo's ethical ads (optional)
    ]
}