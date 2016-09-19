#!/usr/bin/env bash

set -eo pipefail

[[ "$TRACE" ]] && set -x

start_viewer_sinatra() {
  mkdir -p /tmp/viewer-sinatra
  cd /tmp/viewer-sinatra
  # TODO: Make `master` configurable
  curl -fsSL https://github.com/everypolitician/viewer-sinatra/archive/master.tar.gz | tar -x -f - --strip 1
  bundle install
  bundle exec ruby app.rb &
  while ! nc -z localhost 4567; do sleep 1; done
}

build_viewer_static() {
  cd /tmp
  wget -nv -m localhost:4567/status/all_countries.html || (echo "wget exited with non-zero exit code: $?" >&2 && exit 1)
}

deploy_viewer_static() {
  cd /tmp
  git clone https://github.com/everypolitician/viewer-static.git
  cd viewer-static
  git checkout gh-pages
  cp -R /tmp/localhost:4567/* .
  git add .
  git -c "user.name=everypoliticianbot" -c "user.email=everypoliticianbot@users.noreply.github.com" commit -m "Automated commit" || true
  git push origin gh-pages
}

main() {
  start_viewer_sinatra
  build_viewer_static
  deploy_viewer_static
}

main
