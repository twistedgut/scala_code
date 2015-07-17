#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_Invoice.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/invoice

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/invoice-1234.html',
    expected   => {
        'document_heading' => 'NET-A-PORTER.COM',
        'document_title' => 'INVOICE',
        'shipment_items' => {
            items  => [
                        {
                          description => "Hunter Original Tall Wellington boots",
                          duties => "0.00",
                          price => "150.00",
                          qty => '1',
                          unit_price => "100.00",
                          vat => "50.00",
                          vat_rate => "0.00%",
                        },
                      ],
            totals => {
                        "GRAND TOTAL" => "160.00",
                        "SHIPPING"    => "10.00",
                        "TOTAL PRICE" => "150.00",
                      },
        },
        'invoice_details' => {
            overview  => {
                    "Customer Number" => '9682',
                    "Invoice Date"    => "09/08/2011",
                    "Invoice Number"  => "110809-2087334",
                    "Order Number"    => '1001810427',
                    "Shipment Number" => '1969050',
            },
            addresses => {
                    deliver_to => {
                                 "ADDRESS"    => "DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU",
                                 "CITY"       => "London",
                                 "COUNTRY"    => "Malawi",
                                 "DELIVER TO" => "some one",
                                 "POST CODE"  => "W11",
                               },
                    invoice_to => {
                                 "ADDRESS"    => "DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU",
                                 "CITY"       => "London",
                                 "COUNTRY"    => "Malawi",
                                 "INVOICE TO" => "some one",
                                 "POST CODE"  => "W11",
                               },
                },
        },
        'duties_and_taxes' => 'DUTIES & TAXES INFORMATION:This shipment includes prepaid Customs duties and Sales taxes (when applicable)for the merchandise to be delivered to the address in the country specified by the customer. NET-A-PORTER.COM pays these charges on behalf of the customer. Should you ever receive a demand for payment of such taxes or duties from either our shipper or from any customs authorities, please contact us immediately on shipping@net-a-porter.com, as you are not required to pay this.',
        'footer' => ' 1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF  NEED HELP? Email customercare@net-a-porter.com or call 0800 044 5700 from the UK or +44 (0) 20 3471 4510 from the rest of the world, 24 hours a day, seven days a week. ',
    }
);

__DATA__
<html>
<head>
<title></title>
</head>
<body bgcolor="#FFFFFF" text="#000000">

<table border=0 cellspacing=0 cellpadding=0 width=570>
    <tr>
        <td colspan=5 align="center">

            <font face="Arial,Helvetica" size=4 color="#000000">NET-A-PORTER.COM</font><br>

            <img src="/images/blank.gif" width=570 height=50 border=0>
        </td>
    </tr>
    <tr valign="top">
        <td colspan=3>
            <font face="Arial,Helvetica" size=2 color="#000000"><b>INVOICE</b><br>

            <br>
            </font>
        </td>

            <td colspan=2><font face="arial,helvetica" size=2>&nbsp;</font></td>

    </tr>
    <tr>
        <td colspan=5>
            <font face="Arial,Helvetica" size=-1 color="#000000"><b>Invoice Number:&nbsp;</b>110809-2087334</font><br>
            <font face="Arial,Helvetica" size=-1 color="#000000"><b>Invoice Date:&nbsp;</b>09/08/2011</font><br>
            <br>
        </td>
    </tr>
    <tr height="16">
        <td colspan=2>
            <font face="Arial,Helvetica" size=1 color="#000000">INVOICE TO</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;some&nbsp;one</font>
        </td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2><font face="Arial,Helvetica" size=1 color="#000000">DELIVER TO</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;some&nbsp;one</font></td>
    </tr>
    <tr>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
    </tr>
    <tr height="16">
        <td colspan=2> <font face="Arial,Helvetica" size=1 color="#000000">ADDRESS</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU</font></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2> <font face="Arial,Helvetica" size=1 color="#000000">ADDRESS</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU</font></td>
    </tr>
    <tr>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
    </tr>
    <tr height="16">
        <td colspan=2> <font face="Arial,Helvetica" size=1 color="#000000">CITY</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;London</font></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2> <font face="Arial,Helvetica" size=1 color="#000000">CITY</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;London</font></td>
    </tr>
    <tr>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
    </tr>
    <tr height="16">
        <td width=130> <font face="Arial,Helvetica" size=1 color="#000000">POST CODE</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;W11</font></td>
        <td width=150> <font face="Arial,Helvetica" size=1 color="#000000">COUNTRY</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;Malawi</font></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=130> <font face="Arial,Helvetica" size=1 color="#000000">POST CODE</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;W11</font></td>
        <td width=150> <font face="Arial,Helvetica" size=1 color="#000000">COUNTRY</font><font face="Arial" size=1 color="#666666">&nbsp;&nbsp;Malawi</font></td>
    </tr>
    <tr>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
        <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=280 height=1 border=0></td>
    </tr>
</table>

<table width="600">
    <tr>
        <td colspan=2>
            <font face="Arial,Helvetica" size=-1 color="#000000"><b><br><br>Order Number:</b> 1001810427<br>
            <b>Shipment Number:</b> 1969050<br>
            <b> Customer Number:</b> 9682</font><br><br>
        </td>
    </tr>
</table>

<table border=0 cellspacing=0 cellpadding=1 width=570 >
    <tr bgcolor="black">
        <td width=25 align="center" bgcolor="black">&nbsp;</td>
        <td width=220 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">DESCRIPTION</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">QUANTITY</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">UNIT PRICE</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">VAT RATE</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">VAT</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">DUTIES</font></td>
        <td width=65 bgcolor="black" align="center"><font face="Arial,Helvetica" size=1 color="#FFFFFF">PRICE</font></td>
    </tr>
</table>

<table border=1 cellspacing=0 cellpadding=1 width=570 bordercolor="#000000" bordercolorlight="black"  bordercolordark="white">




    <tr>
        <td width=25  align="right"><font face="Arial,Helvetica" size=1 color="#000000">1</font><img src="/images/blank.gif" width=4 height=1 border=0></td>
        <td width=220 align="center"><font face="Arial,Helvetica" size=1 color="#000000">Hunter Original Tall Wellington boots</td>
        <td width=65  align="right"><font face="Arial,Helvetica" size=1 color="#000000">1</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=65  align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=65  align="right"><font face="Arial,Helvetica" size=1 color="#000000">0.00%</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=65  align="right"><font face="Arial,Helvetica" size=1 color="#000000">50.00</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=65  align="right"><font face="Arial,Helvetica" size=1 color="#000000">0.00</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
        <td width=65  align="right" ><font face="Arial,Helvetica" size=1 color="#000000">150.00</font><img src="/images/blank.gif" width=10 height=1 border=0></td>
    </tr>



</table>





<table border=0 cellspacing=0 cellpadding=0 width=570>
    <tr>
        <td colspan=2><img src="/images/blank.gif" width=1 height=1 border=0></td>
    </tr>
    <tr>
        <td width=475 align="right"><font face="Arial,Helvetica" size=1 color="#000000">TOTAL PRICE</font></td>
        <td width=30>&nbsp;</td>
        <td width=65 align="right"><font face="Arial" size=1 color="#666666">&#163; 150.00</font></td>
    </tr>
    <tr>
        <td width=505></td>
        <td></td>
        <td width=65 bgcolor="#999999"><img src="/images/linepixel.gif" width=65 height=1 border=0></td>
    </tr>
    <tr>
        <td align="right"><font face="Arial,Helvetica" size=1 color="#000000">SHIPPING</font></td>
        <td>&nbsp;</td>
        <td width=65 align="right"><font face="Arial" size=1 color="#666666">&#163; 10.00</font></td>
    </tr>
    <tr>
        <td width=505></td>
        <td></td>
        <td width=65 bgcolor="#999999"><img src="/images/linepixel.gif" width=65 height=1 border=0></td>
    </tr>









    <tr>
        <td align="right"><font face="Arial,Helvetica" size=1 color="#000000">GRAND TOTAL</font></td>
        <td></td>
        <td width=65 align="right"><font face="Arial" size=1 color="#666666">&#163; 160.00</font></td>
    </tr>
    <tr>
        <td width=505></td>
        <td></td>
        <td width=65 bgcolor="#999999"><img src="/images/linepixel.gif" width=65 height=1 border=0></td>
    </tr>
    <tr>
        <td colspan=3>
            <img src="/images/blank.gif" width=570 height=10 border=0><br>
            <font face="Arial,Helvetica" size=1 color="#000000">Thank you for shopping at NET-A-PORTER.COM</font>
        </td>
    </tr>
</table>




    <table width=600 border=0 cellpadding=0 cellspacing=0>
        <tr>
            <td><img src="/images/blank.gif" width=1 height=164 border=0></td>
        </tr>
        <tr>
            <td align="center">
                <font face="Arial,Helvetica" size=1 color="#000000">DUTIES & TAXES INFORMATION:<br>This shipment includes prepaid Customs duties and Sales taxes (when applicable)<br>for the merchandise to be delivered to the address in the country specified by the customer.<br>
                &nbsp;<br>



                <br>NET-A-PORTER.COM pays these charges on behalf of the customer.<br>
                &nbsp;<br>
                Should you ever receive a demand for payment of such taxes or duties from either our shipper or from any customs authorities, please contact us immediately on shipping@net-a-porter.com, as you are not required to pay this.</font>
            </td>
        </tr>
    </table>


<br>

<table width=635 border=0 cellpadding=0 cellspacing=0>
    <tr>
        <td><img src="/images/blank.gif" width="1" height="30" border="0"></td>
    </tr>
    <tr>
        <td align="left">
<font face="arial" size=1 color="#000000">
1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF

<br/>
<br/>
NEED HELP? Email customercare@net-a-porter.com or call

    0800 044 5700 from the UK or +44 (0) 20 3471 4510 from the rest of the world, 24 hours a day, seven days a week.

</font>
        </td>
    </tr>
</table>


</body>
</html>
