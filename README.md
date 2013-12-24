bitfinex
========

Ruby library for Bitfinex.com
Work in progress, contributions welcome but keep in mind that the official docs seem to refer to an older version of their API.  Eg, signatures are now computed with an HMAC.

SSL Certificates
================
If you're on OSX, you will probably need to install the RapidSSL CA bundle, (included in the support dir).
If you installed OpenSSL via homebrew, it will need to go into
/usr/local/etc/openssl/certs

Otherwise, if you're getting SSL error, fire up irb and do:
puts OpenSSL::X509::DEFAULT_CERT_FILE
puts OpenSSL::X509::DEFAULT_CERT_DIR

And either add it to the cert file or drop it in the directory and run c_rehash
