Version=0.15.0

PREFIX = /usr/local
SYSCONFDIR = /etc

SYSCONF = \
	data/manjaro-tools.conf

BIN_BASE = \
	bin/mkchroot \
	bin/basestrap \
	bin/manjaro-chroot \
	bin/fstabgen \
	bin/signfile \
	bin/chroot-run

LIBS_BASE = \
	lib/util.sh \
	lib/util-mount.sh \
	lib/util-msg.sh \
	lib/util-fstab.sh

SHARED_BASE = \
	data/pacman-default.conf \
	data/pacman-multilib.conf \
	data/pacman-mirrors.conf

LIST_PKG = \
	data/pkg.list.d/default.list

ARCH_CONF = \
	data/make.conf.d/i686.conf \
	data/make.conf.d/x86_64.conf \
	data/make.conf.d/multilib.conf

BIN_PKG = \
	bin/checkpkg \
	bin/lddd \
	bin/finddeps \
	bin/find-libdeps \
	bin/signpkgs \
	bin/mkchrootpkg \
	bin/buildpkg \
	bin/buildtree

LIBS_PKG = \
	lib/util-pkg.sh \
	lib/util-pkgtree.sh

SHARED_PKG = \
	data/makepkg.conf \
	data/base-devel-udev

LIST_ISO = \
	data/iso.list.d/default.list \
	data/iso.list.d/manjaro.list \
	data/iso.list.d/community.list \
	data/iso.list.d/sonar.list

BIN_ISO = \
	bin/buildiso \
	bin/testiso \
	bin/deployiso

LIBS_ISO = \
	lib/util-iso.sh \
	lib/util-iso-mount.sh \
	lib/util-iso-image.sh \
	lib/util-iso-boot.sh \
	lib/util-publish.sh

SHARED_ISO = \
	data/pacman-mhwd.conf \
	data/mkinitcpio.conf \
	data/profile.conf.example

CPIOHOOKS = \
	initcpio/hooks/miso \
	initcpio/hooks/miso_loop_mnt \
	initcpio/hooks/miso_pxe_common \
	initcpio/hooks/miso_pxe_http \
	initcpio/hooks/miso_pxe_nbd \
	initcpio/hooks/miso_pxe_nfs \
	initcpio/hooks/miso_shutdown

CPIOINST = \
	initcpio/install/miso \
	initcpio/install/miso_loop_mnt \
	initcpio/install/miso_pxe_common \
	initcpio/install/miso_pxe_http \
	initcpio/install/miso_pxe_nbd \
	initcpio/install/miso_pxe_nfs \
	initcpio/install/miso_kms \
	initcpio/install/miso_shutdown

CPIO = \
	initcpio/script/miso_shutdown

MAN_XML = \
	buildpkg.xml \
	buildtree.xml \
	buildiso.xml \
	deployiso.xml \
	check-yaml.xml \
	manjaro-tools.conf.xml \
	profile.conf.xml

BIN_YAML = \
	bin/check-yaml

LIBS_YAML = \
	lib/util-yaml.sh

SHARED_YAML = \
	data/linux.preset

all: $(BIN_BASE) $(BIN_PKG) $(BIN_ISO) $(BIN_YAML) doc

edit = sed -e "s|@datadir[@]|$(DESTDIR)$(PREFIX)/share/manjaro-tools|g" \
	-e "s|@sysconfdir[@]|$(DESTDIR)$(SYSCONFDIR)/manjaro-tools|g" \
	-e "s|@libdir[@]|$(DESTDIR)$(PREFIX)/lib/manjaro-tools|g" \
	-e "s|@version@|${Version}|"

%: %.in Makefile
	@echo "GEN $@"
	@$(RM) "$@"
	@m4 -P $@.in | $(edit) >$@
	@chmod a-w "$@"
	@chmod +x "$@"

doc:
	mkdir -p man
	$(foreach var,$(MAN_XML),xsltproc /usr/share/docbook2X/xslt/man/docbook.xsl docbook/$(var) | db2x_manxml --output-dir man ;)

clean:
	rm -f $(BIN_BASE) ${BIN_PKG} ${BIN_ISO}
	rm -rf man

install_base:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools
	install -m0644 ${SYSCONF} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN_BASE} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0644 ${LIBS_BASE} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -m0644 ${SHARED_BASE} $(DESTDIR)$(PREFIX)/share/manjaro-tools

install_pkg:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.list.d
	install -m0644 ${LIST_PKG} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.list.d

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/make.conf.d
	install -m0644 ${ARCH_CONF} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/make.conf.d

	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN_PKG} $(DESTDIR)$(PREFIX)/bin

	ln -sf find-libdeps $(DESTDIR)$(PREFIX)/bin/find-libprovides

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0644 ${LIBS_PKG} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -m0644 ${SHARED_PKG} $(DESTDIR)$(PREFIX)/share/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man1
	gzip -c man/buildpkg.1 > $(DESTDIR)$(PREFIX)/share/man/man1/buildpkg.1.gz
	gzip -c man/buildtree.1 > $(DESTDIR)$(PREFIX)/share/man/man1/buildtree.1.gz

install_iso:
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.list.d
	install -m0644 ${LIST_ISO} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.list.d

	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN_ISO} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0644 ${LIBS_ISO} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/initcpio/hooks
	install -m0755 ${CPIOHOOKS} $(DESTDIR)$(SYSCONFDIR)/initcpio/hooks

	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/initcpio/install
	install -m0755 ${CPIOINST} $(DESTDIR)$(SYSCONFDIR)/initcpio/install

	install -m0755 ${CPIO} $(DESTDIR)$(SYSCONFDIR)/initcpio


	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -m0644 ${SHARED_ISO} $(DESTDIR)$(PREFIX)/share/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man1
	gzip -c man/buildiso.1 > $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	gzip -c man/deployiso.1 > $(DESTDIR)$(PREFIX)/share/man/man1/deployiso.1.gz

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man5
	gzip -c man/manjaro-tools.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/manjaro-tools.conf.5.gz
	gzip -c man/profile.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/profile.conf.5.gz

install_yaml:
	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN_YAML} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0644 ${LIBS_YAML} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -m0644 ${SHARED_YAML} $(DESTDIR)$(PREFIX)/share/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man1
	gzip -c man/check-yaml.1 > $(DESTDIR)$(PREFIX)/share/man/man1/check-yaml.1.gz

uninstall_base:
	for f in ${SYSCONF}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/$$f; done
	for f in ${BIN_BASE}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${SHARED_BASE}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	for f in ${LIBS_BASE}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done

uninstall_pkg:
	for f in ${LIST_PKG}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.list.d/$$f; done
	for f in ${ARCH_CONF}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/make.conf.d/$$f; done
	for f in ${BIN_PKG}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	for f in ${SHARED_PKG}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	for f in ${LIBS_PKG}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildpkg.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildtree.1.gz

uninstall_iso:
	for f in ${LIST_ISO}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.list.d/$$f; done
	for f in ${BIN_ISO}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${SHARED_ISO}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done

	for f in ${LIBS_ISO}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	for f in ${CPIOHOOKS}; do rm -f $(DESTDIR)$(SYSCONFDIR)/initcpio/hooks/$$f; done
	for f in ${CPIOINST}; do rm -f $(DESTDIR)$(SYSCONFDIR)/initcpio/install/$$f; done
	for f in ${CPIO}; do rm -f $(DESTDIR)$(SYSCONFDIR)/initcpio/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/deployiso.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man5/manjaro-tools.conf.5.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man5/profile.conf.5.gz

uninstall_yaml:
	for f in ${BIN_YAML}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${LIBS_YAML}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	for f in ${SHARED_YAML}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/check-yaml.1.gz

install: install_base install_pkg install_iso install_yaml

uninstall: uninstall_base uninstall_pkg uninstall_iso uninstall_yaml

dist:
	git archive --format=tar --prefix=manjaro-tools-$(Version)/ $(Version) | gzip -9 > manjaro-tools-$(Version).tar.gz
	gpg --detach-sign --use-agent manjaro-tools-$(Version).tar.gz

.PHONY: all clean install uninstall dist
