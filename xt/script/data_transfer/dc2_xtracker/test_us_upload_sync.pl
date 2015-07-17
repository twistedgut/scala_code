#!/opt/xt/xt-perl/bin/perl
use strict;
use warnings;
use lib qw( /opt/xt/deploy/xtracker/lib );
use FindBin::libs qw( base=lib_dynamic );
use Carp;

use XTracker::Database qw( read_handle us_handle );
use XTracker::Database::Utilities qw( results_hash2 );

my $dbh_intl = read_handle();
my $dbh_us   = us_handle();

### get list of products in next upload in US
my $qry = "
                select product_id 
                from upload_product
                --where upload_id = (SELECT id FROM upload WHERE upload_status_id = 2 and upload_date > (current_timestamp - interval '1 day') order by upload_date asc limit 1)
                where upload_id = 127
";
my $sth = $dbh_us->prepare( $qry );
$sth->execute ( );

my $prod_list;

while ( my $row = $sth->fetchrow_arrayref() ) {
        if ($prod_list){
                $prod_list .= ",".$row->[0];
        }
        else {
                $prod_list = $row->[0];
        }
}

print "$prod_list\n\n";

# select all product details from intl for US upload products
my $qry = "select p.id as product_id, p.world_id, p.designer_id, p.division_id, p.classification_id,
                    p.product_type_id, p.sub_type_id, p.colour_id,
                    p.season_id, hs.hs_code,
                    p.visible, p.note, p.legacy_sku, p.live, p.colour_filter_id, p.payment_term_id,

                    pa.name, pa.description, pa.long_description, pa.short_description, pa.designer_colour,
                    pa.editors_comments, pa.keywords, pa.recommended, pa.fit_notes, pa.style_notes, pa.editorial_approved,
                    pa.designer_colour_code, --pa.act_id,

                    sa.scientific_term, sa.country_id, sa.packing_note, cast(sa.weight as numeric) * 2.205 as weight, sa.box_id, sa.fabric_content,
                    sa.legacy_countryoforigin, sa.fish_wildlife

             from   product p, product_attribute pa, shipping_attribute sa,
             hs_code hs
             where  p.id = pa.product_id
             and    p.id = sa.product_id
             and p.hs_code_id = hs.id
             --and    p.season_id >= 21
        and p.id in ($prod_list)";

my $sth_intl = $dbh_intl->prepare( $qry );
$sth_intl->execute();
my $results_intl_ref = results_hash2( $sth_intl, 'product_id' );

my $sth_us = $dbh_us->prepare( $qry );
$sth_us->execute();
my $results_us_ref = results_hash2( $sth_us, 'product_id' );

PRODUCT:
foreach my $pid ( keys %{ $results_intl_ref } ){

    next PRODUCT unless $results_us_ref->{$pid};

    my %skip = ( visible              => 1,
                 product_id           => 1,
                 live                 => 1,
                 weight               => 1,
                 #sub_type_id          => 1,
                 #colour_id            => 1,
                 fabric_content       => 1,
                 #colour_filter_id     => 1,
                 packing_note         => 1,
                 #editors_comments     => 1,
                 country_id           => 1,
                 designer_colour      => 1,
                         designer_colour_code => 1,
                 payment_term_id => 1,
                 #long_description => 1,
                 #keywords => 1,
                 #product_type_id => 1,
                 #name => 1,
                 #short_description => 1,
                #hs_code => 1,
                #classification_id        => 1,
                #product_type_id        => 1,
                #sub_type_id => 1,
                colour_filter_id => 1,
                colour_id => 1,
                scientific_term => 1,
                                legacy_countryoforigin => 1,
                        season_id => 1,
            );

    print "checking $pid\n";

    eval{
      FIELD:
        foreach my $key ( keys %{ $results_intl_ref->{$pid} } ){

            next FIELD if $skip{$key};

            if( $results_intl_ref->{$pid}->{$key} ne $results_us_ref->{$pid}->{$key} ){

                sync_data( { product_id => $pid, field => $key, value => $results_intl_ref->{$pid}->{$key} } );
                print "$key updated\n";
            }
            else{
                next FIELD;
            }
        }

        $dbh_us->commit();
    };
    if( $@ ){
        print "update failed: $@\n";
        $dbh_us->rollback();
    }
}


$dbh_intl->disconnect();
$dbh_us->disconnect();


sub sync_data {

    my ( $data_ref ) = @_;

    my $pid   = $data_ref->{product_id};
    my $field = $data_ref->{field};
    my $value = $data_ref->{value};

    my %product  = ( #world_id => 1,
                     #designer_id => 1,
                     #division_id => 1,
                     classification_id  => 1,
                     product_type_id => 1,
                     sub_type_id => 1,
                     #colour_id => 1,
                     #style_number  => 1,
                     #season_id => 1,
                     hs_code => 1,
                     #note => 1,
                     #legacy_sku => 1,
                     #colour_filter_id => 1,
                     #payment_term_id => 1,
                );

    my %prod_att = ( name => 1,
                     description => 1,
                     long_description  => 1,
                     short_description => 1,
                     #designer_colour  => 1,
                     editors_comments => 1,
                     keywords => 1,
                     #recommended => 1,
                     #designer_colour_code => 1,
                     #act_id => 1,
                        fit_notes => 1,
                        style_notes => 1,
                        editorial_approved => 1,
                );

    my %ship_att  = ( #scientific_term => 1,
                      #country_id  => 1,
                      #packing_note => 1,
                      #weight => 1,
                      #box_id => 1,
                      #fabric_content  => 1,
                      #legacy_countryoforigin => 1,
                      fish_wildlife => 1,
                 );

    my $qry = '';

    if( $product{ $field } ){
        if ($field eq "hs_code"){
            $qry = qq{ update product set hs_code_id = (select id from hs_code where hs_code = ?) where id = ? }
        }
        else {
            $qry = qq{ update product set $field = ? where id = ? }
        }
    }
    elsif( $prod_att{ $field } ){
        $qry = qq{ update product_attribute set $field = ? where product_id = ? }
    }
    elsif( $ship_att{ $field } ){
        $qry = qq{ update shipping_attribute set $field = ? where product_id = ? }
    }
    else{
        die "Could not sync data for unknown field $field";
    }

    if ($value && $value ne "Unknown"){
        my $sth = $dbh_us->prepare( $qry );
        $sth->execute( $value, $pid );
    }
    return;
}


__END__
