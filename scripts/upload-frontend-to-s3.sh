#!/bin/bash
set -e
FRONTEND_BUCKET=$1

if [ -z "$FRONTEND_BUCKET" ]; then
  echo "Usage: ./scripts/upload-frontend-to-s3.sh <bucket-name>"
  exit 1
fi

cd app/frontend
npm ci
npm run build
aws s3 sync build/ s3://$FRONTEND_BUCKET --delete
