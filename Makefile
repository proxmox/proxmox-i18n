include /usr/share/dpkg/pkg-info.mk

LINGUAS ?= \
	ar \
	bg \
	ca \
	cs \
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
PDM_I18N_DEB=pdm-i18n_$(DEB_VERSION)_all.deb
PVE_YEW_MOBILE_I18N_DEB=pve-yew-mobile-i18n_$(DEB_VERSION)_all.deb
PMG_YEW_QUARANTINE_I18N_DEB=pmg-yew-quarantine-i18n_$(DEB_VERSION)_all.deb

DEBS=$(PMG_I18N_DEB) $(PVE_I18N_DEB) $(PBS_I18N_DEB) $(PDM_I18N_DEB) $(PVE_YEW_MOBILE_I18N_DEB) $(PMG_YEW_QUARANTINE_I18N_DEB)

PMGLOCALEDIR=$(DESTDIR)/usr/share/pmg-i18n
PVELOCALEDIR=$(DESTDIR)/usr/share/pve-i18n
PBSLOCALEDIR=$(DESTDIR)/usr/share/pbs-i18n
PDMLOCALEDIR=$(DESTDIR)/usr/share/pdm-i18n
PVE_YEW_MOBILE_LOCALEDIR=$(DESTDIR)/usr/share/pve-yew-mobile-i18n
PMG_YEW_QUARANTINE_LOCALEDIR=$(DESTDIR)/usr/share/pmg-yew-quarantine-i18n

PMG_LANG_FILES=$(patsubst %, pmg-lang-%.js, $(LINGUAS))
PVE_LANG_FILES=$(patsubst %, pve-lang-%.js, $(LINGUAS))
PBS_LANG_FILES=$(patsubst %, pbs-lang-%.js, $(LINGUAS))
PDM_LANG_FILES=$(patsubst %, catalog-%.mo, $(LINGUAS))
PVE_YEW_MOBILE_LANG_FILES=$(patsubst %, pve-yew-mobile-catalog-%.mo, $(LINGUAS))
PMG_YEW_QUARANTINE_LANG_FILES=$(patsubst %, pmg-yew-quarantine-catalog-%.mo, $(LINGUAS))

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
	test  -f pmg-gui/Makefile \
	  -a -f pve-yew-mobile-gui/Makefile \
	  -a -f pmg-yew-quarantine-gui/Makefile \
	  -a -f proxmox-datacenter-manager/Makefile \
	  -a -f proxmox-backup/Makefile \
	  -a -f proxmox-yew-widget-toolkit/Makefile \
	  -a -f pve-manager/Makefile \
	  -a -f pve-manager/Makefile \
	    || git submodule update --init

.PHONY: install
install: $(PMG_LANG_FILES) $(PVE_LANG_FILES) $(PBS_LANG_FILES) $(PDM_LANG_FILES) $(PVE_YEW_MOBILE_LANG_FILES) $(PMG_YEW_QUARANTINE_LANG_FILES)
	install -d $(PMGLOCALEDIR)
	install -m 0644 $(PMG_LANG_FILES) $(PMGLOCALEDIR)
	install -d $(PVELOCALEDIR)
	install -m 0644 $(PVE_LANG_FILES) $(PVELOCALEDIR)
	install -d $(PBSLOCALEDIR)
	install -m 0644 $(PBS_LANG_FILES) $(PBSLOCALEDIR)
	install -d $(PDMLOCALEDIR)
	install -m 0644 $(PDM_LANG_FILES) $(PDMLOCALEDIR)
	install -d $(PVE_YEW_MOBILE_LOCALEDIR)
	install -m 0644 $(PVE_YEW_MOBILE_LANG_FILES) $(PVE_YEW_MOBILE_LOCALEDIR)
	install -d $(PMG_YEW_QUARANTINE_LOCALEDIR)
	install -m 0644 $(PMG_YEW_QUARANTINE_LANG_FILES) $(PMG_YEW_QUARANTINE_LOCALEDIR)

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

catalog-%.mo: %.po
	msgmerge $^ | msgattrib --no-fuzzy --no-obsolete | msgfmt --verbose --output-file $@ $<;

.INTERMEDIATE: pve-yew-mobile-all.pot
pve-yew-mobile-all.pot: pve-yew-mobile-gui.pot proxmox-yew-comp.pot proxmox-yew-widget-toolkit.pot
	xgettext $^ --output $@

pve-yew-mobile-catalog-%.mo: %.po pve-yew-mobile-all.pot
	msgmerge $*.po pve-yew-mobile-all.pot| msgattrib --no-fuzzy --no-obsolete > $@.tmp
	msgfmt --verbose --output-file $@ $@.tmp;
	rm -rf  $@.tmp

.INTERMEDIATE: pmg-yew-quarantine-all.pot
pmg-yew-quarantine-all.pot: pmg-yew-quarantine-gui.pot proxmox-yew-comp.pot proxmox-yew-widget-toolkit.pot
	xgettext $^ --output $@

pmg-yew-quarantine-catalog-%.mo: %.po pmg-yew-quarantine-all.pot
	msgmerge $*.po pmg-yew-quarantine-all.pot| msgattrib --no-fuzzy --no-obsolete > $@.tmp
	msgfmt --verbose --output-file $@ $@.tmp;
	rm -rf  $@.tmp

# parameter 1 is the name
# parameter 2 is the directory
define potupdate
	find . -name "*.js" -path "./$(2)*" | LC_COLLATE=C sort | xargs xgettext \
      --sort-output \
      --add-comments="TRANSLATORS" \
      --from-code="UTF-8" \
      --package-name="$(1)" \
      --package-version="$(shell cd $(2);git rev-parse HEAD)" \
      --msgid-bugs-address="<support@proxmox.com>" \
      --copyright-holder="Copyright (C) Proxmox Server Solutions GmbH <support@proxmox.com> & the translation contributors." \
      --output="$(1)".pot
endef

# parameter 1 is the name
# parameter 2 is the directory
define xtrpotupdate
	find . -name "*.rs" -path "./$(2)*" | LC_COLLATE=C sort | xargs xtr \
	  --package-name "$(1)" \
	  --package-version="$(shell cd $(2);git rev-parse HEAD)" \
	  --msgid-bugs-address="<support@proxmox.com>" \
	  --copyright-holder="Copyright (C) Proxmox Server Solutions GmbH <support@proxmox.com> & the translation contributors." \
	  --output "$(1)".pot
endef

.PHONY: update update_pot do_update
update_pot: submodule
	$(call potupdate,proxmox-widget-toolkit,proxmox-widget-toolkit/)
	$(call potupdate,pve-manager,pve-manager/www/manager6/)
	$(call potupdate,proxmox-mailgateway,pmg-gui/js/)
	$(call potupdate,proxmox-backup,proxmox-backup/www/)
	$(call xtrpotupdate,proxmox-datacenter-manager-ui,proxmox-datacenter-manager/ui/src/)
	$(call xtrpotupdate,pve-yew-mobile-gui,pve-yew-mobile-gui/src/)
	$(call xtrpotupdate,pmg-yew-quarantine-gui,pmg-yew-quarantine-gui/src/)
	$(call xtrpotupdate,proxmox-yew-comp,proxmox-yew-comp/src/)
	$(call xtrpotupdate,proxmox-yew-widget-toolkit,proxmox-yew-widget-toolkit/src/)

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
messages.pot: proxmox-widget-toolkit.pot proxmox-mailgateway.pot pve-manager.pot proxmox-backup.pot proxmox-datacenter-manager-ui.pot pve-yew-mobile-gui.pot pmg-yew-quarantine-gui.pot proxmox-yew-comp.pot proxmox-yew-widget-toolkit.pot
	xgettext $^ \
	  --package-name="proxmox translations" \
	  --msgid-bugs-address="<support@proxmox.com>" \
	  --copyright-holder="Copyright (C) Proxmox Server Solutions GmbH <support@proxmox.com> & the translation contributors." \
	  --output $@

.PHONY: distclean
distclean: clean

.PHONY: clean
clean:
	rm -rf $(DEB_SOURCE)-[0-9]*/ *.po.tmp *.js.tmp *.deb *.dsc *.tar.* *.build *.buildinfo *.changes *.js messages.pot

.PHONY: upload-pve upload-pmg upload-pbs upload
upload-%: UPLOAD_DIST ?= $(DEB_DISTRIBUTION)
upload-pve: $(PVE_I18N_DEB) $(PVE_YEW_MOBILE_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pve --dist $(UPLOAD_DIST)
upload-pmg: $(PMG_I18N_DEB) $(PMG_YEW_QUARANTINE_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pmg --dist $(UPLOAD_DIST)
upload-pbs: $(PBS_I18N_DEB)
	tar cf - $^|ssh -X repoman@repo.proxmox.com -- upload --product pbs --dist $(UPLOAD_DIST)

upload: upload-pve upload-pmg upload-pbs
