#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_GiftMsgWarning.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/giftmessagewarning

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/giftmessagewarning-87.html',
    expected   => {
        order_nr => 1230008630,
        barcode  => 'giftmessagewarning1230008630.png',
        message  => 'Goodbye Rita :-( 2187'
    }
);

__DATA__
<html>
<head>
<title></title>
</head>
<body bgcolor="#FFFFFF" TEXT="#000000">
<font face="Arial,Helvetica" size="6" color="#000000">GIFT MESSAGE:</font>
<br />
<br />
<br />
<font face="Arial,Helvetica" size="4" color="#000000" id="msg">Goodbye Rita :-( 2187</font>
<br />
<br />
<br />
Order: <span id="order-nr">1230008630</span><br/>
<img id="barcode" src="/mnt/hgfs/dev/xt/tmp/var/data/xt_static/barcodes/giftmessagewarning1230008630.png"
    alt="Please contact service desk if this message is displayed instead of a barcode">
</body>
</html>
