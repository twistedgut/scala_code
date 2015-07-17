#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head1 NAME

PrintDoc_Outpro.t

=head1 DESCRIPTION

Test::XTracker::Client sanity check for printdoc:

    printdoc/outpro

=cut

use Test::XTracker::Client::SelfTest;

Test::XTracker::Client::SelfTest->new(
    content    => (join '', (<DATA>)),
    uri        => 'printdoc/outpro-1234.html',
    expected   => {
          'document_heading' => 'NET-A-PORTER.COM',
          'document_title' => 'PROFORMA INVOICE',
          'shipment_details' => {
                "Consignee"    => "eada819 ae6d06",
                "Date"         => "22/12/2010",
                "Fax"          => "",
                "Order Number" => '1001390875',
                "Phone"        => "telephone",
                "Unknown"      => [
                                    "",
                                    "DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU",
                                    "London, W11",
                                    "Norway",
                                    "",
                                  ],
          },
          'shipment_items' => {
                                'total' => '110.00',
                                'items' => [
                                             {
                                               'country' => 'China',
                                               'customs code' => '621210',
                                               'value' => '100.00',
                                               'subtotal' => '100.00',
                                               'type' => 'Lingerie - Bras PID: 32389',
                                               'description' => 'PERSONAL USE 90% polyamide, 10% elastane. Wings: 90% polyamide, 10% elastane. Cup lining: 94% silk, 6% elastane',
                                               'units' => '1'
                                             },
                                             {
                                               'country' => '',
                                               'customs code' => '',
                                               'value' => '10.00',
                                               'subtotal' => '10.00',
                                               'type' => 'Shipping',
                                               'description' => '',
                                               'units' => '1'
                                             }
                                           ]
                              },
          'footer' => ' ALL CURRENCY IN GBP  EXPORT TYPE: Permanent REASON FOR EXPORT : CLOTHING/DDP INCL.VAT AUTHORISATION I declare that the above information is true and correct to the best of my knowledge and that the goods are of the above stated origin(s). For and on behalf of the above named company. ______________________________________________________________ Signature and Position in CompanyDHL Express Airbill Numbernone    1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF VAT REG NO: GB 743 7967 86 NEED HELP? Email customercare@net-a-porter.com or call 0800 044 5700 from the UK or +44 (0) 20 3471 4510 from the rest of the world, 24 hours a day, seven days a week.     '
        }
);

__DATA__




<html>
<head>
<title></title>
<style type="text/css">
<!--
td{font-size:7pt;font-family:arial}
//-->
</style>
<script language="JavaScript">
<!--

//-->
</script>
</head>
<body topmargin=0 leftmargin=0 marginheight=0 marginwidth=0>
<br /><br />
<table cellpadding=0 cellspacing=0 width=635 border=0>

<tr><td align="center" colspan="2"><font face="Arial" size=+1>NET-A-PORTER.COM</font><br>&nbsp;<br>&nbsp;<br>
</td>
</tr>
<tr valign="top">
<td><font face="Arial" size=2><b>

	PROFORMA INVOICE


</b></font></td>
<td align="right">

	<img src="/home/andrew/development/xt/root/static/images/ddpstamp.gif" width="159" height="66">

</td>
</tr>
<tr><td align="center" colspan="2"><br>

&nbsp;<br>
&nbsp;<br></td>
</tr>
</table>
<table cellpadding=0 cellspacing=0 border=0 width=635>
<tr>
<td><font face="Arial" size=-1>Consignee:&nbsp;</font></td>
<td><font face="Arial" size=-1 color="#666666">eada819&nbsp;ae6d06</font></td>
<td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
<td><font face="Arial" size=-1>Order Number:&nbsp;</font></td>
<td><font face="Arial" size=-1 color="#666666">1001390875</font></td>
</tr>

<tr valign="top">
<td><font face="Arial" size=-1>&nbsp;</font></td>
<td></td>
<td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
<td><font face="Arial" size=-1>Date:&nbsp;</font></td>
<td><font face="Arial" size=-1 color="#666666">22/12/2010</font></td>
</tr>
<tr valign="top">
<td><font face="Arial" size=-1>&nbsp;</font></td>
<td><font face="Arial" size=-1 color="#666666">
    DC1, Unit 3, Charlton Gate Business Park, Anchor and Hope Lane, LONDON, SE7 7RU</font></td>
<td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
<td><font face="Arial" size=-1>Phone:&nbsp;</font></td>

<td><font face="Arial" size=-1 color="#666666">telephone</font></td>
</tr>
<tr valign="top">
<td>&nbsp;</td>
<td><font face="Arial" size=-1 color="#666666">London, W11</font></td>
<td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>
<td><font face="Arial" size=-1>Fax:&nbsp;</font></td>
<td><font face="Arial" size=-1 color="#666666"></font></td>
</tr>
<tr valign="top">
<td>&nbsp;</td>
<td><font face="Arial" size=-1 color="#666666">Norway</font></td>
<td width=10><img src="/images/blank.gif" width=10 height=1 border=0></td>

<td>&nbsp;</td>
<td>&nbsp;</td>
</tr>
</table>
&nbsp;<br>
&nbsp;<br>
<table cellpadding=1 cellspacing=0 border=1 width=635 bordercolor="#000000" bordercolordark="#000000" bordercolorlight="#000000">
<tr bgcolor="#000000" valign="bottom">

<td width=30><font face="Arial" size=-3 color="#ffffff">UNITS</font></td>
<td width=100><font face="Arial" size=-3 color="#ffffff">UNIT TYPE</font></td>
<td width=80><font face="Arial" size=-3 color="#ffffff">COUNTRY OF MFG</font></td>
<td width=230><font face="Arial" size=-3 color="#ffffff">COMPLETE DETAILED DESCRIPTION OF GOODS</font></td>

<td width=65 align="center"><font face="Arial" size=-3 color="#ffffff">UNIT VALUE</font></td>
<td width=65 align="center"><font face="Arial" size=-3 color="#ffffff">SUB TOTAL</font></td>
<td width=100><font face="Arial" size=-3 color="#ffffff">CUSTOMS COMMODITY CODE</font></td>
</tr>








	<tr valign="top">

		<td align="center"><font face="Arial" size=-3>1</td>
		<td align="left"><font face="Arial" size=-3>


				Lingerie

					 - Bras



            <br />
            PID: 32389
		</td>
		<td align="left"><font face="Arial" size=-3>China</td>
		<td align="left"><font face="Arial" size=-3>PERSONAL USE 90% polyamide, 10% elastane. Wings: 90% polyamide, 10% elastane. Cup lining: 94% silk, 6% elastane</td>

		<td align="right"><font face="Arial" size=-3>100.00</td>
		<td align="right"><font face="Arial" size=-3>100.00</td>
		<td align="center"><font face="Arial" size=-3>621210</td>
	</tr>










	<tr valign="top">
		<td align="center"><font face="Arial" size=-3>1</td>

		<td align="left"><font face="Arial" size=-3>Shipping</td>
		<td align="left"><font face="Arial" size=-3>&nbsp;</td>
		<td align="left"><font face="Arial" size=-3>&nbsp;</td>
		<td align="right"><font face="Arial" size=-3>10.00</td>
		<td align="right"><font face="Arial" size=-3>10.00</td>
		<td align="center"><font face="Arial" size=-3></td>
	</tr>







	<tr valign="top">
		<td align="right" colspan="5"><font face="Arial" size=-2>TOTAL VALUE: </td>
		<td align="right"><font face="Arial" size=-2><b>110.00</b></td>
		<td></td>
	</tr>
</table>
<br>
<br>

<table cellpadding=0 cellspacing=0 border=0>

<tr>
<td><font face="Arial" size=-1>TOTAL PACKAGES</td><td><font face="Arial" size=-1>:</td><td><font face="Arial" size=-1>0</td>
</tr>
<tr>
<td><font face="Arial" size=-1>TOTAL WEIGHT</td><td><font face="Arial" size=-1>:</td><td><font face="Arial" size=-1>0.0933766528925618&nbsp;kgs.</td>
</tr>
<tr>
<td><font face="Arial" size=-1>TOTAL VOL WEIGHT</td><td><font face="Arial" size=-1>:</td><td><font face="Arial" size=-1>0&nbsp;kgs.</td>

</tr>
</table>
<br>
<font face="Arial" size=-1>

	ALL CURRENCY IN GBP


<br>
EXPORT TYPE: Permanent<br>
<br>
REASON FOR EXPORT :



	CLOTHING/DDP INCL.VAT


<br><br><br>





	<u>AUTHORISATION</u><br>
	<br>
	I declare that the above information is true and correct to the best of my knowledge and that the goods are of the above stated origin(s).<br>
	<br>
	For and on behalf of the above named company.<br>
	<br>

	<br>
	______________________________________________________________<br>
	Signature and Position in Company<br>

	<table cellpadding=0 cellspacing=0 border=0 width=635>
	<tr>
		<td align="right"><font face="Arial" size=-1>DHL Express Airbill Number<br><b>none</b></td>

	</tr>
	</table><br>




<table width=635 border=0 cellpadding=0 cellspacing=0>
    <tr>
        <td><img src="/images/blank.gif" width="1" height="84" border="0"></td>
    </tr>
    <tr>

        <td align="left">
<font face="arial" size=1 color="#000000">
1 THE VILLAGE OFFICES, WESTFIELD LONDON SHOPPING CENTRE, ARIEL WAY, LONDON, W12 7GF

	VAT REG NO: GB 743 7967 86<br>


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

