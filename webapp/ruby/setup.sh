# Setup ruby
sudo apt install -y ruby ruby-dev libmysqlclient-dev
cd "$HOME/webapp/ruby"
sudo gem update -N --system && sudo gem install -N bundler
bundle install --jobs 4

# Only once
# Setup timezone of mysql by http://ikm.hatenablog.jp/entry/2013/06/26/185518

# Start ruby
# MYSQL_HOST is web01
cd "$HOME/webapp/ruby"
MYSQL_HOST=54.238.211.35 bundle exec thin start --port 8080 -A rack -R config.ru -e production
