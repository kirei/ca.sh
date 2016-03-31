# Certification Authority

This repository contains some scripts for setting up simple X.509 certification
authority using OpenSSL.

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


## Bootstrap CA

    ca.sh bootstrap

## Generate Test CSR

    openssl genrsa 2048 > test.key
    openssl req -new -sha256 -key test.key -out test.csr

## Sign CSR

    ca.sh issue test.csr generic

## Revoke Certificate

    ca.sh revoke test.crt

## Update CRL

    ca.sh crl
