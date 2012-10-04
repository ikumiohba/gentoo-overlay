# Copyright 1999-2008 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

inherit eutils toolchain-funcs multilib git

DESCRIPTION="InspIRCd - The Modular C++ IRC Daemon"
HOMEPAGE="http://www.inspircd.org/"
EGIT_REPO_URI="git://gitorious.org/inspircd/inspircd.git"
EGIT_BRANCH="insp11"
EGIT_TREE="insp11"

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
	git_src_unpack ${A}
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