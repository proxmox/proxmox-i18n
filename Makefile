include /usr/share/dpkg/pkg-info.mk

LINGUAS=de it fr ja es sv ru tr zh_CN zh_TW da ca pl sl nb nn pt_BR eu fa gl hu he ar nl kr

PVE_I18N_DEB=pve-i18n_${DEB_VERSION_UPSTREAM_REVISION}_all.deb
PMG_I18N_DEB=pmg-i18n_${DEB_VERSION_UPSTREAM_REVISION}_all.deb
PBS_I18N_DEB=pbs-i18n_${DEB_VERSION_UPSTREAM_REVISION}_all.deb

DEBS=${PMG_I18N_DEB} $(PVE_I18N_DEB) $(PBS_I18N_DEB)

PMGLOCALEDIR=${DESTDIR}/usr/share/pmg-i18n
PVELOCALEDIR=${DESTDIR}/usr/share/pve-i18n
PBSLOCALEDIR=${DESTDIR}/usr/share/pbs-i18n

PMG_LANG_FILES=$(patsubst %, pmg-lang-%.js, $(LINGUAS))
PVE_LANG_FILES=$(patsubst %, pve-lang-%.js, $(LINGUAS))
PBS_LANG_FILES=$(patsubst %, pbs-lang-%.js, $(LINGUAS))

all:

.PHONY: deb
deb: $(DEBS)
$(PMG_I18N_DEB): $(PVE_I18N_DEB)
$(PBS_I18N_DEB): $(PVE_I18N_DEB)
$(PVE_I18N_DEB): | submodule
	rm -rf dest
	rsync -a * dest
	cd dest; dpkg-buildpackage -b -us -uc
	lintian $(DEBS)

.PHONY: submodule
submodule:
	test -f "pmg-gui/Makefile" || git submodule update --init

.PHONY: install
install: ${PMG_LANG_FILES} ${PVE_LANG_FILES} ${PBS_LANG_FILES}
	install -d ${PMGLOCALEDIR}
	install -m 0644 ${PMG_LANG_FILES} ${PMGLOCALEDIR}
	install -d ${PVELOCALEDIR}
	install -m 0644 ${PVE_LANG_FILES} ${PVELOCALEDIR}
	install -d ${PBSLOCALEDIR}
	install -m 0644 ${PBS_LANG_FILES} ${PBSLOCALEDIR}


pmg-lang-%.js: %.po
	./po2js.pl -t pmg -v "${VERSION}-${PKGREL}" -o pmg-lang-$*.js $?

pve-lang-%.js: %.po
	./po2js.pl -t pve -v "${VERSION}-${PKGREL}" -o pve-lang-$*.js $?

pbs-lang-%.js: %.po
	./po2js.pl -t pbs -v "${VERSION}-${PKGREL}" -o pbs-lang-$*.js $?

# parameter 1 is the name
# parameter 2 is the directory
define potupdate
    ./jsgettext.pl -p "$(1) $(shell cd $(2);git rev-parse HEAD)" -o $(1).pot $(2)
endef

.PHONY: update update_pot
update_pot: submodule
	git submodule foreach 'git pull --ff-only origin master'
	$(call potupdate,proxmox-widget-toolkit,proxmox-widget-toolkit/)
	$(call potupdate,pve-manager,pve-manager/www/manager6/)
	$(call potupdate,proxmox-mailgateway,pmg-gui/js/)
	$(call potupdate,proxmox-backup,proxmox-backup/www/)

update: | update_pot messages.pot
	for i in $(LINGUAS); do echo -n "$$i: "; msgmerge -s -v $$i.po messages.pot >$$i.po.tmp && mv $$i.po.tmp $$i.po; done;

stats:
	@for i in $(LINGUAS); do echo -n "$$i: "; msgfmt --statistics -o /dev/null $$i.po; done

init-%.po: messages.pot
	msginit -i $^ -l $^ -o $*.po --no-translator

.INTERMEDIATE: messages.pot
messages.pot: proxmox-widget-toolkit.pot proxmox-mailgateway.pot pve-manager.pot proxmox-backup.pot
	msgcat $^ > $@

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	find . -name '*~' -exec rm {} ';'
	rm -rf dest *.po.tmp *.js.tmp *.deb *.buildinfo *.changes *.js messages.pot

.PHONY: upload-pve upload-pmg upload-pbs
upload-pve: ${PVE_I18N_DEB}
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pve --dist buster
upload-pmg: ${PMG_I18N_DEB}
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist buster
upload-pbs: ${PBS_I18N_DEB}
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pbs --dist buster
