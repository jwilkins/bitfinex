bitfinex
========

Ruby library for Bitfinex.com
Work in progress, contributions welcome but keep in mind that the official docs seem to refer to an older version of their API.  Eg, signatures are now computed with an HMAC.

If you like this, send pull requests with improvements.  Or send bitcoin: 12bEpFnsvPPUS57PnuSJPZe6zHvwcyYFVb

CLI for Bitfinex
================
./timed_tx sell 1 at 1000 on bitfinex -x 10 -i 60
  [*] timed_tx
  Will:
    sell 1.0 BTC @ 845.0 USD 10 time(s)
    on bitfinex
    1 order every 60 seconds
  pausing 10 seconds, hit ctrl-c to abort
  Placed order 5584165 (1.0 @ 1000.0), waiting for completion ..


SSL Certificates
================
If you're on OSX, you will probably need to install the RapidSSL CA bundle, (included in the support dir).
If you installed OpenSSL via homebrew, it will need to go into
/usr/local/etc/openssl/certs

Otherwise, if you're getting SSL errors, fire up irb and do:
puts OpenSSL::X509::DEFAULT_CERT_FILE
puts OpenSSL::X509::DEFAULT_CERT_DIR

And either add it to the cert file or drop it in the directory and run c_rehash


TODO
====
http://www.set50.com/cgi-bin/formula.asp#Stochastic%20and%20RSI%20System
