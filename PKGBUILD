# Maintainer: artoo <artoo@manjaro.org>
# Maintainer: Philip Müller <philm@manjaro.org>

_pkgbase=manjaro-tools
_ver=0.14.4
_branch=hybrid

pkgbase=manjaro-tools-git
pkgname=('manjaro-tools-base-git'
        'manjaro-tools-pkg-git'
        'manjaro-tools-iso-git'
        'manjaro-tools-yaml-git')
pkgver=r2529.ca67278
pkgrel=1
arch=('any')
pkgdesc='Development tools for Manjaro Linux'
license=('GPL')
groups=('manjaro-tools')
url='https://github.com/oberon2007/manjaro-tools'
makedepends=('git' 'docbook2x')
source=("git+$url.git#branch=$_branch")
sha256sums=('SKIP')

prepare() {
    cd ${srcdir}/${_pkgbase}
    # patches here
    sed -e "s/^Version=.*/Version=$_ver/" -i Makefile
    #sed -e "s/^Version=.*/Version=$pkgver/" -i Makefile
}

pkgver() {
    cd ${srcdir}/${_pkgbase}
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

build() {
    cd ${srcdir}/${_pkgbase}
    make SYSCONFDIR=/etc PREFIX=/usr
}

package_manjaro-tools-base-git() {
    pkgdesc='Development tools for Manjaro Linux (base tools)'
    provides=("manjaro-tools-base=$_ver")
    depends=('openssh' 'rsync' 'haveged' 'os-prober' 'gnupg' 'pacman-mirrorlist>=20160301')
    optdepends=('manjaro-tools-pkg: Manjaro Linux package tools'
                'manjaro-tools-iso: Manjaro Linux iso tools'
                'manjaro-tools-yaml: Manjaro Linux yaml tools')
    conflicts=('manjaro-tools-base')
    backup=('etc/manjaro-tools/manjaro-tools.conf')

    cd ${srcdir}/${_pkgbase}
    make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install_base
}

package_manjaro-tools-pkg-git() {
    pkgdesc='Development tools for Manjaro Linux (packaging tools)'
    provides=("manjaro-tools-pkg=$_ver")
    depends=('namcap' 'manjaro-tools-base-git')
    conflicts=('manjaro-tools-pkg' 'devtools')

    cd ${srcdir}/${_pkgbase}
    make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install_pkg
}

package_manjaro-tools-yaml-git() {
    pkgdesc='Development tools for Manjaro Linux (yaml tools)'
    provides=("manjaro-tools-yaml=$_ver")
    conflicts=('manjaro-tools-yaml')
    depends=('manjaro-tools-base-git' 'calamares-tools' 'ruby-kwalify' 'manjaro-iso-profiles-base')

    cd ${srcdir}/${_pkgbase}
    make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install_yaml
}

package_manjaro-tools-iso-git() {
    pkgdesc='Development tools for Manjaro Linux (ISO tools)'
	provides=("manjaro-tools-iso=$_ver")
    depends=('dosfstools' 'libisoburn' 'squashfs-tools' 'manjaro-tools-yaml-git' 'mkinitcpio' 'mktorrent')
	conflicts=('manjaro-tools-iso')
    optdepends=('qemu: quickly test isos')

	cd ${srcdir}/${_pkgbase}
	make SYSCONFDIR=/etc PREFIX=/usr DESTDIR=${pkgdir} install_iso
}

