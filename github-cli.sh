#!/bin/bash

set -e

create_release(){
  local USERNAME="$1"
  local REPOSITORY="$2"
  local APP_VERSION="$3"
  local CURRENT_BRANCH="$4"
  local DESC="$5"
  local PAYLOAD=$(echo '{}' | jq --arg tag_name "$APP_VERSION" \
  --arg target_commitish "$CURRENT_BRANCH" \
  --arg body "$DESC" '{
    $tag_name,
    $target_commitish,
    name: $tag_name,
    $body,
    "draft": false,
    "prerelease": true
  }' | sed -r 's/[\]{2}/\\/g')
  (curl -s -X POST -w '%{stderr}%{http_code}\n%{stdout}\n' \
      -H "Authorization: token ${REPO_TOKEN}" \
    "https://api.github.com/repos/${USERNAME}/${REPOSITORY}/releases?access_token=$REPO_TOKEN" \
    --data "$PAYLOAD" |\
    tee -a /dev/stderr | jq -r '.id') 2> /tmp/stderr 1> /tmp/stdout

  if test "$(cat /tmp/stderr | head -n 1)" -ne "201"; then
    echo -e "> Can't create release: \nreq=${PAYLOAD}\n\nres=$(cat /tmp/stderr)" >&2
    exit 10
  fi
  local RELEASE_ID=$(cat /tmp/stdout)
  echo "> Release created with id $RELEASE_ID" >&2
  echo $RELEASE_ID
}

upload_file(){
  local OUT=$(curl --data-binary "@$SOURCE_FILE" -w "\n%{http_code}\n%{stdout}\n" \
    -s -X POST -H 'Content-Type: application/octet-stream' \
    -H "Authorization: token ${REPO_TOKEN}" \
    "https://uploads.github.com/repos/${USERNAME}/${REPOSITORY}/releases/$RELEASE_ID/assets?name=$TARGET_FILE"
    )

  if test "$(echo "$OUT" | tail -n 1)" -ne "201"; then
    echo -e "> Can't upload file: $TARGET_FILE \n $(echo ${OUT})" >&2
    return 11
  fi
  return 0
}

upload_files(){
  for SOURCE_FILE in "$@"; do
    if [ -f "$SOURCE_FILE" ]; then
      TARGET_FILE="$(basename $SOURCE_FILE)"
      echo "> uploading $TARGET_FILE"  >&2
      md5sum $SOURCE_FILE && ls -lha $SOURCE_FILE
      ( echo "try 1" && upload_file ) || ( echo "try 2" && upload_file ) || ( echo "try 3" && upload_file )
    fi
  done
}

validate_repo_token(){
  if [ "$REPO_TOKEN" = "" ] ; then
    echo "REPO_TOKEN cannot be empty" >&2
    exit 12;
  fi
}

create_tag(){
  git config user.email "githubcli@github.com"
  git config user.name "Github CLI"

  git tag ${APP_VERSION}

  local REMOTE="https://${REPO_TOKEN}@github.com/${USERNAME}/${REPOSITORY}.git"
  local LAST_COMMIT=$(git log --oneline | awk '{print $1}' | head -n1)
  git push "$REMOTE" --tags
  git status
  echo "> Pushed ${LAST_COMMIT} to ${CURRENT_BRANCH}" >&2
}

USERNAME="$2"
REPOSITORY="$3"
APP_VERSION="$4"
CURRENT_BRANCH="$5"
DESC="$6"

echo "> USERNAME=${USERNAME}, REPOSITORY=${REPOSITORY}, APP_VERSION=${APP_VERSION}, CURRENT_BRANCH=${CURRENT_BRANCH}, DESC=${DESC}" >&2

case $1 in

  release )

    validate_repo_token

    create_tag

    RELEASE_ID=$(create_release $USERNAME $REPOSITORY $APP_VERSION $CURRENT_BRANCH "$DESC")

    upload_files "$@"

  ;;

  create-tag )
    create_tag
  ;;

  create-release )
    create_release $USERNAME $REPOSITORY $APP_VERSION $CURRENT_BRANCH "$DESC"
  ;;

  upload-files )
    RELEASE_ID="$4"
    upload_files "$@"
  ;;

esac
