#!/bin/bash

echo " \"" |../jsonlint
echo '"hello \\\" world\\"' |../jsonlint

echo '  "\\hello \\\" world\\"' |../jsonlint
echo '" \" \\\\"' |../jsonlint
echo '"\\"' |../jsonlint
echo '"It works"' |../jsonlint
echo '[ "It works", "as an array", "too!" ]' |../jsonlint
echo '{ "It works":"as an array", "with objects":"too!" }' |../jsonlint
echo '{ "It works": [ "as an array", "with objects", "too!" ], "and":"more", "false":false, "true":true, "null": {"number": 0.223 , "text":"txt"}, "number":0.1234 }' |../jsonlint
