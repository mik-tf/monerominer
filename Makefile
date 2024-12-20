build:
	bash monerominer.sh install

rebuild:
	monerominer uninstall
	bash monerominer.sh install
	
delete:
	monerominer uninstall