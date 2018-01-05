#! /bin/sh

rm -rf publish
node ./node_modules/.bin/nodeppt generate ./ppt.md -a

cd publish
mv ppt.html index.html

git init
git add -A
date=`date "+DATE: %m/%d/%Y%nTIME: %H:%M:%S"`
git commit -m 'generate by nodeppt on ${date}'
#exit
echo 'push to gh-pages'
git push -u https://github.com/umbrellaZwl/webpack-upgrade-pratice.git master:gh-pages --force
