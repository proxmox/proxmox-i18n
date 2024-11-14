include /usr/share/dpkg/pkg-info.mk

LINGUAS=\
	ar \
	bg \
	ca \
	da \
	de \
	es \
	eu \
	fa \
	fr \
	gl \
	he \
	hr \
	hu \
	it \
	ja \
	ka \
	ko \
	nb \
	nl \
	nn \
	pl \
	pt_BR \
	ru \
	sl \
	sv \
	tr \
	ukr \
	zh_CN \
	zh_TW \

BUILDDIR ?= $(DEB_SOURCE)-$(DEB_VERSION)

DSC=$(DEB_SOURCE)_$(DEB_VERSION_UPSTREAM_REVISION).dsc
PVE_I18N_DEB=pve-i18n_$(DEB_VERSION)_all.deb
PMG_I18N_DEB=pmg-i18n_$(DEB_VERSION)_all.deb
PBS_I18N_DEB=pbs-i18n_$(DEB_VERSION)_all.deb

DEBS=$(PMG_I18N_DEB) $(PVE_I18N_DEB) $(PBS_I18N_DEB)

PMGLOCALEDIR=$(DESTDIR)/usr/share/pmg-i18n
PVELOCALEDIR=$(DESTDIR)/usr/share/pve-i18n
PBSLOCALEDIR=$(DESTDIR)/usr/share/pbs-i18n

PMG_LANG_FILES=$(patsubst %, pmg-lang-%.js, $(LINGUAS))
PVE_LANG_FILES=$(patsubst %, pve-lang-%.js, $(LINGUAS))
PBS_LANG_FILES=$(patsubst %, pbs-lang-%.js, $(LINGUAS))

all:

$(BUILDDIR): submodule
	rm -rf $@ $@.tmp
	rsync -a * $@.tmp
	mv $@.tmp $@

.PHONY: deb
deb: $(DEBS)
$(DEBS): build-debs

build-debs: $(BUILDDIR)
	cd $(BUILDDIR); dpkg-buildpackage -b -us -uc
	lintian $(DEBS)
	touch "$@"

sbuild: $(DSC)
	sbuild $(DSC)

.PHONY: dsc
dsc: $(DSC)
$(DSC): $(BUILDDIR)
	cd $(BUILDDIR); dpkg-buildpackage -S -us -uc -d
	lintian $(DSC)

submodule:
	test  -f pmg-gui/Makefile -a -f proxmox-backup/Makefile -a -f pve-manager/Makefile \
	    || git submodule update --init

.PHONY: install
install: $(PMG_LANG_FILES) $(PVE_LANG_FILES) $(PBS_LANG_FILES)
	install -d $(PMGLOCALEDIR)
	install -m 0644 $(PMG_LANG_FILES) $(PMGLOCALEDIR)
	install -d $(PVELOCALEDIR)
	install -m 0644 $(PVE_LANG_FILES) $(PVELOCALEDIR)
	install -d $(PBSLOCALEDIR)
	install -m 0644 $(PBS_LANG_FILES) $(PBSLOCALEDIR)
# compat symlinks for kr -> ko correction.
	ln -s pmg-lang-ko.js $(PMGLOCALEDIR)/pmg-lang-kr.js
	ln -s pve-lang-ko.js $(PVELOCALEDIR)/pve-lang-kr.js
	ln -s pbs-lang-ko.js $(PBSLOCALEDIR)/pbs-lang-kr.js

pmg-lang-%.js: %.po
	./po2js.pl -t pmg -v "$(DEB_VERSION)" -o pmg-lang-$*.js $?

pve-lang-%.js: %.po
	./po2js.pl -t pve -v "$(DEB_VERSION)" -o pve-lang-$*.js $?

pbs-lang-%.js: %.po
	./po2js.pl -t pbs -v "$(DEB_VERSION)" -o pbs-lang-$*.js $?

# parameter 1 is the name
# parameter 2 is the directory
define potupdate
    ./jsgettext.pl -p "$(1) $(shell cd $(2);git rev-parse HEAD)" -o $(1).pot $(2)
endef

.PHONY: update update_pot do_update
update_pot: submodule
	$(call potupdate,proxmox-widget-toolkit,proxmox-widget-toolkit/)
	$(call potupdate,pve-manager,pve-manager/www/manager6/)
	$(call potupdate,proxmox-mailgateway,pmg-gui/js/)
	$(call potupdate,proxmox-backup,proxmox-backup/www/)

do_update:
	$(MAKE) update_pot
	$(MAKE) messages.pot
	for i in $(LINGUAS); do echo -n "$$i: "; msgmerge -s -v $$i.po messages.pot >$$i.po.tmp && mv $$i.po.tmp $$i.po; done;

update:
	git submodule foreach 'git pull --ff-only origin master'
	$(MAKE) do_update

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
	rm -rf $(DEB_SOURCE)-[0-9]*/ *.po.tmp *.js.tmp *.deb *.dsc *.tar.* *.build *.buildinfo *.changes *.js messages.pot

.PHONY: upload-pve upload-pmg upload-pbs upload
upload-%: UPLOAD_DIST ?= $(DEB_DISTRIBUTION)
upload-pve: $(PVE_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pve --dist $(UPLOAD_DIST)
upload-pmg: $(PMG_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist $(UPLOAD_DIST)
upload-pbs: $(PBS_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pbs --dist $(UPLOAD_DIST)

upload: upload-pve upload-pmg upload-pbs
