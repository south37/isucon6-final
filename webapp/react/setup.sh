etup react
sudo apt install -y nodejs nodejs-legacy npm
cd "$HOME/webapp/react"
npm install && npm cache clean
NODE_ENV=production npm run build

# Start react
cd "$HOME/webapp/react"
node build/server.js
