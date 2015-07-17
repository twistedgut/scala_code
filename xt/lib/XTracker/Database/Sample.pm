package XTracker::Database::Sample;

use strict;
use warnings;

use Perl6::Export::Attrs;
use XTracker::Database;
use XTracker::Database::Stock qw( get_saleable_item_quantity );
use XTracker::Database::Delivery qw( get_incomplete_delivery_items_by_variant );
use XTracker::Database::Utilities qw( results_list last_insert_id results_channel_list );
use XTracker::Constants::FromDB qw(
    :flow_status
    :shipment_status
    :shipment_item_status
    :shipment_class
    :variant_type
);


### Subroutine : guess_variant_id               ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub guess_variant_id :Export() {

    my ( $p ) = @_;

    my $sql = qq(
select q.variant_id
  from quantity q, variant v
 where v.product_id = ?
   and q.variant_id = v.id
   and location_id = (
    select id
      from location
     where location = 'Sample Room'
   )
);

    my $sth = $p->{dbh}->prepare( $sql );

    $sth->execute( $p->{product_id} );

    my $variant_id = $sth->fetchrow;

    $sth->finish;

    return $variant_id;

}


### Subroutine : get_shipment_id                ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_shipment_id :Export() {

    my $p = shift;

    my $sql = qq(
select shipment_id
from shipment_item
where variant_id = ?
and shipment_item_status_id = $SHIPMENT_ITEM_STATUS__DISPATCHED
and shipment_id in (select id from shipment where shipment_class_id = 7)
limit 1
    );

    my $sth = $p->{dbh}->prepare( $sql );

    $sth->execute( $p->{variant_id} );

    my $shipment_id = $sth->fetchrow;

    return $shipment_id;

}


### Subroutine : create_sample_receiver         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub create_sample_receiver :Export(:DEFAULT) {

    my ( $dbh, $name, $address_id ) = @_;

    my $qry = "INSERT INTO sample_receiver VALUES (default, ?, ?)";
    my $sth = $dbh->prepare($qry);
    $sth->execute($name, $address_id);

    return last_insert_id( $dbh, 'sample_receiver_id_seq' );
}



### Subroutine : get_sample_rma                                      ###
# usage        : $hash_ptr = get_sample_rma(                           #
#                      $dbh,                                           #
#                      $args_ref = { type,id }                         #
#                 );                                                   #
# description  : Returns the RMA details for a Sample Stock            #
#                return. Includes Channel Id & Channel Name via        #
#                'stock_transfer' record.                              #
# parameters   : Database Handle, Argument Ref to 'type' (all,         #
#                legacy_sku or rma_number) and the 'id' of the 'type'  #
# returns      : A pointer to a HASH containing the details            #

sub get_sample_rma :Export() {

    my ( $dbh, $args ) = @_;

    my $clause = {
        all => 'AND 1 = 1',
        legacy_sku => 'AND legacy_sku = ?',
        rma_number => 'AND rma_number = ?',
    };

    my $sql = qq{
SELECT r.rma_number, rsl.date, v.legacy_sku, p.id AS product_id, pa.name, pa.description,
 pt.product_type, v.size_id, d.designer,
 ch.id AS channel_id, ch.name AS sales_channel
FROM return r, shipment s, return_status_log rsl, shipment_item si,
 variant v, product p, product_attribute pa, product_type pt, designer d,
 link_stock_transfer__shipment lsts, stock_transfer st, channel ch
WHERE r.shipment_id = s.id
AND s.shipment_class_id = 7
AND r.return_status_id in(1, 2)
AND r.id = rsl.return_id
AND rsl.return_status_id = 1
AND s.id = si.shipment_id
AND si.variant_id = v.id
AND v.product_id = p.id
AND p.id = pa.product_id
AND p.product_type_id = pt.id
AND p.designer_id = d.id
AND r.shipment_id = lsts.shipment_id
AND st.id = lsts.stock_transfer_id
AND st.channel_id = ch.id
$clause->{$args->{type}}
};

    my $sth = $dbh->prepare( $sql );

    $sth->execute( $args->{id} );

    my $rma_details_ref = $sth->fetchrow_hashref;

    $sth->finish;

    return $rma_details_ref;
}



### Subroutine : get_vendor_sample_shipment_items                     ###
# usage        : $hash_ptr = get_vendor_sample_shipment_items(          #
#                      $dbh,                                            #
#                      $args = { product_id, size_id, channel_id }      #
#                );                                                     #
# description  : Returns a list of Vendor Samples that need to be       #
#                checked. The list will be returned with sales channel  #
#                as the key and an array of sample for each channel as  #
#                the value. If passed a product id & size id & channel  #
#                id then it will return a hash pointer to the record    #
#                for that row alone.                                    #
# parameters   : A Database Handle, optional Args: Product Id, Size Id  #
#                & a Sales Channel Id.                                  #
# returns      : A pointer to a HASH.                                   #

sub get_vendor_sample_shipment_items :Export() {
    my ( $dbh, $args ) = @_;

    # make it, worst case, and empty string to avoid irritating messages like:
    #   Use of uninitialized value $product_id_clause in concatenation (.) or
    #   string at
    #   /home/c.wright/development/xt/lib/XTracker/Database/Sample.pm line
    #   465.
    my $product_id_clause = q{};
    my @args;

    if ( defined $args->{product_id} && defined $args->{size_id} && defined $args->{channel_id} ) {
        $product_id_clause = " AND v.product_id = ? AND v.size_id = ? AND st.channel_id = ? ";
        @args = ( $args->{product_id}, $args->{size_id}, $args->{channel_id} );
    }

    my $qry = qq{
SELECT s.id as shipment_id,
 TO_CHAR(s.date, 'DD-MM-YYYY  HH24:MI') AS transfer_date,
 si.id AS shipment_item_id,
 v.id AS variant_id,
 p.id AS product_id,
 c.colour,
 v.legacy_sku,
 sku_padding(v.size_id) as size_id,
 size.size,
 la.mastercolor,
 la.descriptionofcolour,
 st.channel_id,
 ch.name AS sales_channel
FROM shipment s
JOIN shipment_item si on si.shipment_id=s.id
JOIN variant v on si.variant_id=v.id
JOIN size on v.size_id=size.id
JOIN product p on v.product_id=p.id
LEFT JOIN legacy_attributes la ON ( p.id = la.product_id )
JOIN colour c on p.colour_id=c.id
JOIN link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
JOIN stock_transfer st on lsts.stock_transfer_id=st.id
JOIN channel ch on st.channel_id=ch.id
WHERE s.shipment_class_id  = $SHIPMENT_CLASS__TRANSFER_SHIPMENT -- transfer
AND s.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED -- dispatched
AND v.type_id = $VARIANT_TYPE__SAMPLE -- sample
$product_id_clause
ORDER BY transfer_date ASC
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( @args );

    if ( $product_id_clause ) {
        return $sth->fetchrow_hashref();
    }
    else {
        return results_channel_list( $sth );
    }
}


### Subroutine : get_variant_from_delivery_item           ###
# usage        : $scalar = get_variant_from_delivery_item(  #
#                    $dbh,                                  #
#                    $args = { delivery_item_id, clause }   #
#                );
# description  : Returns a Variant Id for a given delivery  #
#                item Id. Will link to the stock order item #
#                table unless the 'clause' is set to        #
#                'shipment_item' where it will then link to #
#                the shipment item table.                   #
# parameters   : Database Handler, Args containing Delivery #
#                Item Id & an optional Clause.              #
# returns      : A Vairant Id.                              #

sub get_variant_from_delivery_item :Export() {

    my ( $dbh, $args ) = @_;

    my $qry;

    if ( $args->{clause} eq 'shipment_item' ) {

        $qry = qq{
SELECT v.id AS variant_id
FROM variant v,
 shipment_item soi,
 delivery_item dii,
 link_delivery_item__shipment_item ldi_soi
WHERE v.id = soi.variant_id
AND soi.id = ldi_soi.shipment_item_id
AND ldi_soi.delivery_item_id = dii.id
AND dii.id = ?
};

    }
    else {

        $qry = qq{
SELECT v.id AS variant_id
FROM variant v,
 stock_order_item soi,
 delivery_item dii,
 link_delivery_item__stock_order_item ldi_soi
WHERE v.id = soi.variant_id
AND soi.id = ldi_soi.stock_order_item_id
AND ldi_soi.delivery_item_id = dii.id
AND dii.id = ?
};

    }

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $args->{delivery_item_id} );

    my $row = $sth->fetchrow_hashref;

    return $row->{variant_id};

}


### Subroutine : update_shipment_item_variant         ###
# usage        : update_shipment_item_variant(          #
#                   $dbh,                               #
#                   $args = { process_group_id,         #
#                             sample_variant_id,        #
#                             stock_variant_id }        #
#                );                                     #
# description  : This updates a shipment item's variant #
#              : id with the sample variant id for a    #
#                product. Gets the Shipment Id to       #
#                update using a stock process group id  #
#                and the regular stock variant id.      #
# parameters   : A Database Handle, Args containing the #
#                Stock Process Group Id, Sample Variant #
#                Id & the Stock Variant Id.             #
# returns      : Nothing.                               #

sub update_shipment_item_variant :Export() {

    my ( $dbh, $args ) = @_;
    $args->{process_group_id} =~ s/^p-//i;

    my $s_qry = qq{
SELECT si.id
FROM stock_process sp,
 delivery_item di,
 link_delivery_item__shipment_item ldisi,
 shipment_item si
WHERE sp.group_id = ?
AND sp.delivery_item_id = di.id
AND di.id = ldisi.delivery_item_id
AND ldisi.shipment_item_id = si.id
AND si.variant_id = ?
};

    my $s_sth = $dbh->prepare( $s_qry );

    $s_sth->execute( $args->{process_group_id}, $args->{sample_variant_id} );

    my $shipment_item = $s_sth->fetchall_arrayref( {} );

    my $shipment_item_id= $shipment_item->[0]->{id};

    my $u_qry = qq{
UPDATE shipment_item
SET variant_id = ?
WHERE id = ?
};

    my $u_sth = $dbh->prepare( $u_qry );

    $u_sth->execute( $args->{stock_variant_id}, $shipment_item_id );

}


### Subroutine : get_stock_variant_id_from_variant              ###
# usage        : $scalar = get_stock_variant_id_from_variant(     #
#                     $dbh,                                       #
#                     $args = { variant_id }                      #
#                );                                               #
# description  : This gets the Stock Variant Id for a given       #
#                variant id usually a sample variant id.          #
# parameters   : A Database Handle, Args containing a Variant Id. #
# returns      : A Variant Id.                                    #

sub get_stock_variant_id_from_variant :Export() {

    my ( $dbh, $args ) = @_;

    # This is a guesstimate.  I'm told that there will only ever be one sample
    my $qry = qq{
SELECT v.id
FROM variant v
WHERE v.type_id = 1
AND v.product_id IN (
 SELECT p.id
 FROM variant v,
      product p
 WHERE p.id = v.product_id
 AND v.id = ?
)
AND v.size_id IN (
 SELECT v.size_id
 FROM variant v,
      product p
 WHERE p.id = v.product_id
 AND v.id = ?
)
};

    my $sth = $dbh->prepare( $qry );

    $sth->execute( $args->{id}, $args->{id} );

    my $row = $sth->fetchrow_hashref();

    return $row->{id};

}


=head2 get_sample_variant_with_stock

  usage        : $variant_id = get_sample_variant_with_stock(
                        $database_handler,
                        $variants_hash_ref,
                        $variant_size_array_ref,
                        $ideal_variant_id,
                        $channel_ref
                   );

  description  : This will check that the ideal variant id that is passed
                 in has any Stock in the Sample Room, Free Stock Available or
                 has any Delivery Items for it that have not been Completed.
                 If not it will traverse the variant_size array from the ideal
                 size start point in the following manner: +1/-1, +2/-2 and so on,
                 until it finds a variant with stock. If no stock can be found with
                 any variant then it returns the ideal variant id passed in initially.
                 Need to pass in a Sales Channel Ref as got from Database::Channel::get_channel.

  parameters   : A Database Handle, A HASH Ref of Varaints index by their Size Id,
                 An ARRAY Ref of Variants Sizes, The Ideal Variant Id, Sales Channel Ref.
  returns      : A Variant Id.

=cut

sub get_sample_variant_with_stock :Export() {

    my ( $dbh, $product_id, $variants, $variant_sizes, $ideal_vid, $channel_ref )   = @_;

    die "No DBH Connection Passed"                              if ( !defined $dbh );
    die "No Product Id Passed"                                  if ( !defined $product_id );
    die "No Variant HASH Passed"                                if ( !defined $variants );
    die "No Variant Sizes Passed"                               if ( !defined $variant_sizes );
    die "No Ideal Size VID Passed"                              if ( !defined $ideal_vid );
    die "No Sales Channel Ref Passed or isn't a HASH Ref"       if ( !defined $channel_ref || ref( $channel_ref ) ne 'HASH' );

    # set-up the return VID to be the ideal vid
    # if no stock is found at all
    my $ret_vid     = $ideal_vid;

    # find the point in the $variant_sizes array
    # for the $ideal_vid
    my $start_point_idx = 0;
    foreach my $key ( keys %{ $variants } ) {
        if ( $variants->{ $key } == $ideal_vid ) {
            foreach ( 0..$#{ $variant_sizes } ) {
                if ( $variant_sizes->[ $_ ] == $key ) {
                    $start_point_idx    = $_;
                    last;
                }
            }
            last;
        }
    }

    # get Saleable Stock for the Product and Sales Channel
    my $saleable_stock  = get_saleable_item_quantity( $dbh, $product_id );
    my $stock_can_use   = ( exists $saleable_stock->{ $channel_ref->{name} } ? $saleable_stock->{ $channel_ref->{name} } : undef );
    # get any Stock in or on it's way to the Sample Room for the Product and Sales Channel
    my $sample_stock    = get_sample_stock_qty( $dbh, { type => 'product', id => $product_id, channel_id => $channel_ref->{id} } );

    # loop round the array checking to see
    # if there is any stock available or about
    # to become available for a variant

    my $count   = 0;
    my $adjust  = 0;
    my $too_low = 0;
    my $too_high= 0;

    while ( !$too_low || !$too_high ) {

        my $idx     = $start_point_idx;
        my $mult    = ( ($count % 2) == 0 ? -1 : 1 );

        $idx    += $mult * $adjust;
        $adjust++                   if ( $mult == -1 );
        $count++;

        # check that the Index is neither TOO High or TOO Low
        if ( $idx < 0 ) {
            $too_low    = 1;
            next;
        }
        if ( $idx > $#{ $variant_sizes } ) {
            $too_high   = 1;
            next;
        }

        # check that there is a variant for the size
        # we've got from the sizes array. This will always
        # be the case for now but allows for future development where
        # we can pass in a set of sizes that may or may not have
        # variants for it
        if ( exists $variants->{ $variant_sizes->[ $idx ] } ) {
            # check some stock of some sort exists

            my $found_stock = 0;
            my $variant_id  = $variants->{ $variant_sizes->[ $idx ] };

            # only need one of these "Stock Check" methods to
            # have some stock for us to be-able to use this variant
            CASE: {
                if ( defined $sample_stock ) {
                    if ( exists $sample_stock->{ $variant_id }
                         && $sample_stock->{ $variant_id } > 0 )
                    {
                        $ret_vid    = $variant_id;
                        $found_stock= 1;
                        last CASE;
                    }
                }
                if ( defined $stock_can_use ) {
                    if ( exists $stock_can_use->{ $variant_id }
                         && $stock_can_use->{ $variant_id } > 0 ) {
                        $ret_vid    = $variant_id;
                        $found_stock= 1;
                        last CASE;
                    }
                }
                my $deliv_items = get_incomplete_delivery_items_by_variant( $dbh, $variant_id, $channel_ref->{id} );
                if ( defined $deliv_items ) {
                    # if there are any delivery items at all for the variant
                    # then that will do, there is some stock at least
                    if ( scalar( keys %{ $deliv_items } ) ) {
                        $ret_vid    = $variant_id;
                        $found_stock= 1;
                        last CASE;
                    }
                }
            };

            # if we've found stock we quit the while loop and return the VID
            last        if ( $found_stock );
        }
    }

    return $ret_vid;
}

=head2 get_sample_room_stock_qty

  usage        : $hash_ref  = get_sample_room_stock_qty(
                        $database_handler,
                        {
                            type        => 'product' || 'variant',
                            id          => $product_id || $variant_id,
                            channel_id  => $channel_id,
                        }
                   );

  description  : This will return a quantity of stock for each variant in the Sample Room
                 either by product id or specific variant id that is in the sample room or
                 has been requested or is on it's way to the sample room. This can be used
                 to make decisions as to whether stock needs to be requested for the Sample
                 Room. You need to specifiy the Sales Channel for the search.

  parameters   : A Database Handler, A HASH Ref of Options containing the 'type' to use
                 is either for a product 'id' or a variant 'id' and the Sales Channel Id.
  returns      : A HASH Ref for each variant that has stock with the quantity of stock found.

=cut

sub get_sample_stock_qty :Export() {

    my ( $dbh, $args )      = @_;

    die "No DBH Connection Passed"          if ( !defined $dbh );
    die "No ARGS Hash Ref Passed"           if ( !defined $args || ref($args) ne "HASH" );

    die "No Type Specified in ARGS"         if ( !exists $args->{type} );
    die "No ID Specified in ARGS"           if ( !exists $args->{id} );
    die "No Channel Id Specified in ARGS"   if ( !exists $args->{channel_id} );
    die "Invalid Type Specified in ARGS"    if ( $args->{type} !~ m/^(product|variant)$/ );

    my $retval;

    my %qry_type    = (
            product => ' IN ( SELECT id FROM variant WHERE product_id = ? ) ',
            variant => ' = ? ',
        );
    my $qry_type    = $qry_type{ $args->{type} };
    my $type_id     = $args->{id};
    my $channel_id  = $args->{channel_id};

    my $qry =<<SQL
SELECT  variant_id, SUM(quantity) AS quantity
FROM    (
            SELECT  variant_id, SUM(quantity) AS quantity
            FROM    quantity
            WHERE   variant_id $qry_type
            AND     channel_id = ?
            AND     status_id IN ($FLOW_STATUS__SAMPLE__STOCK_STATUS,
                                  $FLOW_STATUS__CREATIVE__STOCK_STATUS,
                                  $FLOW_STATUS__TRANSFER_PENDING__STOCK_STATUS,
                                  $FLOW_STATUS__REMOVED_QUARANTINE__STOCK_STATUS,
                                  $FLOW_STATUS__RTV_TRANSFER_PENDING__STOCK_STATUS)
            GROUP BY 1
        UNION ALL
            SELECT  variant_id, COUNT(*) AS quantity
            FROM    stock_transfer
            WHERE   variant_id $qry_type
            AND     channel_id = ?
            AND     status_id = (
                        SELECT  id
                        FROM    stock_transfer_status
                        WHERE   status = 'Requested'
                    )
            GROUP BY 1
        UNION ALL
            SELECT  st.variant_id, COUNT(*) AS quantity
            FROM    stock_transfer st,
                    link_stock_transfer__shipment lsts,
                    shipment s
            WHERE   st.variant_id $qry_type
            AND     st.channel_id = ?
            AND     st.status_id = (
                        SELECT  id
                        FROM    stock_transfer_status
                        WHERE   status = 'Approved'
                    )
            AND     st.id = lsts.stock_transfer_id
            AND     lsts.shipment_id = s.id
            AND     s.shipment_status_id < 4
            GROUP BY 1
        ) AS total
GROUP BY 1
SQL
;
    my $sth = $dbh->prepare( $qry );
    $sth->execute( $type_id, $channel_id, $type_id, $channel_id, $type_id, $channel_id );

    while ( my $row = $sth->fetchrow_hashref() ) {
        $retval->{ $row->{variant_id} } = $row->{quantity};
    }

    return $retval;
}


1;

__END__
