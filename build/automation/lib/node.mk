NODE_VERSION = 14.15.1

node-virtualenv: ### Setup Node.js virtual environment - optional: NODE_VERSION
	nvm install $(NODE_VERSION)
	nvm use $(NODE_VERSION)
