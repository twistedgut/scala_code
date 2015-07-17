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

# select all product details from intl
my $qry = q{ select p.id as product_id, p.world_id, p.designer_id, p.division_id, p.classification_id,
                    p.product_type_id, p.sub_type_id, p.colour_id, p.style_number, p.season_id, p.hs_code_id,
                    p.visible, p.note, p.legacy_sku, p.live, p.colour_filter_id, p.payment_term_id, p.payment_settlement_discount_id, p.payment_deposit_id,
                          
                    pa.name, pa.description, pa.long_description, pa.short_description, pa.designer_colour, 
                    pa.editors_comments, pa.keywords, pa.recommended,
                    pa.designer_colour_code, pa.size_scheme_id, pa.act_id,

                    sa.scientific_term, sa.country_id, sa.packing_note, cast(sa.weight as numeric) * 2.205 as weight, sa.box_id, sa.fabric_content,  
                    sa.legacy_countryoforigin, sa.fish_wildlife, sa.is_hazmat
                  
             from   product p, product_attribute pa, shipping_attribute sa
             where  p.id = pa.product_id
             and    p.id = sa.product_id
             and p.id >= 30403 
             and p.id <= 30404

        };

my %new_import = ( 
30403 => 1,
30404 => 1
              );


my $sth_intl = $dbh_intl->prepare( $qry );
$sth_intl->execute();
my $results_intl_ref = results_hash2( $sth_intl, 'product_id' );

my $sth_us = $dbh_us->prepare( $qry );
$sth_us->execute();
my $results_us_ref = results_hash2( $sth_us, 'product_id' );


foreach my $pid ( keys %{ $results_intl_ref } ){

    #print "checking $pid\n";
    
    if( $new_import{ $pid } ){
        copy_product( $pid, $results_intl_ref->{$pid} );
        print "$pid COPIED\n\n";
    }
}


$dbh_intl->disconnect();

$dbh_us->commit();
$dbh_us->disconnect();


sub copy_product {

    my ( $pid, $data_ref ) = @_;

    # collect variants
    my $qry_var = q{ select * from variant where product_id = ? };
    my $sth_var = $dbh_intl->prepare( $qry_var );
    $sth_var->execute( $pid );

    my $variants = $sth_var->fetchall_arrayref( {} );

    # insert statements
    my $in_prod = q{ insert into product ( id, world_id, designer_id, division_id, classification_id,
                                           product_type_id, sub_type_id, colour_id, style_number,
                                           season_id, hs_code_id, visible, note, legacy_sku, live,
                                           colour_filter_id, payment_term_id, payment_settlement_discount_id, payment_deposit_id
                                      )
                     values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
                };
    
    my $in_pa   = q{ insert into product_attribute ( product_id, name, description, long_description,
                                                     short_description, designer_colour, 
                                                     editors_comments,
                                                     keywords, recommended,
                                                     designer_colour_code,
                                                     size_scheme_id, act_id
                                                )
                     values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
                };
    
    my $in_sa   = q{ insert into shipping_attribute ( product_id, scientific_term, country_id,  
                                                      packing_note, weight, box_id, fabric_content,  
                                                      legacy_countryoforigin, fish_wildlife, is_hazmat
                                                 )
                     values ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ? )
                };

    my $in_var  = q{ insert into variant ( id, product_id, size_id_old, nap_size_id, legacy_sku,
                                           type_id, size_id, designer_size_id
                                      )
                     values ( ?, ?, ?, ?, ?, ?, ?, ? )
                }; 
                                            

    my $sth_prod = $dbh_us->prepare( $in_prod );
    my $sth_pa   = $dbh_us->prepare( $in_pa );
    my $sth_sa   = $dbh_us->prepare( $in_sa );
    my $sth_var  = $dbh_us->prepare( $in_var );

     # do the work
    eval{
        # product data
        $sth_prod->execute( $data_ref->{product_id},
                            $data_ref->{world_id},
                            $data_ref->{designer_id},
                            $data_ref->{division_id},
                            $data_ref->{classification_id},
                            $data_ref->{product_type_id},
                            $data_ref->{sub_type_id},
                            $data_ref->{colour_id},
                            $data_ref->{style_number},
                            $data_ref->{season_id},
                            $data_ref->{hs_code_id},
                            $data_ref->{visible},
                            $data_ref->{note},
                            $data_ref->{legacy_sku},
                            $data_ref->{live},
                            $data_ref->{colour_filter_id},
                            $data_ref->{payment_term_id},
                            $data_ref->{payment_settlement_discount_id},
                            $data_ref->{payment_deposit_id}
                       );

        # product attributes
        $sth_pa->execute( $data_ref->{product_id},
                          $data_ref->{name},
                          $data_ref->{description},
                          $data_ref->{long_description},
                          $data_ref->{short_description},
                          $data_ref->{designer_colour},
                          $data_ref->{editors_comments},
                          $data_ref->{keywords},
                          $data_ref->{recommended},
                          $data_ref->{designer_colour_code},
                          $data_ref->{size_scheme_id},
                          $data_ref->{act_id}
                     );
        # shipping attributes
        $sth_sa->execute( $data_ref->{product_id},
                          $data_ref->{scientific_term},
                          $data_ref->{country_id},
                          $data_ref->{packing_note},
                          $data_ref->{weight},
                          $data_ref->{box_id},
                          $data_ref->{fabric_content},
                          $data_ref->{legacy_countryoforigin},
                          $data_ref->{fish_wildlife},
                          $data_ref->{is_hazmat},
                     );

        # variant data
        foreach my $variant ( @$variants ){
            $sth_var->execute( $variant->{id},
                               $variant->{product_id},
                               $variant->{size_id_old},
                               $variant->{nap_size_id},
                               $variant->{legacy_sku},
                               $variant->{type_id},
                               $variant->{size_id},
                               $variant->{designer_size_id},
                          );
            print "variant $variant->{id} created\n";
        }

        $dbh_us->commit();
    };
    if ( $@ ) {
        print $@;
        $dbh_us->rollback();
    }
}

__END__


