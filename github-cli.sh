#!/bin/bash

set -e

create_release(){
  local USERNAME="$1"
  local REPOSITORY="$2"
  local APP_VERSION="$3"
  local CURRENT_BRANCH="$4"
  local DESC="$5"
  local PAYLOAD='{
    "tag_name": "%s",
    "target_commitish": "%s",
    "name": "%s",
    "body": "%s",
    "draft": false,
    "prerelease": true
  }'
  local PAYLOAD=$(printf "$PAYLOAD" $APP_VERSION $CURRENT_BRANCH $APP_VERSION "$DESC")
  (curl -s -X POST -w '%{stderr}%{http_code}\n%{stdout}\n' \
    "https://api.github.com/repos/${USERNAME}/${REPOSITORY}/releases?access_token=$REPO_TOKEN" \
    --data "$PAYLOAD" |\
    tee -a /dev/stderr | jq -r '.id') 2> /tmp/stderr 1> /tmp/stdout

  if test "$(cat /tmp/stderr | head -n 1)" -ne "201"; then
    echo -e "> Can't create release: \n $(cat /tmp/stderr)"
    exit 1
  fi
  TAG_ID=$(cat /tmp/stdout)
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

  git commit -a -m "Releasing ${APP_VERSION}" || true
  git tag ${APP_VERSION}

  REMOTE="https://${REPO_TOKEN}@github.com/${USERNAME}/${REPOSITORY}.git"
  git push "$REMOTE" "$CURRENT_BRANCH" --tags
  git status
  echo "> Pushed"
}

#    REPO_TOKEN=$2
USERNAME="$2"
REPOSITORY="$3"
APP_VERSION="$4"
CURRENT_BRANCH="$5"
DESC="$6"

echo "> USERNAME=${USERNAME}, REPOSITORY=${REPOSITORY}, APP_VERSION=${APP_VERSION}, CURRENT_BRANCH=${CURRENT_BRANCH}, DESC=${DESC}"

case $1 in

  release )

    validate_repo_token

    create_tag

    create_release $USERNAME $REPOSITORY $APP_VERSION $CURRENT_BRANCH $DESC

  ;;

  create-tag )
    create_tag
  ;;

  create-release )
    create_release $USERNAME $REPOSITORY $APP_VERSION $CURRENT_BRANCH $DESC
  ;;

esac
