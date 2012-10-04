# Copyright 1999-2007 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-irc/inspircd/inspircd-1.1.11.ebuild,v 1.1 2007/08/06 08:37:11 hansmi Exp $

inherit eutils toolchain-funcs multilib

DESCRIPTION="InspIRCd - The Modular C++ IRC Daemon"
HOMEPAGE="http://www.inspircd.org/"
MY_PV_A="${PV%_*}" # major and minor
MY_PV_B="${PV##*[_]}" # alpha, beta, ...
MY_PV_B="${MY_PV_B%[0-9]*}"
[[ "$MY_PV_B" == "rc" ]] || MY_PV_B="${MY_PV_B:0:1}"
MY_PV_C="${PV##*[a-z]}" # suffix to alpha/beta
MY_PV="${MY_PV_A}${MY_PV_B}${MY_PV_C}" # rebuilt version
# Example: 1.2.0_alpha1 -> 1.2.0a1
# SRC_URI="mirror://sourceforge/${PN}/InspIRCd-${MY_PV}.tar.bz2"
SRC_URI="http://inspircd.eggy.cc/InspIRCd-${MY_PV}.tar.bz2"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~ppc ~x86"
IUSE="openssl gnutls ipv6 kernel_linux mysql postgres sqlite zlib ldap"

RDEPEND="
	dev-lang/perl
	openssl? ( dev-libs/openssl )
	gnutls? ( net-libs/gnutls )
	mysql? ( virtual/mysql )
	postgres? ( dev-db/postgresql )
	sqlite? ( >=dev-db/sqlite-3.0 )
	ldap? ( net-nds/openldap )"
DEPEND="${RDEPEND}"

S="${WORKDIR}/inspircd"

src_unpack() {
	unpack ${A}
	cd "${S}"

	local SQL=0
	cd src/modules

	if use zlib ; then
		cp extra/m_ziplink.cpp .
	fi
	if use openssl || use gnutls ; then
		cp extra/m_sslinfo.cpp .
		cp extra/m_ssl_oper_cert.cpp .
	fi

	if use ldap ; then
		cp extra/m_ldapauth.cpp .
	fi

	if use mysql ; then
		SQL=1
		cp extra/m_mysql.cpp .
	fi
	if use postgres ; then
		SQL=1
		cp extra/m_pgsql.cpp .
	fi
	if use sqlite ; then
		SQL=1
		cp extra/m_sqlite3.cpp .
	fi
	if [ ${SQL} -eq 1 ] ; then
		cp extra/m_sql{auth.cpp,log.cpp,oper.cpp,utils.cpp,utils.h,v2.h} .
	fi

	cd "${S}"
	epatch "${FILESDIR}/${PV}-configure-interactive-certgen.patch"
}

src_compile() {

	# ./configure doesn't know --disable-gnutls, -ipv6 and -openssl options,
	# so should be used only --enable-like.
	local myconf=""
	use gnutls  && myconf="--enable-gnutls"
	use myconf  && myconf="${myconf} --enable-ipv6 --enable-remote-ipv6"
	use openssl && myconf="${myconf} --enable-openssl"

	./configure ${myconf} \
		--enable-epoll \
		--prefix="/usr/$(get_libdir)/inspircd" \
		--config-dir="/etc/inspircd" \
		--binary-dir="/usr/bin" \
		--library-dir="/usr/$(get_libdir)/inspircd" \
		--module-dir="/usr/$(get_libdir)/inspircd/modules" \
		|| die "configure failed"
	./configure -modupdate || die "modupdate failed"

	emake CC="$(tc-getCXX)" || die "emake failed"
}

src_install() {
	# the inspircd buildsystem does not create these, its configure script
	# does. so, we have to make sure they are there.
	dodir /usr/$(get_libdir)/inspircd
	dodir /usr/$(get_libdir)/inspircd/modules
	dodir /etc/inspircd
	dodir /var/log/inspircd
	dodir /usr/include/inspircd

	emake install \
		LIBPATH="${D}/usr/$(get_libdir)/inspircd/" \
		MODPATH="${D}/usr/$(get_libdir)/inspircd/modules/" \
		CONPATH="${D}/etc/inspircd" \
		BINPATH="${D}/usr/bin" \
		BASE="${D}/usr/$(get_libdir)/inspircd/inspircd.launcher"

	insinto /usr/include/inspircd/
	doins "${S}"/include/*

	newinitd "${FILESDIR}"/init.d_inspircd inspircd

	keepdir "/var/log/inspircd/"
}

pkg_postinst() {
	enewgroup inspircd
	enewuser inspircd -1 -1 -1 inspircd
	chown -R inspircd:inspircd "${ROOT}"/etc/inspircd
	chmod 700 "${ROOT}"/etc/inspircd

	chmod 750 "${ROOT}"/var/log/inspircd
	chown -R inspircd:inspircd "${ROOT}"/var/log/inspircd

	chown -R inspircd:inspircd "${ROOT}"/usr/$(get_libdir)/inspircd
	chmod -R 755 "${ROOT}"/usr/$(get_libdir)/inspircd

	chmod -R 755 "${ROOT}"/usr/bin/inspircd
}
