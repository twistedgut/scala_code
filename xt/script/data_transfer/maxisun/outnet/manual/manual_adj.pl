#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use Getopt::Long; 
use DateTime; 

my $dbh         = read_handle(); 
my $outdir      = undef; 
my $channel_id  = undef; 
my $dt          = DateTime->now; 
my %data        = (); 

my $to          = $dt->date; 
my $from        = $dt->subtract( days => 1 )->date; 

GetOptions( 
    'outdir=s'      => \$outdir, 
    'channel_id=s'  => \$channel_id, 
); 
 
die 'No output directory defined' if not defined $outdir; 
die 'No channel id defined' if not defined $channel_id; 

# open output file
open my $fh, '>', '/var/data/xt_static/data/maxisun/intl/'.$outdir.'/manual_adjustment.csv' || die "Couldn't open output file: $!"; 


my $qry = "
    select to_char(current_timestamp, 'DDMMYYYY') as date, p.id as product_id, p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, sum(ls.quantity) as quantity, p.designer_id, p.season_id, sa.legacy_countryoforigin, ls.notes
    from product p
        left join legacy_designer_supplier lds on p.designer_id = lds.designer_id
            left join supplier s on lds.supplier_id = s.id, 
    variant v, log_stock ls, price_purchase pri, shipping_attribute sa
    where p.id = v.product_id 
    and v.id = ls.variant_id 
    and ls.stock_action_id = 3
    and ls.date between ? and ?
    and ls.channel_id = ?
    and p.id = pri.product_id
    and p.id = sa.product_id
    group by p.id, p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, p.designer_id, p.season_id, sa.legacy_countryoforigin, ls.notes
";

my $sth = $dbh->prepare($qry);
$sth->execute($from, $to, $channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if (!$row->{code}){
        $row->{code} = "UNKNOWN";
    }


    $row->{style_number} =~ s/\n//;
    $row->{style_number} =~ s/\r//;

    $row->{legacy_countryoforigin} =~ s/\n//;
    $row->{legacy_countryoforigin} =~ s/\r//;

    my $cost = $row->{uk_landed_cost} * $row->{quantity};

    print $fh $row->{legacy_sku}."~";
    print $fh $row->{date}."~";
    print $fh "~";
    print $fh $row->{style_number}."~";
    print $fh "GBP~";
    print $fh $row->{code}."~";
    print $fh $cost."~";
    print $fh $row->{quantity}."~";
    print $fh $row->{legacy_sku}."~";
    print $fh $row->{designer_id}."~";
    print $fh $row->{season_id}."~";
    print $fh $row->{legacy_countryoforigin}."~";
    print $fh "~~~~".$row->{notes}."~\r\n";
}

$dbh->disconnect();

close $fh;

