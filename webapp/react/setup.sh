# setup react
# sudo apt install -y nodejs nodejs-legacy npm
# cd "$HOME/webapp/react"
# npm install && npm cache clean

# Start react
cd "$HOME/webapp/react"
NODE_ENV=production npm run build
sudo SSL_KEY=/home/isucon/webapp/ssl/oreore.key SSL_CERT=/home/isucon/webapp/ssl/oreore.crt API=http://localhost:8080 node build/server.js
