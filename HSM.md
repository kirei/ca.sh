# How to use ca.sh with a HSM

## Prerequisites

- OpenSSL (http://www.openssl.org)
- OpenSC (https://github.com/OpenSC/OpenSC/wiki)
- Smartcard-HSM USB-Stick (http://www.smartcard-hsm.com/)

## Initialize HSM

### 1. Generate Wrapping Keys and SO-PIN

Generate Device Key Encryption Key (DKEK) used for initializing the HSM. In
this example, we will generate two (2) keys.

    sc-hsm-tool --create-dkek-share dkek-share-1.pbe
    sc-hsm-tool --create-dkek-share dkek-share-2.pbe

HSM:s initialized with the same DKEK may shared keys, hence the DKEK shares
above must be kept safe and protected.

### 2. Initialize Primary HSM

Random SO-PIN (16 digits, same for both primary and secondary HSMs). PIN (8
digits) choosen by each HSM custodian (can, and should, be changed by the
custodian later).

    sc-hsm-tool --verbose --initialize --dkek-shares 2 --label "Example CA"
    sc-hsm-tool --import-dkek-share dkek-share-1.pbe
    sc-hsm-tool --import-dkek-share dkek-share-2.pbe

### 3. Create key on Primary HSM

    pkcs11-tool --module /Library/OpenSC/lib/opensc-pkcs11.so \
        --login --keypairgen --key-type rsa:2048 --id 10 --label "CA" 

### 4. Backup Key from Primary HSM

Dump all card objects.  Note "Key ref" for key to back up.

    pkcs15-tool -D
    sc-hsm-tool --wrap-key root-ca-key-wrapped.bin --key-reference 1

Encrypted key backups will be placed in *.bin.

### 5. Initialize Secondary HSMs

Initialize HSM and import all DKEK shares.

    sc-hsm-tool --verbose --initialize --dkek-shares 2 --label "Example CA"
    sc-hsm-tool --import-dkek-share dkek-share-1.pbe
    sc-hsm-tool --import-dkek-share dkek-share-2.pbe

### 6. Restore Key to Secondary HSM

    sc-hsm-tool --unwrap-key root-ca-key-wrapped.bin --key-reference 1


## Change HSM PIN

Verify old PIN:

    opensc-explorer

    OpenSC [3F00]> cd aid:E82B0601040181C31F0201

    OpenSC [E82B/0601/0401/81C3/1F02/01]> verify CHV129
    Please enter PIN:
    Code correct.

    OpenSC [3F00]> cd aid:E82B0601040181C31F0201

Change PIN from 12345678 to 00000000:

    opensc-explorer

    OpenSC [3F00]> cd aid:E82B0601040181C31F0201

    OpenSC [E82B/0601/0401/81C3/1F02/01]> change CHV129 "12345678" "00000000"
    PIN changed.

    OpenSC [E82B/0601/0401/81C3/1F02/01]> quit

Change SO-PIN:

    opensc-explorer

    OpenSC [3F00]> cd aid:E82B0601040181C31F0201

    OpenSC [E82B/0601/0401/81C3/1F02/01]> change chv136 3537363231383830 3537363231383830
    PIN changed.
    OpenSC [E82B/0601/0401/81C3/1F02/01]> 

## More information

- https://github.com/OpenSC/OpenSC/wiki
- https://github.com/OpenSC/OpenSC/wiki/SmartCardHSM
