PKG_NAME = 2048-puzzle
SOURCES = main.sh
SUPPORT = README.org AUTHORS LICENCE .version ASCII-board

default:
	./main.sh
	echo "This was the DEMO, use make install"

pop:
	gnome-terminal -e "./main.sh -d /tmp/board" --working-directory=${shell pwd}

unlink:
	rm -f ${DESTDIR}/usr/local/bin/${PKG_NAME}

uninstall: unlink
	rm -rf ${DESTDIR}/opt/${PKG_NAME}

link: unlink
	ln -s "${PWD}/main.sh" ${DESTDIR}/usr/local/bin/${PKG_NAME}

install: unlink uninstall
	mkdir -p ${DESTDIR}/opt/${PKG_NAME}
	install -m 755 ${SOURCES} -t ${DESTDIR}/opt/${PKG_NAME}/
	cp -r ${SUPPORT} ${DESTDIR}/opt/${PKG_NAME}/
	test -e /opt/ASCII-board/board.sh && (\
	  rmdir -rf ${DESTDIR}/opt/${PKG_NAME}/ASCII-board &&\
	    ln -s /opt/ASCII-board/ ${DESTDIR}/opt/${PKG_NAME}/) || :
	ln -s /opt/${PKG_NAME}/main.sh ${DESTDIR}/usr/local/bin/${PKG_NAME}
