#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_PickingList.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/pickinglist

=cut

use Test::XTracker::Client::SelfTest;

# create anonymous sub for this function
# because when run as an aggregate test
# any functions called the same will
# throw re-defined errors
my $fix_location = sub {
    my $location = shift;
    return Test::XTracker::Client::SelfTest
        ->_xclient_translate_location( $location );
};

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/pickinglist',
    expected   => {
        'shipment_data' => {
             'Printed Date' => '18-8-2010 16:12',
             'Customer Number' => '251603',
             'Customer Name' => 'a6cb 8f2d5',
             'Shipment Date' => '18-08-2010 15:12',
             'Shipment Number' => '1308212',
             'SLA Cut-Off' => '19-08-2010 03:12'
                       },
        'item_list' => [
             {
               'Size' => '999',
               'Designer' => 'Gift Card',
               'Location' => $fix_location->('2-J-294-B'),
               'Display Location' => '2-J-294-B',
               'Name' => 'Test Voucher 2106069 31843 1282144301.18957',
               'Colour' => 'Unknown',
               'SKU' => '2106069-999'
             },
             {
               'Size' => 'x small',
               'Designer' => 'Wolford',
               'Location' => 'Invar',
               'Display Location' => 'Invar',
               'Name' => 'Velvet Control thong',
               'Colour' => 'Black',
               'SKU' => '77871-011'
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
<table cellspacing="0" cellpadding="0" width="600" border="0">
	<tbody>
	<tr valign="top">
		<td width="300">
            <h1>Picking List</h1>

            <h4>Printed: 18-8-2010 16:12</h4>
            <br />
            <br />
            <h3><b>Shipment Number:&nbsp;&nbsp;1308212</b></h3>
            <img src="/var/data/xt_static/barcodes/pickorder1308212.png">
        </td>
		<td align="right">

			<table width="300" border="3" cellpadding="5" cellspacing="0" bordercolor="#000000" style="border-style:solid">
				<tr>
					<td align="center"><h1>NET-A-PORTER.COM</h1></td>
				</tr>
                <tr>
					<td align="center"><h2>CUSTOMER ORDER<!-- shipment type - CUSTOMER ORDER, EIP ORDER, SALE ORDER, SAMPLE ORDER, STOCK TRANSFER --></h2></td>
				</tr>
				<tr>

					<td align="center"><h2>Express</h2></td>
				</tr>

				<tr>
					<td align="center"><br><h1>GIFT</h1></td>
				</tr>


			</table>
		</td>
	</tr>

	<tr>
		<td colspan="2" align="left">
			<br>
			<table cellspacing="0" cellpadding="4" width="640" border="0">
				<tr>
					<td width="120" align="right"><font size="2"><b>Shipment Date:</b></font></td>
					<td width="160"><font size="2">18-08-2010  15:12</font></td>
					<td><font size="2">&nbsp;&nbsp;&nbsp;&nbsp;</font></td>

					<td width="130" align="right"><font size="2"><b>Customer No:</b></font></td>
					<td width="200"><font size="2">251603</font></td>
				</tr>
				<tr>
					<td align="right"><font size="2"><b>Release Date:</b></font></td>
					<td><font size="2"></font></td>
					<td><font size="2">&nbsp;&nbsp;&nbsp;&nbsp;</font></td>

					<td align="right"><font size="2"><b>Customer Name:</b></font></td>
					<td><font size="5"><b>a6cb 8f2d5</b></font></td>
				</tr>
                                <tr>
                                    <td align="right"><font size="2"><b>SLA Cut-Off:</b></font></td>
                                    <td><font size="2">19-08-2010  03:12</font></td>
                                </tr>
			</table>
		</td>
	</tr>
	</tbody>
</table>

<br>

<table width="640" border="2" cellpadding="10" cellspacing="0" bordercolor="#000000" style="border-style:solid">
	<tbody>
	<tr valign="top">
        <td width="15%" class=tableheader><b>&nbsp;Notes</b></td>
		<td width="85%"><br>

		</td>
	</tr>
</table>

 <br><br><br>



<table cellspacing="0" cellpadding="0" width="700" bgcolor="#f2f2f2" border="0">
	<tbody>
	<tr height="24" bgcolor="#c5c5c5">
		<td><b>&nbsp;&nbsp;Location&nbsp;&nbsp;</b></td>
		<td><b>&nbsp;&nbsp;SKU&nbsp;&nbsp;</b></td>
		<td>&nbsp;&nbsp;</td>
		<td><b>&nbsp;Name&nbsp;&nbsp;</b></td>

		<td>&nbsp;&nbsp;</td>
		<td><b>&nbsp;&nbsp;Designer&nbsp;&nbsp;</b></td>
		<td><b>&nbsp;&nbsp;Size&nbsp;&nbsp;</b></td>
		<td><b>&nbsp;&nbsp;Colour&nbsp;&nbsp;</b></td>
	</tr>










				<tr>
					<td bgcolor="#f2f2f2" colspan=8 height=10></td>

				</tr>
				<tr>
					<td>&nbsp;&nbsp;<font size="2">2-J-294-B&nbsp;&nbsp;&nbsp;&nbsp;</font></td>
					<td><font size="3">&nbsp;&nbsp;2106069-999</font></td>
					<td>&nbsp;&nbsp;</td>
					<td><font size="2">Test Voucher 2106069 31843 1282144301.18957</font></td>
					<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>

					<td><font size="2">Gift Card</font></td>
					<td>&nbsp;&nbsp;<font size="2">999</font></td>
					<td>&nbsp;&nbsp;<font size="2">Unknown</font></td>
				</tr>
				<tr>
					<td bgcolor="#f2f2f2" colspan=8 height=10></td>
				</tr>

				<tr>
					<td colspan=8 bgcolor="#c2c2c2" height=1></td>
				</tr>













				<tr>
					<td bgcolor="#f2f2f2" colspan=8 height=10></td>
				</tr>
				<tr>
					<td>&nbsp;&nbsp;<font size="2">Invar&nbsp;&nbsp;&nbsp;&nbsp;</font></td>
					<td><font size="3">&nbsp;&nbsp;77871-011</font></td>

					<td>&nbsp;&nbsp;</td>
					<td><font size="2">Velvet Control thong</font></td>
					<td>&nbsp;&nbsp;&nbsp;&nbsp;</td>
					<td><font size="2">Wolford</font></td>
					<td>&nbsp;&nbsp;<font size="2">x small</font></td>
					<td>&nbsp;&nbsp;<font size="2">Black</font></td>
				</tr>

				<tr>
					<td bgcolor="#f2f2f2" colspan=8 height=10></td>
				</tr>
				<tr>
					<td colspan=8 bgcolor="#c2c2c2" height=1></td>
				</tr>







	</tbody>
</table>
</body>
</html>
