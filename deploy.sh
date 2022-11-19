zip -r deploy.zip * -x '.bundle' '.ruby-version'
aws lambda update-function-code --function-name myakuari_judge_line_bot --zip-file fileb://deploy.zip
rm deploy.zip
