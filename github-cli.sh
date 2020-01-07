#!/bin/bash

set -e

create_release(){
  local USERNAME=$1
  local REPOSITORY=$2
  local APP_VERSION=$3
  local DESC=$4
  local PAYLOAD='{
    "tag_name": "%s",
    "target_commitish": "%s",
    "name": "%s",
    "body": "%s",
    "draft": false,
    "prerelease": true
  }'
  local PAYLOAD=$(printf "$PAYLOAD" $APP_VERSION $APP_VERSION $APP_VERSION "$DESC")
  curl -i -s -X POST "https://api.github.com/repos/${USERNAME}/${REPOSITORY}/releases?access_token=$REPO_TOKEN" \
    --data "$PAYLOAD"
  local TAG_ID=$(echo "" | grep -o -E 'id": [0-9]+'| awk '{print $2}' | head -n 1)
  echo "> Release created with id $TAG_ID" >&2
  echo $TAG_ID
}

upload_file(){
  curl --data-binary "@$SOURCE_FILE" -i -w '\n' -f -s -X POST -H 'Content-Type: application/octet-stream' \
  "https://uploads.github.com/repos/$REPO_URL/releases/$TAG_ID/assets?name=$TARGET_FILE&access_token=$REPO_TOKEN"
}

validate_repo_token(){
  if [ "$REPO_TOKEN" = "" ] ; then echo "REPO_TOKEN cannot be empty"; exit 1; fi
}

create_tag(){
  git config user.email "builds@travis-ci.com"
  git config user.name "Travis CI"

  git commit -a -m "Releasing ${APP_VERSION}"
  git tag ${APP_VERSION}

  REMOTE="https://${REPO_TOKEN}@github.com/${USERNAME}/${REPOSITORY}.git"
  git push "$REMOTE" "$CURRENT_BRANCH:$CURRENT_BRANCH" --tags
  git status
  echo "> Pushed"
}

#    REPO_TOKEN=$2
USERNAME=$2
REPOSITORY=$3
APP_VERSION=$4
CURRENT_BRANCH=$5

echo "> USERNAME=${USERNAME}, REPOSITORY=${REPOSITORY}, APP_VERSION=${APP_VERSION}"

case $1 in

  release )

    validate_repo_token

    create_tag

    create_release $USERNAME $REPOSITORY $APP_VERSION

  ;;

  create-tag )
    create_tag
  ;;

  create-release )
    create_release $USERNAME $REPOSITORY $APP_VERSION
  ;;

esac
