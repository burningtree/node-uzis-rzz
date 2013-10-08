
output=$(shell ls -tr *.csv | awk 'NR==1{print $1}')

all:
	npm run prepublish

run:
	@make all
	./uzis-rzz
	make zip

install:
	mkdir cache

clean:
	rm uzis-rzz.js; rm uzis-rzz-*.csv; rm uzis-rzz-*.json; rm uzis-rzz-*.zip

zip:
	# zip last results
	@echo "Creating $(output).zip .."
	zip $(output).zip $(output)

