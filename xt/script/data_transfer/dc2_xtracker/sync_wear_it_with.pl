#!/opt/xt/xt-perl/bin/perl -w
use strict;
use warnings;
use lib "/opt/xt/deploy/xtracker/lib/";
use FindBin::libs qw( base=lib_dynamic );

use XTracker::Database qw(:common);
use XTracker::Database::Attributes qw( delete_recommended_product );
use XTracker::Database::Product qw( product_present );
use XTracker::Comms::FCP qw( create_fcp_related_product delete_fcp_related_product );

# connect to INTL XT database
my $dbh_xt_intl = get_database_handle( { name => 'xtracker', type => 'readonly'} ) || die print "Error: Unable to connect to INTL XT DB";

# get current INTL data
my $intl_data = _get_data($dbh_xt_intl, 'all');

# finished with INTL db
$dbh_xt_intl->disconnect();


# connect to AM XT database
my $dbh_xt_am = get_database_handle( { name => 'DC2', type => 'transaction'} ) || die print "Error: Unable to connect to AM XT DB";

# connect to AM FCP database
my $dbh_fcp = get_database_handle( { name => 'FCP_DC2', type => 'transaction'} ) || die print "Error: Unable to connect to AM FCP DB";


# get current AM data
my $am_data = _get_data($dbh_xt_am, 'active');


# loop through AM data and check for updates on AM
foreach my $product_id ( keys %{$am_data} ) {
    ## no critic(ProhibitDeepNests)

    print "PID: $product_id\n";


        # loop over each wear it with slot
        foreach my $slot ( qw(slot11 slot12 slot21 slot22 slot31 slot32) ) {

        eval {

            #print "SLOT: $slot\n";

            if ( $intl_data->{$product_id}{$slot.'_pid'} ){

            # set product
            if ( !$am_data->{$product_id}{$slot.'_pid'} || ( $am_data->{$product_id}{$slot.'_pid'} != $intl_data->{$product_id}{$slot.'_pid'} && $am_data->{$product_id}{$slot.'_auto'} == 1) ) {

                # get slot and position
                if ( $slot =~ m/(slot)(\d{1})(\d{1})/ ) {   
                    
                    my $position    = $2;
                    my $sort    = $3;

                    # if set remove current product first
                    if ( $am_data->{$product_id}{$slot.'_pid'} ) {

                        print "DELETING: ".$am_data->{$product_id}{$slot.'_pid'}."\n";
                    
                        delete_recommended_product($dbh_xt_am, $product_id, $am_data->{$product_id}{$slot.'_pid'}, 1);
                    
                        if ( product_present( $dbh_xt_am, { type => 'product_id', id => $product_id, environment => 'live' } ) ) {            
                            delete_fcp_related_product( $dbh_fcp, { product_id => $product_id, related_product_id => $am_data->{$product_id}{$slot.'_pid'}, type_id => 'Recommended' } );
                        }
                    
                    }

                    print "ADDING: ".$intl_data->{$product_id}{$slot.'_pid'}."\n";
            
                    # set new product
                    my $qry = "insert into recommended_product (product_id, recommended_product_id, type_id, sort_order, slot, auto_set) values (?,?,?,?,?,?)";
                    my $sth = $dbh_xt_am->prepare($qry);
                    $sth->execute( $product_id, $intl_data->{$product_id}{$slot.'_pid'}, 1, $sort, $position, 1 );
                   
                    # check if product live 
                    if ( product_present( $dbh_xt_am, { type => 'product_id', id => $product_id, environment => 'live' } ) ) { 

                        # check if recommended product is live
                        if ( product_present( $dbh_xt_am, { type => 'product_id', id => $intl_data->{$product_id}{$slot.'_pid'}, environment => 'live' } ) ) {           
                            create_fcp_related_product( $dbh_fcp, { product_id => $product_id, related_product_id => $intl_data->{$product_id}{$slot.'_pid'}, type_id => 'Recommended', sort_order => $sort, position => $position } );
                        }
                        else {
                            die "Skipped - product not live";
                        }
                    }
                }
            
            }
            else {
                #print "SKIPPING: Manually Set\n";
            }
        }
            else {

                #print "SKIPPING: No data\n";
            }

            $dbh_xt_am->commit();
            $dbh_fcp->commit();

    };

    if ( $@ ) {
        print "ERROR: $product_id - ". $@;
        $dbh_xt_am->rollback();
        $dbh_fcp->rollback();
    }

        }

}


$dbh_xt_am->disconnect();
$dbh_fcp->disconnect();



sub _get_data {

    my $dbh = shift;
    my $type = shift;

    my %data = ();

    # query to return all wear it with data from XT database in one go
    my $qry = "
        select p.id as product_id, 

            p11.id as slot11_pid,
            rp11.auto_set as slot11_auto,
            p12.id as slot12_pid,
            rp12.auto_set as slot12_auto,

            p21.id as slot21_pid,
            rp21.auto_set as slot21_auto,
            p22.id as slot22_pid,
            rp22.auto_set as slot22_auto,

            p31.id as slot31_pid,
            rp31.auto_set as slot31_auto,
            p32.id as slot32_pid,
            rp32.auto_set as slot32_auto

        from product p
            LEFT JOIN recommended_product rp11 
                LEFT JOIN product p11 ON rp11.recommended_product_id = p11.id
            ON p.id = rp11.product_id AND rp11.type_id = 1 AND rp11.slot = 1 and rp11.sort_order = 1
            LEFT JOIN recommended_product rp12 
                LEFT JOIN product p12 ON rp12.recommended_product_id = p12.id
            ON p.id = rp12.product_id AND rp12.type_id = 1 AND rp12.slot = 1 and rp12.sort_order = 2

            LEFT JOIN recommended_product rp21 
                LEFT JOIN product p21 ON rp21.recommended_product_id = p21.id
            ON p.id = rp21.product_id AND rp21.type_id = 1 AND rp21.slot = 2 and rp21.sort_order = 1
            LEFT JOIN recommended_product rp22 
                LEFT JOIN product p22 ON rp22.recommended_product_id = p22.id
            ON p.id = rp22.product_id AND rp22.type_id = 1 AND rp22.slot = 2 and rp22.sort_order = 2

            LEFT JOIN recommended_product rp31 
                LEFT JOIN product p31 ON rp31.recommended_product_id = p31.id
            ON p.id = rp31.product_id AND rp31.type_id = 1 AND rp31.slot = 3 and rp31.sort_order = 1
            LEFT JOIN recommended_product rp32 
                LEFT JOIN product p32 ON rp32.recommended_product_id = p32.id
            ON p.id = rp32.product_id AND rp32.type_id = 1 AND rp32.slot = 3 and rp32.sort_order = 2

            LEFT JOIN price_adjustment pa ON p.id = pa.product_id AND current_timestamp BETWEEN pa.date_start AND pa.date_finish

    ";
    
    if ($type eq 'active'){
        $qry .= ' where p.visible = true or p.live = false';
    }

    my $sth = $dbh->prepare($qry);
    $sth->execute();

    while ( my $row = $sth->fetchrow_hashref() ) {
            $data{ $row->{product_id} } = $row;
    }

    return \%data;

}

__END__
