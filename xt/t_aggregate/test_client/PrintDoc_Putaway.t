#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_Putaway.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/putaway

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    spec       => 'printdoc/putaway',
    expected   => {
        'metadata' => {
            'delivery_number'   => '615019',
            'process_group_id'  => '844284',
            'page_type'         => 'Surplus',
            'Designer'          => 'Rows',
            'Description'       => 'New Description',
            'Colour'            => 'Black',
            'Sales Channel'     => 'MRPORTER.COM'
        },
        'item_list' => [
            {
                'Size' => 'None/Unknown',
                'SKU' => '2106034-001'
            }
        ]
    }
);

__DATA__
<html>
<head>
<title></title>
<meta http-equiv=content-type content="text/html; charset=utf8">
</head>
<body>
<font face="arial">
<table cellspacing="0" cellpadding="0" width="650" border="0">
    <tbody>
    <tr valign="top">
    <td><h1>Putaway Sheet</h1><h4>Printed: 30-09-2010 10:03</h4><br></td>

    <td align="right">
    <table width="200" border="3" cellpadding="5" cellspacing="0" bordercolor="#000000" style="border-style:solid">
    <tr>
    <td align="center"><h1>Goods In</h1></td>
    </tr>
    <tr>
    <td align="center"><h1>Surplus</h1></td>
    </tr>

                <tr>
                    <td align="center"><h1>Flat</h1></td>
                </tr>
    </table>
    </td>
    </tr>
    <tr>
    <td align="left"><br><h2><b>Delivery Number: 615019</b></h2></p></td>

    <td align="right"><br><h2><b>Process Group ID: 844284</b></h2></p></td>
    </tr>
    <tr>
    <td align="left"><img src="/var/data/xt_static/barcodes/delivery-615019.png"><br><br></td>
<td align="right"><img src="/var/data/xt_static/barcodes/sub_delivery-844284.png"><br><br></td>
</tr>
</tbody>
</table>
<br><br>


<table width="650" border="2" cellpadding="10" cellspacing="0" bordercolor="#000000" style="border-style:solid">
    <tbody>
    <tr>
    <td>
            <b>Sales Channel:</b> MRPORTER.COM
    </td>
    </tr>
    <tr>

    <td>
            <b>Designer:</b> Rows
    </td>
    </tr>
    <tr>
    <td>
            <b>Description:</b> New Description
    </td>

    </tr>
    <tr>
    <td>
            <b>Colour:</b> Black
    </td>
    </tr>
</table>

<br />
<br />

<table cellspacing="0" cellpadding="0" width="650" bgcolor="#f2f2f2" border="0">
    <tbody>
    <tr height="24" bgcolor="#c5c5c5">
    <td><b>&nbsp;&nbsp;SKU&nbsp;&nbsp;</b></td>
    <td><b>&nbsp;&nbsp;Size&nbsp;&nbsp;</b></td>
    </tr>


    <tr>
    <td bgcolor="#f2f2f2" colspan="6" height=10>&nbsp;</td>

    </tr>
    <tr>
    <td>&nbsp;&nbsp;<font size="3">2106034-001&nbsp;&nbsp;&nbsp;&nbsp;</font></td>
    <td><font size="2">None/Unknown</font></td>
    </tr>
    <tr>
    <td bgcolor="#f2f2f2" colspan="6" height=10>&nbsp;</td>
    </tr>

    <tr>
    <td colspan="6" bgcolor="#c2c2c2" height=1></td>
    </tr>

    </tbody>
</table>
</body>
</html>

