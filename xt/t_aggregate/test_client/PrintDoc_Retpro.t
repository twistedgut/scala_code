#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_Retpro.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/retpro

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/retpro-1234.html',
    expected   => {
          'document_heading' => 'theOutnet.com',
          'document_title' => 'RETURNS PROFORMA INVOICE/COMMERCIAL INVOICE',
          'shipment_items' => {
                                'items' => [
                                            {
                                                description => "Catherine Malandrino:Embroidered silk tank, shell: 100% silk, combo: 100% cotton (15854-011)",
                                                gbp_subtotal => "100.00",
                                                gbp_unit_value => "100.00",
                                                hs_code => '620610',
                                                manufacture_country => "China",
                                                net_weight => "0.160kgs",
                                                qty => '1',
                                                tick => "",
                                                usd_subtotal => "177.00",
                                                usd_unit_value => "177.00",
                                            },
                                            {
                                                description => "Vera Wang:Silk-charmeuse shift dress, 100% silk (17284-014)",
                                                gbp_subtotal => "150.00",
                                                gbp_unit_value => "150.00",
                                                hs_code => '620449',
                                                manufacture_country => "United States",
                                                net_weight => "0.200kgs",
                                                qty => '1',
                                                tick => "",
                                                usd_subtotal => "265.50",
                                                usd_unit_value => "265.50",
                                            },
                                           ],
                                'totals' => {
                                                gbp_total => '250.00',
                                                usd_total => '442.50',
                                            }
                              },
          'currency' => 'CURRENCY : GBP',
          'shipment_details' => {
                "Consignee Details" => {
                                        "ADDRESS"         => "UNIT 3, CHARLTON GATE BUSINESS PARKANCHOR AND HOPE LANE, CHARLTONLONDONUNITED KINGDOM",
                                        "COMPANY NAME"    => "theOutnet.com",
                                        "DATE OF INVOICE" => "06/01/2011",
                                        "INVOICE NO."     => "110106-1522335",
                                        "ORDER NO."       => '1001392468',
                                        "POST CODE"       => "SE7 7RU",
                                        "TEL NO."         => "+44 (0) 20 3471 4777",
                                    },
                "Consignor Details" => {
                                        "ADDRESS" => "DC1, Unit 3, Charlton Gate Business ParkAnchor and Hope LaneLONDON, SE7 7RULondonUnited Kingdom",
                                        "INVOICE TO" => "98e15 5408",
                                        "ORIGINAL AIRWAY BILL NO." => '5781828496',
                                        "ORIGINAL DATE SENT" => "06/01/2011",
                                        "POST CODE" => "NW10 4GR",
                                        "RETURN AIRWAY BILL NO." => '6850913348',
                                        "TEL NO." => "telephone",
                                    },
          },
          export_reason => 'REASON FOR EXPORT: British Returned Goods Rejected by Customer',
          footer => ' 1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF  NEED HELP? Email serviceteam@theOutnet.com or call 0800 011 4250 from the UK or +44 (0) 20 3471 4777 from the rest of the world, 8am-8pm GMT, Monday to Friday and 9am-5pm GMT, Saturday to Sunday. ',
        }
);

__DATA__




<html>
<head>
<title></title>
<style type="text/css">
<!--
td{font-size:7pt;font-family:Arial;}
//-->
</style>
</head>
<body topmargin=0 leftmargin=0 marginheight=0 marginwidth=0>
    <table cellpadding=0 cellspacing=0 width=635 border=0>
        <tr>
            <td align="center" colspan="2">
                <font size=+1>theOutnet.com</font><br />&nbsp;<br>&nbsp;<br />
            </td>
        </tr>
        <tr valign="top">
            <td>
                <font size=2><b>RETURNS PROFORMA INVOICE/COMMERCIAL INVOICE</b></font>
            </td>
            <td align="right">
                <img src="/home/andrew/development/xt/tmp/var/data/xt_static/barcodes/proOrder1483789.png" />
            </td>
        </tr>
        <tr>
            <td align="center" colspan="2"><br>&nbsp;<br>&nbsp;<br></td>
        </tr>
    </table>
    <table cellpadding=0 cellspacing=0 border=0 width=635>
        <tr>
            <td colspan=2><font size=-1><b>Consignor Details</b></font></td>
            <td>&nbsp;</td>
            <td colspan=2><font size=-1><b>Consignee Details</b></font></td>
        </tr>
        <tr>
            <td colspan=7><img src="/images/blank.gif" width=1 height=5 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-2>INVOICE TO&nbsp;</font></td>
            <td><font size=-2 color="#666666">98e15&nbsp;5408</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
            <td><font size=-2>COMPANY NAME&nbsp;</font></td>
            <td><font size=-2 color="#666666">theOutnet.com</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr valign="top">
            <td><font size=-2>ADDRESS&nbsp;</font></td>
            <td><font size=-2 color="#666666">
            DC1, Unit 3, Charlton Gate Business Park<br />Anchor and Hope Lane<br />LONDON, SE7 7RU<br />London<br />United Kingdom
            </font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>ADDRESS&nbsp;</font></td>
            <td><font size=-2 color="#666666">UNIT 3, CHARLTON GATE BUSINESS PARK<br>ANCHOR AND HOPE LANE, CHARLTON<br>LONDON<br>UNITED KINGDOM</font></td>
        </tr>
        <tr valign="top">
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-2>POST CODE&nbsp;</font></td>
            <td><font size=-2 color="#666666">NW10 4GR</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>POST CODE&nbsp;</font></td>
            <td><font size=-2 color="#666666">SE7 7RU</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr valign="top">
            <td><font size=-2>TEL NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">
            telephone<br />
            </font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>TEL NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">+44 (0) 20 3471 4777</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr colspan=5>
            <td>&nbsp;<br>&nbsp;<br></td>
        </tr>
        <tr>
            <td><font size=-2>ORIGINAL DATE SENT&nbsp;</font></td>
            <td><font size=-2 color="#666666">06/01/2011</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>DATE OF INVOICE&nbsp;</font></td>
            <td><font size=-2 color="#666666">06/01/2011</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-2>ORIGINAL AIRWAY BILL NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">5781828496</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>INVOICE NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">110106-1522335</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-2>RETURN AIRWAY BILL NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">6850913348</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>ORDER NO.&nbsp;</font></td>
            <td><font size=-2 color="#666666">1001392468</font></td>
        </tr>
        <tr>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
            <td colspan=2 bgcolor="#666666"><img src="/images/blank.gif" width=1 height=1 border=0 /></td>
        </tr>
    </table>
    &nbsp;<br>
    &nbsp;<br>
    <font face="Arial" size=-3><b>Tick Item(s) Being Returned</b></font>
    <table cellpadding=1 cellspacing=0 border=1 width=635 bordercolor="#000000" bordercolordark="#000000" bordercolorlight="#000000">
        <tr bgcolor="#000000" valign="bottom">
            <td><font size=-3 color="#ffffff">TICK</font></td>
            <td width=160><font size=-3 color="#ffffff">FULL DESCRIPTION OF GOODS<br>INCLUDING FABRICATION</font></td>
            <td align="center"><font size=-3 color="#ffffff">QTY</font></td>

            <td width=65 align="center"><font size=-3 color="#ffffff">UNIT VALUE<br>GBP</font></td>

            <td width=65 align="center"><font size=-3 color="#ffffff">UNIT VALUE<br>USD</font></td>

            <td align="center"><font size=-3 color="#ffffff">SUBTOTAL<br>GBP</font></td>

            <td align="center"><font size=-3 color="#ffffff">SUBTOTAL<br>USD</font></td>
            <td width=55 align="center"><font size=-3 color="#ffffff">UNIT NET<br>WEIGHT</font></td>
            <td align="center"><font size=-3 color="#ffffff">COUNTRY OF<br>MANUFACTURE</font></td>
            <td align="center"><font size=-3 color="#ffffff">HS CODE</font></td>
        </tr>








                <tr valign="top">
                    <td>&nbsp;</td>
                    <td><font size=-3>Catherine Malandrino:Embroidered silk tank, shell: 100% silk, combo: 100% cotton (15854-011)</td>
                    <td align="center"><font size=-3>1</td>
                    <td align="right"><font size=-3>100.00</td>

                    <td align="right"><font size=-3>177.00</td>

                    <td align="right"><font size=-3>100.00</td>

                    <td align="right"><font size=-3>177.00</td>

                    <td align="right"><font size=-3>0.160kgs</td>
                    <td align="center"><font size=-3>China</td>
                    <td align="center"><font size=-3>620610</td>
                </tr>






                <tr valign="top">
                    <td>&nbsp;</td>
                    <td><font size=-3>Vera Wang:Silk-charmeuse shift dress, 100% silk (17284-014)</td>
                    <td align="center"><font size=-3>1</td>
                    <td align="right"><font size=-3>150.00</td>

                    <td align="right"><font size=-3>265.50</td>

                    <td align="right"><font size=-3>150.00</td>

                    <td align="right"><font size=-3>265.50</td>

                    <td align="right"><font size=-3>0.200kgs</td>
                    <td align="center"><font size=-3>United States</td>
                    <td align="center"><font size=-3>620449</td>
                </tr>







        <tr>
            <td>&nbsp;</td>
            <td colspan=2><font size=-3>TOTAL NUMBER OF PARCELS : 1</td>
            <td colspan=2 align="right"><font size=-3>TOTAL VALUE :&nbsp;&nbsp;</td>




                <td align="right"><font size=-3>&pound;250.00</td>
                <td align="right"><font size=-3>$442.50</td>



            <td colspan=3 align="right"><font size=-3>TOTAL NET WEIGHT: 0.360kgs</td>
        </tr>
    </table>
    &nbsp;<br>
    <table cellpadding=0 cellspacing=0 border=0 width=635>
        <tr>
            <td><font size=-2>TERMS OF DELIVERY&nbsp;:&nbsp;DDU</font></td>
            <td width=10><img src="/images/blank.gif" width=10 height=1 border=0 /></td>
            <td><font size=-2>CURRENCY&nbsp;:&nbsp;GBP</font></td>
        </tr>
    </table>
    <table cellpadding=0 cellspacing=0 border=0 width=635>
        <tr>
            <td><font size=-2>&nbsp;<br>REASON FOR EXPORT:
                British Returned Goods Rejected by Customer</font>
            </td>
        </tr>
        <tr>
            <td><img src="/images/blank.gif" width=1 height=15 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-1>
                    <b>RMA Number</b>&nbsp;<img align="absmiddle" src="/images/blank.gif" width=200 height=20 border=1 /></font>
            </td>
        </tr>
        <tr>
            <td><img src="/images/blank.gif" width=1 height=15 border=0 /></td>
        </tr>
        <tr>
            <td><font size=-2>I DECLARE THAT THE ABOVE INFORMATION IS TRUE AND CORRECT TO THE BEST OF MY KNOWLEDGE.</font></td>
        </tr>
        <tr>
            <td><font size=-2>&nbsp;<br></font></td>
        </tr>
    </table>
    <table cellpadding=0 cellspacing=0 border=0 width=635>
        <tr>
            <td><font size=-1><b>Sign Here</b>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; </font><img align="absmiddle" src="/images/blank.gif" width=200 height=20 border=1 /></td>
            <td width=5><img src="/images/blank.gif" width=5 height=1 border=0 /></td>
            <td><font size=-1><b>Print Name</b> </font><img align="absmiddle" src="/images/blank.gif" width=200 height=20 border=1 /></td>
        </tr>
    </table>

    <table width=635 border=0 cellpadding=0 cellspacing=0>
    <tr>
        <td><img src="/images/blank.gif" width="1" height="200" border="0"></td>
    </tr>
    <tr>
        <td align="left">
<font face="arial" size=1 color="#000000">
1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF

<br/>
<br/>
NEED HELP? Email serviceteam@theOutnet.com or call

    0800 011 4250 from the UK or +44 (0) 20 3471 4777 from the rest of the world, 8am-8pm GMT, Monday to Friday and 9am-5pm GMT, Saturday to Sunday.

</font>
        </td>
    </tr>
</table>


</body>
</html>
