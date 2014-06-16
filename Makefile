all:
	./node_modules/.bin/browserify -t coffeeify main.coffee > main.js
	./node_modules/.bin/lessc assets/style.less > assets/style.css

run:
	make
	python3 -m http.server 3000
	
