# Copyright 1999-2013 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/sys-block/iscsitarget/iscsitarget-1.4.20.2_p20130103.ebuild,v 1.1 2013/01/03 11:09:58 ryao Exp $

EAPI="4"

inherit linux-mod eutils flag-o-matic

if [ ${PV} == "9999" ] ; then
	inherit subversion
	ESVN_REPO_URI="http://iscsitarget.svn.sourceforge.net/svnroot/iscsitarget/trunk"
else
	SRC_URI="http://dev.gentoo.org/~ryao/dist/${P}.tar.gz"
	KEYWORDS="~amd64 ~ppc ~x86"
fi

DESCRIPTION="Open Source iSCSI target with professional features"
HOMEPAGE="http://iscsitarget.sourceforge.net/"

LICENSE="GPL-2"
SLOT="0"
IUSE=""

DEPEND="dev-libs/openssl"
RDEPEND="${DEPEND}"

MODULE_NAMES="iscsi_trgt(misc:${S}/kernel)"

pkg_setup() {
	CONFIG_CHECK="CRYPTO_CRC32C"
	ERROR_CFG="iscsitarget needs support for CRC32C in your kernel."

	kernel_is ge 2 6 14 || die "Linux 2.6.14 or newer required"


	linux-mod_pkg_setup
}
src_prepare() {
	# Fix build system to apply proper patches
	epatch "${FILESDIR}/${PN}-1.4.20.2_p20130103-fix-3.2-support.patch"

	# Apply kernel-specific patches
	emake KSRC="${KERNEL_DIR}" patch || die

	# Respect LDFLAGS. Bug #365735
	epatch "${FILESDIR}/${PN}-1.4.20.2-respect-flags-v2.patch"

	# Avoid use of WRITE_SAME_16 in Linux 2.6.32 and earlier
	epatch "${FILESDIR}/${PN}-1.4.20.2_p20130103-restore-linux-2.6.32-support.patch"
	{ kernel_is le 3 6 || 
		epatch "${FILESDIR}/${P}-kernel36.patch" ;
	}
}

src_compile() {
	emake KSRC="${KERNEL_DIR}" usr || die

	unset ARCH
	emake KSRC="${KERNEL_DIR}" kernel || die
}

src_install() {
	einfo "Installing userspace"

	# Install ietd into libexec; we don't need ietd to be in the path
	# for ROOT, since it's just a service.
	exeinto /usr/libexec
	doexe usr/ietd || die

	dosbin usr/ietadm || die

	insinto /etc
	doins etc/ietd.conf etc/initiators.allow || die

	# We moved ietd in /usr/libexec, so update the init script accordingly.
	sed -e 's:/usr/sbin/ietd:/usr/libexec/ietd:' "${FILESDIR}"/ietd-init.d-2 > "${T}"/ietd-init.d
	newinitd "${T}"/ietd-init.d ietd || die
	newconfd "${FILESDIR}"/ietd-conf.d ietd || die

	# Lock down perms, per bug 198209
	fperms 0640 /etc/ietd.conf /etc/initiators.allow

	doman doc/manpages/*.[1-9] || die
	dodoc ChangeLog README RELEASE_NOTES README.initiators README.mcs README.vmware || die

	einfo "Installing kernel module"
	unset ARCH
	linux-mod_src_install || die
}
