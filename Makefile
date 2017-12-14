LINGUAS=de fr es it

VERSION=1.0
PKGREL=2

PVE_I18N_DEB=pve-i18n_${VERSION}-${PKGREL}_all.deb
PMG_I18N_DEB=pmg-i18n_${VERSION}-${PKGREL}_all.deb

DEBS=${PMG_I18N_DEB} ${PVE_I18N_DEB}

PMGLOCALEDIR=${DESTDIR}/usr/share/pmg-i18n
PVELOCALEDIR=${DESTDIR}/usr/share/pve-i18n

PMG_LANG_FILES=$(patsubst %, pmg-lang-%.js, $(LINGUAS))
PVE_LANG_FILES=$(patsubst %, pve-lang-%.js, $(LINGUAS))

all: | submodule

.PHONY: deb
deb: $(DEBS)
$(DEBS): | submodule
	rm -rf dest
	mkdir dest
	rsync -a debian dest
	make DESTDIR=dest install 
	cd dest; dpkg-buildpackage -b -us -uc
	lintian ${PMG_I18N_DEB}
	lintian ${PVE_I18N_DEB}

.PHONY: submodule
submodule:
	test -f "pmg-gui/Makefile" || git submodule update --init

.PHONY: install
install: ${PMG_LANG_FILES} ${PVE_LANG_FILES} 
	install -d ${PMGLOCALEDIR}
	install -m 0644 ${PMG_LANG_FILES} ${PMGLOCALEDIR}
	install -d ${PVELOCALEDIR}
	install -m 0644 ${PVE_LANG_FILES} ${PVELOCALEDIR}


pmg-lang-%.js: proxmox-widget-toolkit-%.po proxmox-mailgateway-%.po
	./po2js.pl -o pmg-lang-$*.js $?

pve-lang-%.js: proxmox-widget-toolkit-%.po pve-manager-%.po
	./po2js.pl -o pve-lang-$*.js $?

.PHONY: update
update:
	./jsgettext.pl -p "proxmox-widget-toolkit 1.0" -o proxmox-widget-toolkit.pot proxmox-widget-toolkit/ 
	./jsgettext.pl -p "proxmox-mailgateway 5.0" -o proxmox-mailgateway.pot -b proxmox-widget-toolkit.pot pmg-gui/js/
	./jsgettext.pl -p "pve-manager 5.0" -o pve-manager.pot -b proxmox-widget-toolkit.pot pve-manager/www/manager6/
	for j in proxmox-widget-toolkit proxmox-mailgateway pve-manager; do for i in $(LINGUAS); do echo -n "$$j-$$i: ";msgmerge -s -v $$j-$$i.po $$j.pot >$$j-$$i.po.tmp && mv $$j-$$i.po.tmp $$j-$$i.po; done; done

# try to generate po files when someone add a new language
.SECONDARY: # do not delete generated intermediate file
proxmox-widget-toolkit-%.po: proxmox-widget-toolkit.pot
	msginit -i proxmox-widget-toolkit.pot -l $* -o proxmox-widget-toolkit-$*.po

.SECONDARY: # do not delete generated intermediate file
proxmox-mailgateway-%.po: proxmox-mailgateway.pot
	msginit -i proxmox-mailgateway.pot -l $* -o proxmox-mailgateway-$*.po

.SECONDARY: # do not delete generated intermediate file
pve-manager-%.po: pve-manager.pot
	msginit -i pve-manager.pot -l $* -o pve-manager-$*.po


.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	find . -name '*~' -exec rm {} ';'
	rm -rf dest *.po.tmp *.js.tmp *.deb *.buildinfo *.changes pve-lang-*.js pmg-lang-*.js

.PHONY: upload-pve
upload-pve: ${PVE_I18N_DEB}
	tar cf - ${PVE_I18N_DEB}|ssh -X repoman@repo.proxmox.com -- upload --product pve --dist stretch

.PHONY: upload-pmg
upload-pmg: ${PMG_I18N_DEB}
	tar cf - ${PMG_I18N_DEB}|ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist stretch
