
output=$(shell ls -tr *.csv | awk 'NR==1{print $1}')

all:
	./uzis-rzz
	make zip

clean:
	rm *.csv; rm *.json; rm *.zip

zip:
	# zip last results
	@echo "Creating $(output).zip .."
	zip $(output).zip $(output)

