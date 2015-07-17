#!/opt/xt/xt-perl/bin/perl 
use strict;
use warnings;
use DBI;
use Symbol;
use Data::Dumper;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;

my $dbh = read_handle();

my ($sth, $notesProduct, $designer1, $numP, %replacement,$notes_ids);

my $HTML_OUT_DIR = '/opt/xt/deploy/xtracker/script/data_transfer/web_site/notes_registration';

$sth = $dbh->prepare("select distinct notes_id from notes_product3");
$sth->execute();
$notes_ids = $sth->fetchall_arrayref();

foreach my $id (@$notes_ids){

    $sth = $dbh->prepare("
    SELECT np.product_id, d.designer, np.product_name, round(np.price_gbp) as price_gbp, round(np.price_usd) as price_usd, p.live, p.visible, CASE WHEN d.designer LIKE '3.1 %' THEN replace(d.designer, '3.1 ', '') WHEN d.designer ~ 'Chlo' THEN substring(d.designer, '^(.*Chlo)')||'e' ELSE d.designer END as sort_by_designer
      FROM notes_product3 np, product p, designer d
     WHERE notes_id = '$id->[0]' and np.product_id = p.id and p.designer_id = d.id
     ORDER BY 8, np.product_id
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


    my $filename = "notes$id->[0]_product_list";

    if ($id->[0] =~ /\D/) {
        ($filename = lc "$id->[0]_product_list") =~ s/\s/_/g;
    }

    open (my $HTML, ">", "$HTML_OUT_DIR/$filename-so.html") or die "Can't open file for writing: $!\n";

    my $so = "";
    my $js = "var notesProductInfo = new Object();\n";

    for my $i (0..$numP-1) {
        my( $p, $prevP, $price_str);
        $p = $notesProduct->[$i];
        $prevP = $notesProduct->[$i-1] if $i>0;

        $js .= "notesProductInfo['$p->{product_id}'] = [\"$p->{designer}\", \"$p->{product_name}\"];";

        if( $p->{designer} ne $prevP->{designer} ) {
            ($designer1 = $p->{sort_by_designer}) =~ s/([\s&'\-])/$replacement{$1}/go;
            $so .= "<option value='$designer1'>$p->{designer}</option>\n";        
        }

    }

    print $HTML "$so\n";

    close($HTML);

    open (my $JS, ">", "$HTML_OUT_DIR/$filename.js") or die "Can't open file for writing: $!\n";
    print $JS "$js";
    close($JS);

}

$dbh->disconnect();












