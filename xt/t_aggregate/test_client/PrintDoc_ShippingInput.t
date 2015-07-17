#!/usr/bin/env perl
use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_ShippingInput.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/shippingform

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/shippingform-2143846.html',
    expected   => {
           document_title => 'SHIPPING INPUT FORM',
            shipment_details => {
              'Box Size(s)' => 'Outer 1',
              'Customer Category' => '-',
              'Customer Number' => '251603',
              'Mobile Telephone' => '',
              'Number of Boxes' => '1',
              'Order Number' => '1001950832',
              'Sales Channel' => 'NET-A-PORTER.COM',
              'Shipment Number' => '2143846',
              'Shipping Account' => 'DHL Express - Domestic',
              'Shipping Details' => 'some one',
              'Shipping Type' => 'Air',
              Telephone => 'telephone',
              Unknown => [
                '',
                'DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU',
                'London',
                '',
                'United Kingdom',
                'W11'
              ]
            },
            shipment_items => {
              grand_total => '241',
              items => [
                {
                  country_of_origin => 'China',
                  description => 'HunterOriginal Tall Wellington boots',
                  fabric_content => 'upper: rubber; inner: fabric; sole: rubber',
                  hs_code => '640192',
                  qty => '1',
                  sku => '34300',
                  sub_total => '100.00',
                  unit_price => '100.00',
                  weight => '2.37896381818182'
                },
                {
                  country_of_origin => 'Italy',
                  description => '7 for all mankindMid-rise skinny jeans',
                  fabric_content => '98% cotton, 2% elastane',
                  hs_code => '620462',
                  qty => '1',
                  sku => '35098',
                  sub_total => '110.00',
                  unit_price => '110.00',
                  weight => '0.509090909090909'
                }
              ],
              shipping => '1.67',
              shipping_tax => '1.67',
              total_price => '210.00',
              total_tax => '21.00',
              total_weight => '2.88805472727273'
            }
        }
);

__DATA__
<html>
<head>
<title></title>
</head>
<body bgcolor="#FFFFFF" TEXT="#000000">



<table border=0 cellspacing=0 cellpadding=0 width=650>
	<tr>
		<td colspan=2 align="center">
			<font face="Arial,Helvetica" size=4 color="#000000">SHIPPING INPUT FORM</font><br>
			<img src="/images/blank.gif" width=500 height=50 border=0>
		</td>
	</tr>
	<tr>
		<td colspan="2">
			<table border=0 cellspacing=0 cellpadding=0 width="100%">
				<tr>
					<td><img src="/home/andrew/development/xt/tmp/var/data/xt_static/barcodes/pickorder2143846.png"></td>
					<td></td>
				</tr>
			</table>
		<br><br>
		</td>
	</tr>
	<tr>
		<td bgcolor="#999999"><img src="/images/blank.gif" width=140 height=1 border=0></td>
		<td bgcolor="#999999"><img src="/images/blank.gif" width=510 height=1 border=0></td>
	</tr>

    <tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Sales Channel:</b></td>
		<td><font face="Arial,Helvetica" size=+1 color="#000000">NET-A-PORTER.COM</td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
    <tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Shipping Account:</b></td>
		<td><font face="Arial,Helvetica" size=+1 color="#000000">DHL Express - Domestic</font></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
    <tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=35 border=0></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>

	<tr height="22">
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Order Number:&nbsp;</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">1001950832</font></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr height="22">
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Shipment Number:&nbsp;</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">2143846</font></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr height="22">
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Customer Number:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">251603</font></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr height="22">
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Customer Category:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">-</font></td>
	</tr>

	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Shipping Details:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">some&nbsp;one</font></td>
	</tr>
	<tr>
		<td></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU</font></td>
	</tr>
	<tr>
		<td></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">London</font></td>
	</tr>
	<tr>
		<td></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000"></font></td>
	</tr>
	<tr>
		<td></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">United Kingdom</font></td>
	</tr>
	<tr>
		<td></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">W11</font></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Telephone:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">telephone</font></td>
	</tr>
	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Mobile Telephone:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000"></font></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Number of Boxes:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">1</font></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Box Size(s):</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">Outer 1&nbsp;</font></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=30 border=0></td>
	</tr>

	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>

	<tr>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Shipping Type:</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">Air</font></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=5 border=0></td>
	</tr>

	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=30 border=0></td>
	</tr>









	<tr>
		<td colspan=2><img src="/images/blank.gif" width=1 height=40 border=0></td>
	</tr>
	<tr valign="top">
		<td colspan=2>
			<font face="Arial,Helvetica" size=2 color="#000000"><b>Shipment Items</b><br>
			<br>
			</font>
		</td>
	</tr>
</table>

<table border=1 cellspacing=0 cellpadding=0 width=650 bordercolor="#000000" bordercolorlight="black"  bordercolordark="#eeeeee">
	<tr bgcolor="#cccccc">
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">SKU</font></td>
		<td><font face="Arial,Helvetica" size=1 color="#000000">DESCRIPTION</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">WEIGHT</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">COUNTRY&nbsp;OF<br>ORIGIN</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">FABRIC<br>CONTENT</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">HS CODE</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">QTY</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">UNIT<br>PRICE</font></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">SUB<br>TOTAL</font></td>
	</tr>




		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">34300</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">Hunter<br>Original Tall Wellington boots</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">2.37896381818182</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">China</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            upper: rubber; inner: fabric; sole: rubber

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">640192</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>



		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">35098</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">7 for all mankind<br>Mid-rise skinny jeans</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">0.509090909090909</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">Italy</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            98% cotton, 2% elastane

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">620462</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">110.00&nbsp;&nbsp;</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">110.00&nbsp;&nbsp;</font></td>
		</tr>







	<tr bgcolor="#ffffff" height="30">
		<td></td>
		<td></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000"><b>2.88805472727273</b></font></td>
		<td colspan="5" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>TOTAL PRICE:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">210.00&nbsp;&nbsp;</font></td>
	</tr>

		<tr bgcolor="#ffffff" height="30">
			<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>TOTAL TAX:&nbsp;</b></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">21.00&nbsp;&nbsp;</font></td>
		</tr>

	<tr bgcolor="#ffffff" height="30">
		<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>SHIPPING:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">8.33&nbsp;&nbsp;</font></td>
	</tr>

		<tr bgcolor="#ffffff" height="30">
			<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>SHIPPING TAX:&nbsp;</b></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">1.67&nbsp;&nbsp;</font></td>
		</tr>


	<tr bgcolor="#ffffff" height="30">
		<td colspan="8" align="right"><font face="Arial,Helvetica" size=2 color="#000000">&nbsp;<b>GRAND TOTAL:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=2 color="#000000">241&nbsp;&nbsp;</font></td>
	</tr>

</table>

</body>
</html>

