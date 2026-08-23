# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# KaTeX CSS references files under `fonts/`. Expose only its distributable
# assets instead of the whole node_modules tree; Propshaft otherwise copies
# every package, fixture, source map, and README into the production image.
Rails.application.config.assets.paths << Rails.root.join('node_modules/katex/dist')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
Rails.application.config.assets.precompile += %w[admin.js admin.css]
