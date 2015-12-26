Version=0.9.15

PREFIX = /usr/local
SYSCONFDIR = /etc

SYSCONF = \
	data/manjaro-tools.conf

BIN_BASE = \
	bin/mkchroot \
	bin/basestrap \
	bin/manjaro-chroot \
	bin/fstabgen \
	bin/chroot-run

LIBS_BASE = \
	lib/util.sh \
	lib/util-mount.sh \
	lib/util-msg.sh \
	lib/util-pac-conf.sh \
	lib/util-fstab.sh

SHARED_BASE = \
	data/pacman-default.conf \
	data/pacman-multilib.conf \
	data/pacman-mirrors-stable.conf \
	data/pacman-mirrors-testing.conf \
	data/pacman-mirrors-unstable.conf

SETS_PKG = \
	data/pkg.d/default.set

BIN_PKG = \
	bin/checkpkg \
	bin/lddd \
	bin/finddeps \
	bin/find-libdeps \
	bin/signpkg \
	bin/signpkgs \
	bin/mkchrootpkg \
	bin/buildpkg \
	bin/buildtree

LIBS_PKG = \
	lib/util-pkg.sh \
	lib/util-pkgtree.sh

SHARED_PKG = \
	data/makepkg-i686.conf \
	data/base-devel-udev \
	data/makepkg-x86_64.conf

SETS_ISO = \
	data/iso.d/default.set \
	data/iso.d/official.set \
	data/iso.d/community.set \
	data/iso.d/community-minimal.set

BIN_ISO = \
	bin/buildiso \
	bin/testiso \
	bin/deployiso

LIBS_ISO = \
	lib/util-iso.sh \
	lib/util-iso-aufs.sh \
	lib/util-iso-overlayfs.sh \
	lib/util-iso-image.sh \
	lib/util-iso-calamares.sh \
	lib/util-livecd.sh \
	lib/util-iso-boot.sh \
	lib/util-publish.sh \
	lib/util-iso-log.sh

SHARED_ISO = \
	data/pacman-gfx.conf \
	data/profile.conf.example

CPIOHOOKS = \
	initcpio/hooks/miso \
	initcpio/hooks/miso_overlayfs \
	initcpio/hooks/miso_loop_mnt \
	initcpio/hooks/miso_pxe_common \
	initcpio/hooks/miso_pxe_http

CPIOINST = \
	initcpio/inst/miso \
	initcpio/inst/miso_overlayfs \
	initcpio/inst/miso_loop_mnt \
	initcpio/inst/miso_pxe_common \
	initcpio/inst/miso_pxe_http \
	initcpio/inst/miso_kms

SCRIPTS = \
	data/scripts/mhwd-live \
	data/scripts/livecd \
	data/scripts/kbd-model-map

MAN_XML = \
	buildpkg.xml \
	buildtree.xml \
	buildiso.xml \
	deployiso.xml \
	manjaro-tools.conf.xml \
	profile.conf.xml

all: $(BIN_BASE) $(BIN_PKG) $(BIN_ISO) doc

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
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.d
	install -m0644 ${SETS_PKG} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.d

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
	install -dm0755 $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.d
	install -m0644 ${SETS_ISO} $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.d

	install -dm0755 $(DESTDIR)$(PREFIX)/bin
	install -m0755 ${BIN_ISO} $(DESTDIR)$(PREFIX)/bin

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/manjaro-tools
	install -m0644 ${LIBS_ISO} $(DESTDIR)$(PREFIX)/lib/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/hooks
	install -m0755 ${CPIOHOOKS} $(DESTDIR)$(PREFIX)/lib/initcpio/hooks

	install -dm0755 $(DESTDIR)$(PREFIX)/lib/initcpio/install
	install -m0755 ${CPIOINST} $(DESTDIR)$(PREFIX)/lib/initcpio/install

	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools
	install -m0644 ${SHARED_ISO} $(DESTDIR)$(PREFIX)/share/manjaro-tools

	install -dm0755 $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts
	install -m0644 ${SCRIPTS} $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man1
	gzip -c man/buildiso.1 > $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	gzip -c man/deployiso.1 > $(DESTDIR)$(PREFIX)/share/man/man1/deployiso.1.gz

	install -dm0755 $(DESTDIR)$(PREFIX)/share/man/man5
	gzip -c man/manjaro-tools.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/manjaro-tools.conf.5.gz
	gzip -c man/profile.conf.5 > $(DESTDIR)$(PREFIX)/share/man/man5/profile.conf.5.gz

uninstall_base:
	for f in ${SYSCONF}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/$$f; done
	for f in ${BIN_BASE}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${SHARED_BASE}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	for f in ${LIBS_BASE}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done

uninstall_pkg:
	for f in ${SETS_PKG}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/pkg.d/$$f; done
	for f in ${BIN_PKG}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/bin/find-libprovides
	for f in ${SHARED_PKG}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	for f in ${LIBS_PKG}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildpkg.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildtree.1.gz

uninstall_iso:
	for f in ${SETS_ISO}; do rm -f $(DESTDIR)$(SYSCONFDIR)/manjaro-tools/iso.d/$$f; done
	for f in ${BIN_ISO}; do rm -f $(DESTDIR)$(PREFIX)/bin/$$f; done
	for f in ${SHARED_ISO}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/$$f; done
	for f in ${LIBS_ISO}; do rm -f $(DESTDIR)$(PREFIX)/lib/manjaro-tools/$$f; done
	for f in ${CPIOHOOKS}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/hooks/$$f; done
	for f in ${CPIOINST}; do rm -f $(DESTDIR)$(PREFIX)/lib/initcpio/install/$$f; done
	for f in ${SCRIPTS}; do rm -f $(DESTDIR)$(PREFIX)/share/manjaro-tools/scripts/$$f; done
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/buildiso.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man1/deployiso.1.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man5/manjaro-tools.conf.5.gz
	rm -f $(DESTDIR)$(PREFIX)/share/man/man5/profile.conf.5.gz

install: install_base install_pkg install_iso

uninstall: uninstall_base uninstall_pkg uninstall_iso

dist:
	git archive --format=tar --prefix=manjaro-tools-$(Version)/ $(Version) | gzip -9 > manjaro-tools-$(Version).tar.gz
	gpg --detach-sign --use-agent manjaro-tools-$(Version).tar.gz

.PHONY: all clean install uninstall dist
