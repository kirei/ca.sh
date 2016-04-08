#!/bin/sh
#
# Copyright (c) 2016 Kirei AB. All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

if [ ! -s ca.conf ]; then
	echo "ERROR: CA configuration file not found"
	exit 1
fi

if [ ! -s openssl.conf ]; then
	echo "ERROR: OpenSSL configuration file not found"
	exit 1
fi

. ca.conf

usage() {
	echo "USAGE: $0 bootstrap"
	echo "USAGE: $0 issue CSR (generic|subca|host|client|xmpp) [hostname]"
	echo "USAGE: $0 revoke CERT"
	echo "USAGE: $0 crl"
	exit 1
}

ca_bootstrap() {
	rm -f *.old

	if [ ! -n "$OPENSSL_ENGINE" ]; then
		if [ ! -f $CA_KEY ]; then
			touch $CA_KEY
			chmod go= $CA_KEY
			echo "Generating CA key ..."
			openssl genrsa $CA_KEYSIZE > $CA_KEY			
		fi
	fi

	if [ -n "$CA_CERT" ]; then
		rm -f $CA_CERT

		echo "Generating CA certificate ..."
		$OPENSSL_BIN req -config $OPENSSL_CONF \
			-new -x509 -sha256 -utf8 \
			-set_serial 0 -days $CA_DAYS \
			$OPENSSL_ENGINE \
			-key $CA_KEY \
			-out $CA_CERT

		$OPENSSL_BIN x509 -text -noout -in $CA_CERT
	fi

	if [ -n "$CA_CSR" ]; then
		rm -f $CA_CSR

		echo "Generating CA certificate request ..."
		$OPENSSL_BIN req -config $OPENSSL_CONF \
			-new -sha256 -utf8 \
			$OPENSSL_ENGINE \
			-key $CA_KEY \
			-out $CA_CSR

		$OPENSSL_BIN req -text -noout -in $CA_CSR
	fi

	rm -fr $CA_ISSUED
	rm -f $CA_SERIAL
	rm -f $CA_DATABASE

	mkdir $CA_ISSUED
	echo 01 > $CA_SERIAL
	touch $CA_DATABASE
}

ca_revoke_certificate() {
	INPUT_CRT=$1

	if [ ! -s $INPUT_CRT ]; then
		echo "ERROR: Certificate file not found, revocation failed"
		exit 1
	fi

	[ -n "$CMD_BEFORE" ] && $CMD_BEFORE

	$OPENSSL_BIN ca -config $OPENSSL_CONF $OPENSSL_ENGINE \
		-name $CA_SECTION -revoke $INPUT_CRT

	[ -n "$CMD_AFTER" ] && $CMD_AFTER
}

ca_generate_crl() {
	[ -n "$CMD_BEFORE" ] && $CMD_BEFORE

	$OPENSSL_BIN ca -config $OPENSSL_CONF $OPENSSL_ENGINE \
		-name $CA_SECTION \
		-gencrl -crldays $CA_CRL_DAYS -out $CA_CRL.pem

	[ -n "$CMD_AFTER" ] && $CMD_AFTER

	$OPENSSL_BIN crl -in $CA_CRL.pem -out $CA_CRL -outform der
	$OPENSSL_BIN crl -in $CA_CRL -inform der -noout -text
	rm -f $CA_CRL.pem
}

ca_issue_certificate() {
	INPUT_CSR=$1
	TYPE=$2
	HOSTNAME=$3
	DOMAIN=$4

	OUTPUT_CRT=`basename $1 .csr`.crt

	OPENSSL_CONF_TMP=openssl.conf.tmp

	cp $OPENSSL_CONF $OPENSSL_CONF_TMP

	cat <<CONFIG >>$OPENSSL_CONF_TMP
[ ext ]
subjectKeyIdentifier=	hash
authorityKeyIdentifier=	keyid:always,issuer:always
CONFIG

	if [ -n "$CA_CRL_DP" ]; then
	cat <<CONFIG >>$OPENSSL_CONF_TMP
crlDistributionPoints=	$CA_CRL_DP
CONFIG
	fi

	case $TYPE in
	generic)
		cat <<CONFIG >>$OPENSSL_CONF_TMP
basicConstraints=	critical,CA:FALSE
keyUsage=		critical,keyEncipherment,digitalSignature
CONFIG
		;;
	subca)
		cat <<CONFIG >>$OPENSSL_CONF_TMP
basicConstraints=	critical,CA:TRUE,pathlen:0
keyUsage=		critical,keyCertSign,digitalSignature,cRLSign
CONFIG
		;;
	host)	
		cat <<CONFIG >>$OPENSSL_CONF_TMP
basicConstraints=	critical,CA:FALSE
keyUsage=		critical,keyEncipherment,digitalSignature
extendedKeyUsage=	serverAuth,clientAuth
subjectAltName=		DNS:$HOSTNAME
CONFIG
		;;
	client)
		cat <<CONFIG >>$OPENSSL_CONF_TMP
	basicConstraints=	critical,CA:FALSE
	keyUsage=               critical,keyEncipherment,digitalSignature,keyAgreement
	extendedKeyUsage=       clientAuth,emailProtection
	subjectAltName=         email:copy
CONFIG
		;;
	xmpp)
		cat <<CONFIG >>$OPENSSL_CONF_TMP
basicConstraints=	critical,CA:FALSE
keyUsage=		critical,keyEncipherment,digitalSignature
extendedKeyUsage=	serverAuth,clientAuth
subjectAltName=		@subject_alternative_name
[ subject_alternative_name ]
DNS		= $HOSTNAME
otherName.0	= id-on-dnsSRV;UTF8:_xmpp-client.$DOMAIN
otherName.1	= id-on-dnsSRV;UTF8:_xmpp-server.$DOMAIN
CONFIG
		;;
	*)
		usage
	esac

	echo "Signing a $TYPE certificate"

	[ -n "$CMD_BEFORE" ] && $CMD_BEFORE

	$OPENSSL_BIN ca -config $OPENSSL_CONF_TMP $OPENSSL_ENGINE \
		-name $CA_SECTION \
		-extensions ext -in $INPUT_CSR -out $OUTPUT_CRT

	[ -n "$CMD_AFTER" ] && $CMD_AFTER

	rm $OPENSSL_CONF_TMP
	
	if [ -s $OUTPUT_CRT  ]; then
		echo "SUCCESS: Certificate issued"
		if [ -n "$CA_GIT_REMINDER" ]; then
			git add $CA_PREFIX-issued/*.pem $CA_PREFIX.db $CA_PREFIX.serial
			echo "Do not forget to commit changes using 'git commit' and 'git push'"
		fi
	else
		echo "ERROR: Failed to issue certificate"
		exit 1
	fi
}

case $1 in
	bootstrap)
		ca_bootstrap
		;;
	issue)
		ca_issue_certificate $2 $3 $4 $5
		;;
	revoke)
		ca_revoke_certificate $2 $3 $4
		;;
	crl)
		ca_generate_crl
		;;
	*)
		usage
esac
