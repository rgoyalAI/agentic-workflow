#!/bin/bash
# Run before accepting changes

echo "🔍 Pre-edit checks for: $1"

# Format code based on file type
if [[ $1 == *.js ]] || [[ $1 == *.ts ]]; then
    npx prettier --write $1
elif [[ $1 == *.py ]]; then
    black $1
fi

# Run linting
if [[ $1 == *.js ]] || [[ $1 == *.ts ]]; then
    npx eslint $1 --fix
elif [[ $1 == *.py ]]; then
    pylint $1 --errors-only
fi