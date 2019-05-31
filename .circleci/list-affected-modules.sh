#!/bin/bash

sudo apt-get update && sudo apt-get install -y jq

### Uncomment when debugging locally ###
#CIRCLE_PROJECT_REPONAME="alt"
#CIRCLE_PROJECT_USERNAME="applift"
#Be sure NOT to commit the PREV_SUCCESS_USER_TOKEN!!
#PREV_SUCCESS_USER_TOKEN=""

# Finds the most recent successful build whose commit is also an ancestor of the commit behind this job.
# The commit for that successful build is then saved in a file called PREV_SUCCESSFUL_COMMIT.txt, making it
# available to any following steps
get_job () {
  # saves the job information for the job number (first and only argument) to a temp file named JOB_OUTPUT
  # PREV_SUCCESS_USER_TOKEN needs to be an API token with view-build access
  curl -s --user $PREV_SUCCESS_USER_TOKEN: https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$1 > JOB_OUTPUT
}

### Uncomment when debugging locally ###
#CIRCLE_BUILD_NUM=3865
#get_job $CIRCLE_BUILD_NUM
#CIRCLE_SHA1=$(cat JOB_OUTPUT | jq -r ".vcs_revision" 2>/dev/null) || true

CUR_BUILD_NUM=$CIRCLE_BUILD_NUM

while true; do
    CUR_BUILD_NUM=$(($CUR_BUILD_NUM - 1))
    get_job $CUR_BUILD_NUM

    if [[ $(cat JOB_OUTPUT | jq -r ".status") == "success" && $(cat JOB_OUTPUT | jq -r ".build_parameters.CIRCLE_JOB") == "build" ]]; then
        PREV_SUCCESSFUL_COMMIT=$(cat JOB_OUTPUT | jq -r ".vcs_revision" 2>/dev/null) || true

        echo "Checking if previous successful commit ${PREV_SUCCESSFUL_COMMIT:0:7} (from job $CUR_BUILD_NUM) is an ancestor"
        git merge-base --is-ancestor $PREV_SUCCESSFUL_COMMIT $CIRCLE_SHA1; RESULT=$?
        echo "result $RESULT"

        # No previous successful commit OR
        # the previous successful commit was an ancestor THEN
        # stop the search
        if [[ -z PREV_SUCCESSFUL_COMMIT || $RESULT == 0 ]]; then
            break
        fi
    fi
done

rm -f JOB_OUTPUT

echo "Previous successful commit: ${PREV_SUCCESSFUL_COMMIT:0:7} (job: $CUR_BUILD_NUM)"

set -eo pipefail

list_all_modules() {
    find src -maxdepth 1 -type d | sed 's/\src\///' | cut -d'/' -f2
}

list_affected_modules() {
    if [[ -z $PREV_SUCCESSFUL_COMMIT ]]; then
        list_all_modules
    else
        git diff --name-only $PREV_SUCCESSFUL_COMMIT | grep -v '^\.' | grep '\/' | cut -d'/' -f2 | sort | uniq
    fi
}

mkdir -p .runtime
touch .runtime/affected-modules.list
for m in $(list_affected_modules); do
  echo "$m" >> .runtime/affected-modules.list
done

if [[ -z $(cat .runtime/affected-modules.list) ]]; then
    echo "No modules to be built, build successful"
    circleci step halt
else
    echo "Following modules will be built:"; cat .runtime/affected-modules.list
fi
