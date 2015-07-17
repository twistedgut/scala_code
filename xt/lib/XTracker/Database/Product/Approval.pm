package XTracker::Database::Product::Approval;

use strict;
use warnings;
use Carp;

use Perl6::Export::Attrs;

use XTracker::Database;
use XTracker::Database::Stock;
use XTracker::Database::Utilities qw( results_list results_hash2 );
use XTracker::Image               qw( get_images );



### Subroutine : archive_product_approval_list                                       ###
# usage        : archive_product_approval_list( { dbh => $dbh, list => \@archive } );  #
# description  : Archives a copy of Product Approval list                              #
# parameters   : dbh => $dbh, list => \@archive                                        #
# returns      : return $sth->finish                                                   #

sub archive_product_approval_list :Export() {

    my $p = shift;

    if ( $p->{list} ) {

        my $qry = qq{
insert into product_approval_archive ( list, created_timestamp, operator_id, title )
values ( ?, now(), ?, ? )
};

        my $sth = $p->{dbh}->prepare( $qry ) or die "prepare failed: " . $p->{dbh}->errstr;

        $sth->execute( $p->{list}, $p->{operator_id}, $p->{title} );

        $sth->finish;

    }
    elsif ( $p->{id} ) {

        my $qry = qq{
select paa.list, paa.created_timestamp, to_char(paa.created_timestamp, 'DD-MM-YYYY  HH24:MI') as created_date, o.name
from product_approval_archive paa, operator o
where paa.operator_id = o.id
and paa.id = ?
};

        my $sth = $p->{dbh}->prepare( $qry );

        $sth->execute( $p->{id} );

        my $row = $sth->fetchrow_hashref();

        $sth->finish;

        return ( $row->{list}, $row->{created_timestamp}, $row->{name}, $row->{title}, $row->{created_date} );

    }
    else {

        my $qry = qq{
select paa.id, paa.list, paa.created_timestamp, to_char(paa.created_timestamp, 'DD-MM-YYYY  HH24:MI') as created_date, paa.title, o.name, o.username
from product_approval_archive paa, operator o
where paa.operator_id = o.id
order by created_timestamp desc
};

        my $sth = $p->{dbh}->prepare( $qry );

        $sth->execute( );

        my @rows;

        while ( my $row = $sth->fetchrow_hashref() ) {

            push @rows, $row;

        }

        $sth->finish;

        return \@rows;

    }

}

### Subroutine : delete_approval_list            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub delete_approval_list :Export() {

    my ($dbh, $id)  = @_;

    my $qry = "delete from product_approval_archive where id = ?";
    my $sth = $dbh->prepare($qry);
    $sth->execute($id);

    return;
}

### Subroutine : build_approval_list            ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub build_approval_list :Export() {

    my ($arg_ref)   = @_;

    my $dbh_dc1         = $arg_ref->{dbh_dc1};
    my $dbh_dc2         = $arg_ref->{dbh_dc2};
    my $product_ids_ref = $arg_ref->{product_ids};
    my $channel         = $arg_ref->{channel};

    my @submitted_product_ids   = @$product_ids_ref;
    my $product_ids_txt     = join(', ', @submitted_product_ids);

    my $qry_product
        = qq{

             SELECT
                p.id AS product_id,
                d.designer,
                pa.name,
                pa.description,
                c.classification,
                pt.product_type,
                s.season,
                col.colour,
                pch.live,
                pch.visible,
                pch.cancelled,
                to_char(pch.upload_date, 'DD-Mon-YY') AS upload_date,
                CASE
                    WHEN pch.upload_date IS NULL THEN false
                    ELSE true
                END AS has_upload,
                CASE
                    WHEN pch.live IS false THEN true
                    ELSE false
                END AS not_uploaded,
                '-' AS upload_description
            FROM product p
            INNER JOIN product_channel pch
                ON (p.id = pch.product_id AND pch.channel_id = (SELECT id FROM channel WHERE name = '$channel'))
            INNER JOIN classification c
                ON (p.classification_id = c.id)
            INNER JOIN product_type pt
                ON (p.product_type_id = pt.id)
            INNER JOIN season s
                ON (p.season_id = s.id)
            INNER JOIN colour col
                ON (p.colour_id = col.id)
            INNER JOIN product_attribute pa
                ON (p.id = pa.product_id)
            INNER JOIN designer d
                ON (p.designer_id = d.id)
            WHERE p.id IN ($product_ids_txt)
        };

    my $sth_product = $dbh_dc1->prepare($qry_product);
    $sth_product->execute();

    my $approval_items_ref  = results_hash2($sth_product, 'product_id');
    my %approval_items      = %$approval_items_ref;


    ### find submitted product_id's which do not appear in the result set
    my @resultset_product_ids = keys %approval_items;
    my %not_in_resultset;
    @not_in_resultset {@submitted_product_ids} = ();
    delete @not_in_resultset {@resultset_product_ids};
    my @invalid_pids = keys %not_in_resultset;


    ### build list of approval items, ordered as originally submitted
    my @approval_list   = ();

    # This is a little weird...
    my $dbh_for_images = $dbh_dc1 ? $dbh_dc1 : $dbh_dc2;
    my $schema = XTracker::Database::get_schema_using_dbh($dbh_for_images, 'xtracker_schema');
    foreach my $product_id ( @submitted_product_ids ) {

        ### skip this product_id if it does not exist in the approval items result set
        next if grep { /$product_id/ } keys %not_in_resultset;

        my %item_hash   = %{ $approval_items_ref->{$product_id} };

        $item_hash{image} = get_images({
            product_id => $product_id,
            live => $item_hash{live},
            size => 'm',
            schema => $schema,
        });

        my $qry_stock = qq{
                             SELECT
                                ordered,
                                delivered,
                                (main_stock - (reserved + pre_pick + cancel_pending)) as free_stock,
                                sample_stock,
                                reserved
                            FROM product.stock_summary
                            WHERE product_id = ?
                            AND channel_id = (SELECT id FROM channel WHERE name = ?)
        };

        # get dc1 stock info
        my $sth_stock = $dbh_dc1->prepare($qry_stock);
        $sth_stock->execute($product_id, $channel);

        $item_hash{dc1_stock} = $sth_stock->fetchrow_hashref();

        # get dc2 stock info
        $sth_stock = $dbh_dc2->prepare($qry_stock);
        $sth_stock->execute($product_id, $channel);

        $item_hash{dc2_stock} = $sth_stock->fetchrow_hashref();


        # check if product is cancelled
        my $qry_po = qq{select cancelled from product_channel where product_id = ? AND channel_id = (SELECT id FROM channel WHERE name = ?)};

        # get dc1 info
        my $sth_po = $dbh_dc1->prepare($qry_po);
        $sth_po->execute($product_id, $channel);
        while ( my $row = $sth_po->fetchrow_hashref ) {
            $item_hash{dc1_cancelled} = $row->{cancelled};
        }

        # get dc2 info
        $sth_po = $dbh_dc2->prepare($qry_po);
        $sth_po->execute($product_id, $channel);
        while ( my $row = $sth_po->fetchrow_hashref ) {
            $item_hash{dc2_cancelled} = $row->{cancelled};
        }

        ### get delivery details if product not yet uploaded
        if ( $approval_items_ref->{$product_id}{not_uploaded} ) {
            $item_hash{delivery_details_dc1}    = get_availability_details( { dbh => $dbh_dc1, product_id => $product_id, channel => $channel } );
            $item_hash{delivery_details_dc2}    = get_availability_details( { dbh => $dbh_dc2, product_id => $product_id, channel => $channel } );
        }

        ### delete original approval item hash elements as we go
        delete $approval_items{$product_id};

        ### add new item entry to the list
        push @approval_list, \%item_hash;

    }

    return (\@approval_list, \@invalid_pids);

} ### END sub build_approval_list



### Subroutine : get_availability_details       ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub get_availability_details :Export() {

    my $arg_ref     = shift;
    my $dbh         = $arg_ref->{dbh};
    my $product_id  = $arg_ref->{product_id};
    my $channel     = $arg_ref->{channel};

    my $qry_delivery
        = q{SELECT v.product_id, po.id AS purchase_order_id, po.purchase_order_number, s.season,
                to_char(so.start_ship_date, 'DD-Mon-YY') AS start_ship_date, to_char(so.cancel_ship_date, 'DD-Mon-YY') AS cancel_ship_date,
                sot.type AS stock_order_type, sos.status AS stock_order_status, soi.cancel AS stock_order_item_cancel,
                soi.quantity AS stock_order_item_quantity, soit.type AS stock_order_item_type, sois.status AS stock_order_item_status,
                di.delivery_id, to_char(d.date, 'DD-Mon-YY HH24:MI') AS delivery_date, dt.type AS delivery_type, ds.status AS delivery_status,
                di.packing_slip AS delivery_item_packing_slip, di.quantity AS delivery_item_quantity, di.cancel AS delivery_item_cancel
            FROM purchase_order po INNER JOIN stock_order so
                ON so.purchase_order_id = po.id INNER JOIN stock_order_item soi
                ON soi.stock_order_id = so.id LEFT JOIN stock_order_type sot
                ON so.type_id = sot.id LEFT JOIN stock_order_status sos
                ON so.status_id = sos.id LEFT JOIN stock_order_item_type soit
                ON soi.type_id = soit.id LEFT JOIN stock_order_item_status sois
                ON soi.status_id = sois.id INNER JOIN variant v
                ON soi.variant_id = v.id INNER JOIN product p
                ON v.product_id = p.id INNER JOIN product_attribute pa
                ON pa.product_id = p.id  LEFT JOIN season s
                ON po.season_id = s.id LEFT JOIN link_delivery_item__stock_order_item l_di_soi
                ON soi.id = l_di_soi.stock_order_item_id INNER JOIN delivery_item di
                ON l_di_soi.delivery_item_id = di.id INNER JOIN delivery d
                ON di.delivery_id = d.id LEFT JOIN delivery_type dt
                ON d.type_id = dt.id LEFT JOIN delivery_status ds
                ON d.status_id = ds.id
            WHERE p.id = ?
            AND po.channel_id = (SELECT id FROM channel WHERE name = ?)
            AND dt.type = 'Stock Order'
            ORDER BY d.date, d.id;
        };

    my $sth_delivery = $dbh->prepare($qry_delivery);
    $sth_delivery->execute($product_id, $channel);

    my $delivery_ref = results_list($sth_delivery);

    return $delivery_ref;

} ### END sub get_availability_details

1;

__END__

