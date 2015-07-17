#!/opt/xt/xt-perl/bin/perl 
## no critic(ProhibitExcessMainComplexity,ProhibitUselessNoCritic)
use strict;
use warnings;
use DBI;
use Symbol;
use Data::Dumper;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw(get_database_handle);

my $dbh = get_database_handle( { name => 'XTracker_DC1', type => 'readonly' } );

my ($sth, $notesProduct, $designer1, $numP, %replacement,$notes_ids);

my $HTML_OUT_DIR = '/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration';

$sth = $dbh->prepare("select distinct notes_id from notes_product");
$sth->execute();
$notes_ids = $sth->fetchall_arrayref();

foreach my $id (@$notes_ids) {

    $sth = $dbh->prepare("
    SELECT np.product_id, d.designer, np.product_name, round(np.price_gbp) as price_gbp, round(np.price_eur) as price_eur, round(np.price_usd) as price_usd, pc.live, pc.visible, CASE WHEN d.designer LIKE '3.1 %' THEN replace(d.designer, '3.1 ', '') WHEN d.designer ~ 'Chlo' THEN substring(d.designer, '^(.*Chlo)')||'e' ELSE d.designer END as sort_by_designer
      FROM notes_product np, product p, product_channel pc, designer d
     WHERE notes_id = '$id->[0]' and np.product_id = p.id and p.designer_id = d.id and p.id = pc.product_id and pc.channel_id = 1
     ORDER BY 9, np.product_id
     ");

    $sth->execute();
    $notesProduct = $sth->fetchall_arrayref({});

    $dbh->do("UPDATE notes_product_lastupdate SET last_update=now()");
    #$dbh->disconnect();

    #
    # Write html to file
    #

    %replacement = ( ' ', '_', '&', 'and', '\'', '_', '-', '_');

    ($designer1 = $notesProduct->[0]->{designer}) =~ s/([\s&'\-])/$replacement{$1}/g;
    $numP = scalar @$notesProduct;


    my $filename = "notes$id->[0]";

    if ($id->[0] =~ /\D/) {
        ($filename = lc "$id->[0]") =~ s/\s/_/g;
    }

    $filename .= '_intl_product_list';

    open (my $HTML, ">", "$HTML_OUT_DIR/$filename.html") or die "Can't open file for writing: $!\n";

    print $HTML << "EOT";
<html>
<head><meta http-equiv="Content-Type" content="text/html; charset=UTF-8"></head>
<link rel='stylesheet' type='text/css'>
<style>

tr.product {height:20px}
td {font-family: Verdana, Arial, Helvetica, sans-serif;font-size: 9px; text-transform: uppercase;}
a {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    color: #000000;
    text-decoration: none;
    font-weight: bold;
}
a:hover {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    color: #000000;
    text-decoration: underline;
    font-weight: bold;
}
a:active {
    font-family: Verdana, Arial, Helvetica, sans-serif;
    color: #000000;
    text-decoration: none;
    font-weight: bold;
}

.designer {font-family: Arial, Helvetica, sans-serif;font-size: 12px;font-weight: bold;text-transform: uppercase;}

</style>
<script>

function clickOn(id) {
    top.location.href = "/product/" + id;
}

</script>
<body leftmargin="0" topmargin="0" marginwidth="0" marginheight="0" onload='document.productListForm.reset()'>
<form name='productListForm' action="http://lhun.net-a-porter.com/subscribe/product_profile_new.tml" method='post'>
<input type='hidden' name='url' value='http://www.net-a-porter.com/pws/notes_registration/notes$id->[0]_product_list.html' />
<input type='hidden' name='o' value='Notes' />
<input type='hidden' name='e' value='' />

<center>

<table width="675" cellpadding=0 cellspacing=0 border=0>
<tr height=1>
<td width=20></td>
<td width=40></td>
<td width=10></td>
<td width=250></td>
<td width=100></td>
<td width=10></td>
<td width=120></td>
<td width=8></td>
</tr>
EOT

    #my $so = "";
    #my $js = "var notesProductInfo = new Object();\n";

    for my $i (0..$numP-1) {
        my( $p, $prevP, $price_str, $price_str_gbp_eur, $price_str_usd);
        $p = $notesProduct->[$i];
        $prevP = $notesProduct->[$i-1] if $i>0;

        #$js .= "notesProductInfo['$p->{product_id}'] = [\"$p->{designer}\", \"$p->{product_name}\"];";

        if ( $p->{designer} ne $prevP->{designer} ) {
            ($designer1 = $p->{sort_by_designer}) =~ s/([\s&'\-])/$replacement{$1}/go;
            #$so .= "<option value='$designer1'>$p->{designer}</option>\n";        
            print $HTML "<tr id='$designer1' height=30><td>&nbsp;</td><td colspan=7><a name='$designer1'><span class='designer'>$p->{designer}</span></a></td></tr>\n" ;
        }

        if ($p->{price_gbp}==-1) {
            $price_str_gbp_eur = ""; # cancelled;
        }  
        if ($p->{price_gbp}==0 && $p->{price_eur}==0) {
            $price_str_gbp_eur = "TBC";
        }
        elsif ($p->{price_gbp}==0 || $p->{price_eur}==0) {
            $price_str_gbp_eur = "\&pound;";
            $price_str_gbp_eur.= $p->{price_gbp}==0 ? "TBC":$p->{price_gbp};
            $price_str_gbp_eur.= " (\&euro;";
            $price_str_gbp_eur.= $p->{price_eur}==0 ? "TBC":$p->{price_eur};
            $price_str_gbp_eur.= ")";
        }  

        if ($p->{price_gbp}==-1) {
            $price_str_usd = ""; # cancelled;
        }
        elsif ($p->{price_usd}==0) {
            $price_str_usd = "TBC";
        }


        print $HTML << "EOL";
<tr class="product" id='sku$p->{product_id}'>
<td>&nbsp;</td>
<td><a name='$p->{product_id}'>#$p->{product_id}</a></td>
<td>&nbsp;</td>
<td>$p->{product_name}</td>
<td align=right>$price_str_gbp_eur</td>
<td>&nbsp;</td>
EOL
        if ( $p->{live} && $p->{visible} ) {
            print $HTML "<td><a href=\"javascript:clickOn($p->{product_id})\">IN STOCK</a></td>\n<td>&nbsp;</td>";        
        }
        elsif ( $p->{live} && !$p->{visible} ) {
            print $HTML "<td>SOLD OUT</td>\n<td>&nbsp;</td>";        
        }
        elsif ( $p->{price_gbp}==-1 ) {
            print $HTML "<td>CANCELLED</td>\n<td>&nbsp;</td>";        
        }
        else {
            print $HTML "<td>COMING SOON</td>\n",              
                "<td><input type='checkbox' onclick='parent.updateProductSelection(this)' name='s' value='$p->{product_id}' /></td>";
        }
        print $HTML "</tr>\n";

    }

    print $HTML "</table></center></body></html>\n";

    #print $HTML "<!--\n";
    #print $HTML "$so\n";
    #print $HTML "--!>";

    close($HTML);

    #open (JS, ">", "$HTML_OUT_DIR/$filename.js") or die "Can't open file for writing: $!\n";
    #print JS "$js";
    #close(JS);

}

$dbh->disconnect();












