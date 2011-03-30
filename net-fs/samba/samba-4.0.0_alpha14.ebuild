# Copyright 1999-2010 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/net-fs/samba/samba-4.0.0_alpha11.ebuild,v 1.5 2010/07/15 12:34:43 scarabeus Exp $

EAPI="2"

inherit confutils

MY_PV="${PV/_alpha/alpha}"
MY_P="${PN}-${MY_PV}"

DESCRIPTION="Samba Server component"
HOMEPAGE="http://www.samba.org/"
SRC_URI="mirror://samba/samba4/${MY_P}.tar.gz"
LICENSE="GPL-3"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="caps gnutls +netapi sqlite threads +client +server +tools +python"

DEPEND="!net-fs/samba-libs
	!net-fs/samba-server
	!net-fs/samba-client
	dev-libs/popt
	sys-libs/readline
	virtual/libiconv
	caps? ( sys-libs/libcap )
	gnutls? ( net-libs/gnutls )
	sqlite? ( >=dev-db/sqlite-3 )"
	#=sys-libs/ldb-0.9.10 No release yet
# See source4/min_versions.m4 for the minimal versions
RDEPEND="${DEPEND}"

RESTRICT="mirror"

S="${WORKDIR}/${MY_P}/source4"

pkg_setup() {
	SBINPROGS=""
	if use server ; then
		SBINPROGS="${SBINPROGS} bin/samba"
	fi

	BINPROGS=""
	if use client ; then
		BINPROGS="${BINPROGS} bin/smbclient bin/nmblookup bin/ntlm_auth"
	fi
	if use server ; then
		BINPROGS="${BINPROGS} scripting/bin/testparm bin/smbtorture"
	fi
	if use tools ; then
		# Should be in sys-libs/ldb, but there's no ldb release yet
		BINPROGS="${BINPROGS} bin/ldbedit bin/ldbsearch bin/ldbadd bin/ldbdel bin/ldbmodify bin/ldbrename"
	fi
	confutils_use_depend_all server python
}

src_configure() {
	# Upstream refuses to make this configurable
	use caps && export ac_cv_header_sys_capability_h=yes || export ac_cv_header_sys_capability_h=no

	./configure.developer
		--sysconfdir=/etc \
		--localstatedir=/var \
		--enable-developer \
		--enable-external-libtdb \
		--enable-external-libtevent \
		--disable-external-libldb \
		--enable-fhs \
		--enable-largefile \
		$(use_enable gnutls) \
		$(use_enable netapi) \
		--enable-socket-wrapper \
		--enable-nss-wrapper \
		--prefix=/usr
		--with-modulesdir=/usr/lib/samba/modules \
		--with-privatedir=/var/lib/samba/private \
		--with-ntp-signd-socket-dir=/var/run/samba \
		--with-lockdir=/var/cache/samba \
		--with-logfilebase=/var/log/samba \
		--with-piddir=/var/run/samba \
		--without-included-popt \
		$(use_with sqlite sqlite3) \
		$(use_with threads pthreads) \
		--with-setproctitle \
		--with-readline
}

src_compile() {
	# compile libs
	emake || die "failed"
}

src_install() {
	# install libs
	emake install DESTDIR="${D}" || die "emake installib failed"

	# binaries
	dosbin ${SBINPROGS} || die "installing SBINPROGS failed"
	dobin ${BINPROGS} || die "installing BINPROGS failed"

	# install server components
	if use server ; then
		# provision scripts
		insinto /usr/share/${PN}
		doins -r setup
		exeinto /usr/share/${PN}/setup
		doexe setup/{domainlevel,enableaccount,newuser,provision,pwsettings}
		doexe setup/{setexpiry,setpassword,upgrade_from_s3}

		# init script
		newinitd "${FILESDIR}/samba4.initd" samba
	fi
}

src_test() {
	emake test DESTDIR="${D}" || die "Test failed"
}

pkg_postinst() {
	# Optimize the python modules so they get properly removed
	use python && python_mod_optimize $(python_get_sitedir)/${PN}

	# Warn that it's an alpha
	ewarn "Samba 4 is an alpha and therefore not considered stable. It's only"
	ewarn "meant to test and experiment and definitely not for production"
}

pkg_postrm() {
	# Clean up the python modules
	use python && python_mod_cleanup $(python_get_sitedir)/${PN}
}
