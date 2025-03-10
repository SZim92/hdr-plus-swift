# =====================================================================
# Jekyll Website Gemfile
# =====================================================================
# This Gemfile defines the Ruby gems required for the project's documentation
# website, which is built using Jekyll and GitHub Pages. It specifies the
# dependencies needed to generate and serve the documentation locally
# and ensures compatibility with the GitHub Pages hosting environment.
#
# Usage:
#   1. Install bundler: gem install bundler
#   2. Install dependencies: bundle install
#   3. Run the site locally: bundle exec jekyll serve
# =====================================================================

# Specify the source repository for Ruby gems
source "https://rubygems.org"

# Include the github-pages gem which provides the same environment
# as GitHub Pages uses in production. This ensures compatibility
# between local development and the deployed site.
gem "github-pages", group: :jekyll_plugins

# Cross-platform support for timezone data
# Required for Windows compatibility and proper timezone handling
gem "tzinfo-data"

# Windows Directory Monitor - improves performance on Windows systems
# by properly monitoring directories for changes (only installed on Windows)
gem "wdm", "~> 0.1.0" if Gem.win_platform?

# If you have any plugins, put them here!
group :jekyll_plugins do
  # Pagination support for Jekyll posts and collections
  gem "jekyll-paginate"
  
  # Generates a sitemap.xml file for better search engine indexing
  gem "jekyll-sitemap"
  
  # Enables embedding of GitHub gists in Jekyll pages
  gem "jekyll-gist"
  
  # Generates an Atom feed of posts for RSS readers
  gem "jekyll-feed"
  
  # Adds GitHub-flavored emoji support to the site
  gem "jemoji"
  
  # Provides advanced include tag functionality with caching
  gem "jekyll-include-cache"
  
  # Adds search functionality using Algolia
  gem "jekyll-algolia"
  
  # Manages URL redirects for moved or renamed pages
  gem "jekyll-redirect-from"
end
