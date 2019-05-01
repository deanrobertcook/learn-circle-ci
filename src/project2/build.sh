#! /bin/bash
cd "$(dirname "$0")"
echo "Building project 2"
cat < file1.txt

if [[ true && ! -z "" ]]; then
    echo "true case"
else 
    echo "false case"
fi