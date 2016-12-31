# save source backup
git add .
git commit -m "update"
git push origin backup

# deploy blog
hexo g
hexo d
hexo clean
