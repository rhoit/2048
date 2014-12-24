sources = $(wildcard *.sh)

default:
	./main.sh
	echo "This was the DEMO, use make install"

all:
	@echo "build programs lib, doc."

unlink:
	rm -f /usr/local/bin/2048

uninstall: unlink
	rm -rf /opt/2048

link: unlink
	ln -s "$(PWD)/main.sh" /usr/local/bin/2048

install: unlink uninstall
	mkdir -p /opt/2048
	cp *sh /opt/2048/
	ln -s /opt/2048/main.sh /usr/local/bin/2048

installcheck:
	@echo $(sources)

clean:
	echo "erase what has been buit (opposite of make all)"

dist:
	echo "create PACKAGE-VERSION.tar.gz"

distclean:
	echo "erase what ever done by make all, then clean what ever done by ./configure"

distcheck:
	echo "sanity check"

check:
	echo "run the test suite if any"


alias:
	@echo "add alias in to '.bashrc'"
	@echo "alias 2048='$PWD/main.sh'"
