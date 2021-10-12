	USER=root
	HOST=139.159.193.50
	DIR=/root/site/
ALL:
	make push && make deploy

push:
	git add .
	git commit -m "update"
	git push

deploy:
	git submodule update
	hugo && rsync -avz --delete public/ $(USER)@$(HOST):$(DIR)

init:
	git submodule init
	git submodule update