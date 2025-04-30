#!/bin/sh
set -e

echo "Preparing database..."
bundle exec rails db:prepare
echo "Starting Rails server..."
exec "$@" 