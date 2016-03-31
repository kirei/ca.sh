# Certification Authority

This repository contains a script for setting up simple X.509 certification
authority using OpenSSL. It's really not that advanced, but it supports
multiple CA levels as well as HSM.

If you want something with a graphical user interface, you might want to
consider [XCA](http://xca.sourceforge.net/).


## Files

**Scripts**

- ca.sh

**Configuration files**

- openssl.conf
- ca.conf

**Examples**

- root-example (Root CA)
- subca-example (Issuing CA)
- hsm-example (Root CA with HSM)

## Usage

    ca.sh bootstrap
    ca.sh issue CSR (generic|subca|host|client|xmpp) [hostname]
    ca.sh revoke CERT
    ca.sh crl

## Examples

### Bootstrap CA

    ca.sh bootstrap

### Generate Test CSR

    openssl genrsa 2048 > test.key
    openssl req -new -sha256 -key test.key -out test.csr

### Sign CSR

    ca.sh issue test.csr generic

### Revoke Certificate

    ca.sh revoke test.crt

### Update CRL

    ca.sh crl
