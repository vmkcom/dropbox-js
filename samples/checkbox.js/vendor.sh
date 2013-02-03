mkdir -p public/lib
curl http://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.0/jquery.js \
    > public/lib/jquery.js
curl http://cdnjs.cloudflare.com/ajax/libs/jquery/1.9.0/jquery.min.js \
    > public/lib/jquery.min.js
curl http://cdnjs.cloudflare.com/ajax/libs/coffee-script/1.3.3/coffee-script.min.js \
    > public/lib/coffee-script.js
curl http://cdnjs.cloudflare.com/ajax/libs/less.js/1.3.3/less.min.js \
    > public/lib/less.js
curl http://cdnjs.cloudflare.com/ajax/libs/dropbox.js/0.9.0/dropbox.min.js \
    > public/lib/dropbox.min.js
