#!/bin/bash
sudo apt-get update && sudo apt-get install -y jq

get_job () {
  # saves the job information for the job number (first and only argument) to a temp file named JOB_OUTPUT
  curl -s --user CIRCLE_TOKEN: \
    https://circleci.com/api/v1.1/project/github/$CIRCLE_PROJECT_USERNAME/$CIRCLE_PROJECT_REPONAME/$1 > JOB_OUTPUT 
}

#Set first job output to current job
get_job $CIRCLE_BUILD_NUM

while true; do
    PREV_SUCCESSFUL_BUILD_NUM=$(cat JOB_OUTPUT | jq -r ".previous_successful_build" 2>/dev/null | jq -r ".build_num" 2>/dev/null)

    get_job $PREV_SUCCESSFUL_BUILD_NUM
    PREV_SUCCESSFUL_COMMIT=$(cat JOB_OUTPUT | jq -r ".vcs_revision" 2>/dev/null) || true

    echo "Checking if previous successful commit ${PREV_SUCCESSFUL_COMMIT:0:7} (job $PREV_SUCCESSFUL_BUILD_NUM) is an ancestor"
    git merge-base --is-ancestor $PREV_SUCCESSFUL_COMMIT $CIRCLE_SHA1; RESULT=$?
    echo "result $RESULT"

    # No previous successful commit OR 
    # the previous successful commit was an ancestor OR
    # git merge-base threw some other error THEN
    # stop the search
    if [[ -z PREV_SUCCESSFUL_COMMIT || $RESULT != 1 ]]; then
        break
    fi
done

rm -f JOB_OUTPUT

echo "Previous successful commit: ${PREV_SUCCESSFUL_COMMIT:0:7} (job: $PREV_SUCCESSFUL_BUILD_NUM)"
echo $PREV_SUCCESSFUL_COMMIT > PREV_SUCCESSFUL_COMMIT.txt