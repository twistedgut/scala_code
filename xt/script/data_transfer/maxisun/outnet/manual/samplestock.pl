#!/opt/xt/xt-perl/bin/perl -w

use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database;
use XTracker::Config::Local qw( config_var );
use Getopt::Long; 

my $dbh         = read_handle(); 
my $outdir      = undef; 
my $channel_id  = undef; 
my $currency =  config_var('Currency', 'local_currency_code');


GetOptions( 
    'outdir=s'      => \$outdir, 
    'channel_id=s'  => \$channel_id, 
); 
 
die 'No output directory defined' if not defined $outdir; 
die 'No channel id defined' if not defined $channel_id; 

# open output file
open my $fh, '>', '/var/data/xt_static/data/maxisun/'.$outdir.'/SAMPLESTOCK.csv' || die "Couldn't open output file: $!"; 

my $qry = "
    select to_char(current_timestamp, 'DDMMYYYY') as date, p.id as product_id, p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, sum(q.quantity) as quantity, p.designer_id, p.season_id, sa.legacy_countryoforigin
    from variant v 
            left join quantity q on v.id = q.variant_id and q.channel_id = ? and q.location_id in (select id from location where type_id in (4,6)), 
        product p 
            left join legacy_designer_supplier lds on p.designer_id = lds.designer_id
            left join supplier s on lds.supplier_id = s.id, 
        price_purchase pri, shipping_attribute sa
    where v.product_id = p.id
    and p.id = pri.product_id
    and p.id = sa.product_id
    group by
    p.id, p.legacy_sku, p.style_number, s.code, pri.uk_landed_cost, p.designer_id, p.season_id, sa.legacy_countryoforigin
";

my $sth = $dbh->prepare($qry);
$sth->execute($channel_id);

while( my $row = $sth->fetchrow_hashref() ){

    if (!$row->{code}){
        $row->{code} = "UNKNOWN";
    }


    if ($row->{quantity} > 0){

        $row->{style_number} =~ s/\n//;
        $row->{style_number} =~ s/\r//;

        $row->{legacy_countryoforigin} =~ s/\n//;
            $row->{legacy_countryoforigin} =~ s/\r//;

        my $cost = $row->{uk_landed_cost} * $row->{quantity};

        print $fh $row->{legacy_sku}."~";
        print $fh $row->{date}."~";
        print $fh "~";
        print $fh $row->{style_number}."~";
        print $fh "$currency~";
        print $fh $row->{code}."~";
        print $fh $cost."~";
        print $fh $row->{quantity}."~";
        print $fh $row->{legacy_sku}."~";
        print $fh $row->{designer_id}."~";
        print $fh $row->{season_id}."~";
        print $fh $row->{legacy_countryoforigin}."~";
        print $fh "~~~~~\r\n";
    }
}

$dbh->disconnect();

close $fh;

