#!/opt/xt/xt-perl/bin/perl 

use strict;
use warnings;
use Carp;
use Test::More qw( no_plan );
use Data::Dumper qw( Dumper );

use lib '/opt/xt/deploy/xtracker/lib/';
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Database qw( read_handle fcp_handle );

# compare stock levels of each db

open my $lfh, '>', '../logs/pricing.log' || die "can't open log file: $!";
print $lfh "[ sku ]\tfcp\txt\n";

my $dbh_x = read_handle();
my $dbh_f = fcp_handle();

my %pricing_x = ();
my %pricing_f = ();

# xtracker pricing
my $qry_x = q{ select pd.product_id, pd.price, c.currency, 'default' as locality, 'default' as type
               from price_default pd, currency c
               where pd.currency_id = c .id
               union
               select pr.product_id, pr.price, c.currency, lower(r.region) as locality, 'territory' as type
               from price_region pr, currency c, region r
               where pr.currency_id = c .id
               and pr.region_id = r.id
               union
               select pc.product_id, pc.price, c.currency, lower(ctry.code) as locality, 'country' as type
               from price_country pc, currency c, country ctry
               where pc.currency_id = c .id
               and pc.country_id = ctry.id
             };

my $sth_x = $dbh_x->prepare( $qry_x );
$sth_x->execute();
my $results_x = $sth_x->fetchall_arrayref( {} );

# fcp pricing
my $qry_f = q{ select sku, lower(locality) as locality, lower(locality_type) as locality_type, offer_price, currency from channel_pricing };
my $sth_f = $dbh_f->prepare( $qry_f );
$sth_f->execute();
my $results_f = $sth_f->fetchall_arrayref( {} );


# build hash for price comparison
foreach my $row_x ( @$results_x ){
    $pricing_x{ $row_x->{product_id} }->{ $row_x->{type} }->{ $row_x->{locality} }
        = { price => $row_x->{price}, currency => $row_x->{currency} };
};

# build hash for price comparison
foreach my $row_f ( @$results_f ){

    my $sku      = $row_f->{sku};
    my $price    = $row_f->{offer_price};
    my $locality = $row_f->{locality};
    my $type     = $row_f->{locality_type};
    my $currency = $row_f->{currency};

    my ($product_id) = $sku =~ m/^(\d+)-.*$/xms;

    my $new_price_ref = { price => $price, currency => $currency, };

    if ( $pricing_f{$product_id}->{$type}->{$locality} ) {
       next if is_deeply( $pricing_f{$product_id}->{$type}->{$locality}, $new_price_ref ); 
    }

    $pricing_f{$product_id}->{$type}->{$locality} =
        { price => $price, currency => $currency, };
}


foreach my $product_id ( keys %pricing_f ){

    unless( is_deeply( $pricing_f{$product_id}, $pricing_x{$product_id} , "[ $product_id ] Pricing Comparison" ) ){

        print $lfh "[ $product_id ]\n";

        my $x = Dumper $pricing_x{$product_id};
        my $f = Dumper $pricing_f{$product_id};
        
        print $lfh "$x\n";
        print $lfh "$f\n\n";
    }
}    

close $lfh;
$dbh_x->disconnect();
$dbh_f->disconnect();
