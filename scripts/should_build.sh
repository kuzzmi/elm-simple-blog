DIFF=$(git diff HEAD^ HEAD $1 | wc -l)
if [[ $DIFF -ne 0 ]]; then
    exit 0
else
    exit 1
fi
