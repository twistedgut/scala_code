#!/usr/bin/env perl
use NAP::policy "tt", 'test';

use FindBin::libs;

=head1 NAME

PrintDoc_ShipmentList.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/shippinglist

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/shippinglist',
    expected   => {
    'metadata' => {
                    'Number of Boxes' => '1',
                    'Shipping Details' => 'a6cb 8f2d5
DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU
London
United Kingdom
W11',
                    'Shipping Account' => 'DHL Express - Domestic',
                    'Customer Category' => '-',
                    'Telephone' => 'telephone',
                    'Shipment Number' => '1324728',
                    'Sales Channel' => 'NET-A-PORTER.COM',
                    'Box Size(s)' => 'Unknown',
                    'Order Number' => '1001253732',
                    'Shipping Type' => 'Air',
                    'Customer Number' => '251603'
                  },
    'items' => [
                 {
                   'Product ID' => '77871',
                   'Weight' => '0.0921923636363636',
                   'Subtotal' => '100.00',
                   'Country' => 'Austria',
                   'Fabric' => '72% Nylon, 25% Elastane, 3% Cotton',
                   'HS Code' => '620892',
                   'Unit Price' => '100.00',
                   'Quantity' => '1',
                   'Description' => 'WolfordVelvet Control thong'
                 },
                 {
                   'Product ID' => '96721',
                   'Weight' => '0.605',
                   'Subtotal' => '100.00',
                   'Country' => 'United States',
                   'Fabric' => '100%silk',
                   'HS Code' => '620449',
                   'Unit Price' => '100.00',
                   'Quantity' => '1',
                   'Description' => 'Jason WuSilk-crepe sheath dress'
                 },
                 {
                   'Product ID' => '94600',
                   'Weight' => '1.978',
                   'Subtotal' => '100.00',
                   'Country' => 'Italy',
                   'Fabric' => '100% leather',
                   'HS Code' => '640399',
                   'Unit Price' => '100.00',
                   'Quantity' => '1',
                   'Description' => 'FendiOver-the-knee suede boots'
                 },
                 {
                   'Product ID' => '96462',
                   'Weight' => '0.392819636363636',
                   'Subtotal' => '100.00',
                   'Country' => 'Romania',
                   'Fabric' => '23%arcylic,22%nylon,20%wool,20%mohalr;15%viscose',
                   'HS Code' => '611030',
                   'Unit Price' => '100.00',
                   'Quantity' => '1',
                   'Description' => 'See by ChloÃ©Long mohair-blend cardigan'
                 },
                 {
                   'Product ID' => '96720',
                   'Weight' => '0.352',
                   'Subtotal' => '100.00',
                   'Country' => 'United States',
                   'Fabric' => '100%silk',
                   'HS Code' => '620449',
                   'Unit Price' => '100.00',
                   'Quantity' => '1',
                   'Description' => 'Jason WuSilk leaf-print sheath dress'
                 }
               ]
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
					<td><img src="/var/data/xt_static/barcodes/pickorder1324728.png"></td>
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
		<td><font face="Arial,Helvetica" size=-1 color="#000000">1001253732</font></td>
	</tr>
	<tr>
		<td colspan=2 bgcolor="#999999"><img src="/images/blank.gif" width=1 height=1 border=0></td>
	</tr>
	<tr height="22">

		<td><font face="Arial,Helvetica" size=-1 color="#000000">&nbsp;<b>Shipment Number:&nbsp;</b></td>
		<td><font face="Arial,Helvetica" size=-1 color="#000000">1324728</font></td>
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

		<td><font face="Arial,Helvetica" size=-1 color="#000000">a6cb&nbsp;8f2d5</font></td>
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
		<td><font face="Arial,Helvetica" size=-1 color="#000000">Unknown&nbsp;</font></td>
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
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">77871</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">Wolford<br>Velvet Control thong</font></td>

			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">0.0921923636363636</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">Austria</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            72% Nylon, 25% Elastane, 3% Cotton

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">620892</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>

			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>



		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">96721</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">Jason Wu<br>Silk-crepe sheath dress</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">0.605</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">United States</font></td>

			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            100%silk

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">620449</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>




		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">94600</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">Fendi<br>Over-the-knee suede boots</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1.978</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">Italy</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            100% leather

            </font></td>

			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">640399</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>



		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">96462</font></td>

			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">See by ChloÃ©<br>Long mohair-blend cardigan</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">0.392819636363636</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">Romania</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            23%arcylic,22%nylon,20%wool,20%mohalr;15%viscose

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">611030</font></td>

			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>



		<tr bgcolor="#eeeeee" height="40">
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">96720</font></td>
			<td width="145"><font face="Arial,Helvetica" size=1 color="#000000">Jason Wu<br>Silk leaf-print sheath dress</font></td>

			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">0.352</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">United States</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">
            100%silk

            </font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">620449</font></td>
			<td align="center"><font face="Arial,Helvetica" size=1 color="#000000">1</font></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>

			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">100.00&nbsp;&nbsp;</font></td>
		</tr>







	<tr bgcolor="#ffffff" height="30">
		<td></td>
		<td></td>
		<td align="center"><font face="Arial,Helvetica" size=1 color="#000000"><b>3.420012</b></font></td>
		<td colspan="5" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>TOTAL PRICE:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">500.00&nbsp;&nbsp;</font></td>
	</tr>


		<tr bgcolor="#ffffff" height="30">
			<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>TOTAL TAX:&nbsp;</b></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">0.00&nbsp;&nbsp;</font></td>
		</tr>

	<tr bgcolor="#ffffff" height="30">
		<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>SHIPPING:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">8.51&nbsp;&nbsp;</font></td>
	</tr>


		<tr bgcolor="#ffffff" height="30">
			<td colspan="8" align="right"><font face="Arial,Helvetica" size=1 color="#000000">&nbsp;<b>SHIPPING TAX:&nbsp;</b></td>
			<td align="right"><font face="Arial,Helvetica" size=1 color="#000000">1.49&nbsp;&nbsp;</font></td>
		</tr>


	<tr bgcolor="#ffffff" height="30">
		<td colspan="8" align="right"><font face="Arial,Helvetica" size=2 color="#000000">&nbsp;<b>GRAND TOTAL:&nbsp;</b></td>
		<td align="right"><font face="Arial,Helvetica" size=2 color="#000000">510&nbsp;&nbsp;</font></td>
	</tr>

</table>

</body>
</html>


