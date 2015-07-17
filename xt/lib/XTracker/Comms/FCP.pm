package XTracker::Comms::FCP;

# Communication methods for updating the web application database

use strict;
use warnings;
use Carp;

use XTracker::Database::Product qw( get_fcp_sku );
use Scalar::Util 'blessed';

use Sub::Exporter -setup => {
    exports => [ qw{
        update_web_order_status
        update_web_stock_level
        check_and_update_variant_visibility
        amq_update_web_stock_level
        create_fcp_related_product delete_fcp_related_product
        ensure_fcp_related_products_fully_connected ensure_fcp_related_products_group_isolated
        create_website_store_credit update_website_store_credit
    } ]
};

### Subroutine : update_web_order_status         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_web_order_status {

    my ( $dbh_web, $args_ref ) = @_;

    my $orders_id    = $args_ref->{orders_id};
    my $order_status = $args_ref->{order_status};

    if ($orders_id && $order_status) {
        my $qry = "UPDATE orders SET order_status = ? WHERE id = ?";
        my $sth = $dbh_web->prepare($qry);
        $sth->execute($order_status, $orders_id);
    }

    return;
}

### Subroutine : update_web_stock_level         ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub update_web_stock_level {

    my ( $dbh_xt, $dbh_web, $args_ref ) = @_;

    my $variant_id      = $args_ref->{variant_id};
    my $quantity_change = $args_ref->{quantity_change};
    my $updated_by      = $args_ref->{updated_by} || 'XTRACKER - update_web_stock_level';

    my $sku = get_fcp_sku( $dbh_xt, { type => 'variant_id', id => $variant_id } );

    my $qry = "UPDATE stock_location SET no_in_stock = no_in_stock + ?, last_updated_by = ? WHERE sku = ?";
    my $sth = $dbh_web->prepare($qry);
    $sth->execute($quantity_change, $updated_by, $sku);

    # update variant visibility based on SKU stock level
    check_and_update_variant_visibility( $dbh_xt, $dbh_web, $variant_id, $sku );

    return;
}

sub check_and_update_variant_visibility {

    my ( $dbh_xt, $dbh_web, $variant_id, $sku ) = @_;

    # check a variant has stock
    # doesnt matter if stock is allocated/reserved or
    # anything else. The website should display if
    # it's available to buy or not
    # all we care about is if it has stock, it should be visible
    my $qry = "SELECT 1 FROM quantity WHERE variant_id = ? AND quantity > 0 LIMIT 1";
    my $sth = $dbh_xt->prepare($qry);
    $sth->execute($variant_id);

    if ($sth->rows) {
        my $web_qry = "UPDATE product set is_visible = 'T' WHERE sku = ?";
        my $web_sth = $dbh_web->prepare($web_qry);
        $web_sth->execute($sku);
    }

    return;
}

### Subroutine : amq_update_web_stock_level     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub amq_update_web_stock_level {
    my ( $msg_producer, $args_ref ) = @_;

    # catch old use of this function (first arg is a DB)
    if (not defined $msg_producer or not $msg_producer->can('transform_and_send')) {
       croak(
             'first argument should be something with a transform_and_send method, not a '
           . (ref($msg_producer)||'SCALAR')
       );
    }

    $msg_producer->transform_and_send('XT::DC::Messaging::Producer::Stock::Update',
        {
           dc_variant_id    => $args_ref->{variant_id},
           channel_id       => $args_ref->{channel_id},
           quantity_change  => $args_ref->{quantity_change},
        }
    );

    return;
}

### Subroutine : create_fcp_related_product     ###
# usage        :                                  #
# description  :                                  #
# parameters   : product_id, related product_id   #
# returns      : nothing                          #

sub create_fcp_related_product {
    my ( $dbh, $args_ref ) = @_;

    my $product_id         = $args_ref->{product_id};
    my $related_product_id = $args_ref->{related_product_id};
    my $type_id            = $args_ref->{type_id};
    my $sort_order         = defined $args_ref->{sort_order} ? $args_ref->{sort_order} : '0';
    my $position           = defined $args_ref->{position} ? $args_ref->{position} : '0';

    # Delete any existing links between the pids
    my $dqry = "DELETE FROM related_product WHERE search_prod_id = ? AND related_prod_id = ? AND type_id = ?";
    $dbh->do( $dqry, undef, ( $product_id, $related_product_id, $type_id ) );

    # Delete anything in the slot we want to insert into
    if ( $sort_order || $position ) { # i.e if we have position or sort_order then run this query o/w don't coz it deletes all data for that search_prod_id
        $dqry = "DELETE FROM related_product WHERE search_prod_id = ? AND type_id = ? AND sort_order = ? and position = ?";
        $dbh->do( $dqry, undef, ( $product_id, $type_id, $sort_order, $position ) );
    }

    # And insert the new link
    my $qry = <<EOQ;
INSERT INTO related_product
       ( search_prod_id, related_prod_id, type_id, sort_order, created_dts,       created_by, last_updated_dts,  last_updated_by, position )
VALUES ( ?,              ?,               ?,       ?,          current_timestamp, 'XTRACKER', current_timestamp, 'XTRACKER',      ?        )
EOQ
    my $sth = $dbh->prepare( $qry );
    $sth->execute ($product_id, $related_product_id, $type_id, $sort_order, $position);

    return;
}


### Subroutine : delete_fcp_related_product     ###
# usage        :                                  #
# description  :                                  #
# parameters   : product_id, related product_id   #
# returns      :                                  #

sub delete_fcp_related_product {

    my ( $dbh, $args_ref ) = @_;

    my $product_id          = $args_ref->{product_id};
    my $related_product_id  = $args_ref->{related_product_id};
    my $type_id             = $args_ref->{type_id};

    my $qry = "delete from related_product where search_prod_id = ? and related_prod_id = ? and type_id = ?";
    my $sth = $dbh->prepare( $qry );
    $sth->execute ($product_id, $related_product_id, $type_id);

    return;
}

=head2 ensure_fcp_related_products_fully_connected

Given a set of product IDs, ensure that relationships exist between all of
them in both directions.

Takes named parameters as

    ensure_fcp_related_products_fully_connected(
        dbh         => $database_handle,
        product_ids => [ $pid1, $pid2, $pid3 ],
        type_id     => $type_id
    );

Upon success, the function will return.  Upon failure, the function will throw
an exception.

Given the set of product IDs (1, 2, 3, 4), it will ensure relationships 1->2,
1->3, 1->4, 2->1, 2->3, 2->4, 3->1, 3->2, 3->4, 4->1, 4->2, 4->3.  In the
vocabulary of Graph Theory, it ensures that there is a
Complete Directed Graph between these product IDs.

=cut

sub ensure_fcp_related_products_fully_connected {
    my $p = _ensure_fcp_related_products_fully_connected_parameter_check(@_);

    my ($dbh, $product_ids, $type_id) = @$p{ qw{ dbh product_ids type_id } };

    # Ensure that all the desired graph edges are present
    #
    # Each graph edge connects two distinct products.
    #
    # So if there are less than two distinct products in total, then there
    # is nothing to do.
    return if scalar @$product_ids < 2;

    my $query = _ensure_fcp_related_products_fully_connected_query($p);

    my $insert_sth = $dbh->prepare($query->{query});

    $insert_sth->execute(@{ $query->{bind_values} });

    return;
}

=head2 ensure_fcp_related_products_group_isolated

Given a set of product IDs, ensure that no relationships exist between any of
the products in the set and any product outside of the set

Takes named parameters as

    ensure_fcp_related_products(
        dbh         => $database_handle,
        product_ids => [ $pid1, $pid2, $pid3 ],
        type_id     => $type_id
    );

Upon success, the function will return.  Upon failure, the function will throw
an exception.

=cut

sub ensure_fcp_related_products_group_isolated {
    my $p = _ensure_fcp_related_products_fully_connected_parameter_check(@_);

    my ($dbh, $product_ids, $type_id) = @$p{ qw{ dbh product_ids type_id } };

    # If there are no products, then there is nothing to do
    return if !@$product_ids;

    # Ensure that no undesired graph edges are present
    foreach (
        [ 'IN',     'NOT IN' ],
        [ 'NOT IN', 'IN'     ]
    ) {
        my ($search_prod_op, $related_prod_op) = @$_;

        my $product_ids_set_str = '(' . join(',' => ('?') x scalar @$product_ids) . ')';

        my $delete_query = join ' ' =>
            'DELETE FROM related_product',
            'WHERE', join(' AND ' =>
                join(' ' => 'search_prod_id',  $search_prod_op,  $product_ids_set_str),
                join(' ' => 'related_prod_id', $related_prod_op, $product_ids_set_str),
                'type_id = ?'
            );
        my $delete_sth = $dbh->prepare($delete_query);
        $delete_sth->execute(@$product_ids, @$product_ids, $type_id);
    }

    return;
}

sub _ensure_fcp_related_products_fully_connected_parameter_check {
    my (%p) = @_;
    my ($dbh, $product_ids, $type_id) =
        @p{ qw{ dbh product_ids type_id } };

    # Check parameters
    die q{argument 'dbh' is not Object} if !(defined $dbh && blessed($dbh));

    if (!(
        defined $product_ids
        && (ref $product_ids eq 'ARRAY')
        && List::MoreUtils::all { defined $_ && m{^\d+$}so } @$product_ids
    )) {
        die q{argument 'product_ids' is not ArrayRef[Int]};
    }

    if (!(
        defined $type_id && !ref $type_id && $type_id ne ''
    )) {
        die q{argument 'type_id' is not non-empty string};
    }

    return \%p;
}

# Put together the SQL query and bind parameters to be used by
# the function ensure_fcp_related_products_fully_connected

sub _ensure_fcp_related_products_fully_connected_query {
    my ($p) = @_;
    my ($dbh, $product_ids, $type_id) = @$p{ qw{ dbh product_ids type_id } };

    # There is an extended commentary for the SQL query at the end of the file

    my $product_ids_query =
        'SELECT id FROM searchable_product WHERE id IN '
        . '(' . join(',' => ('?') x @$product_ids) . ')';

    my @select_fields = (
        [ search_prod_id   => 'search_prod.id'    ],
        [ related_prod_id  => 'related_prod.id'   ],
        [ type_id          => '?'                 ],
        [ sort_order       => '0'                 ],
        [ position         => '0'                 ],
        [ created_dts      => 'current_timestamp' ],
        [ created_by       => q{'XTRACKER'}       ],
        [ last_updated_dts => 'current_timestamp' ],
        [ last_updated_by  => q{'XTRACKER'}       ],
    );

    my @insert_fields = map { $_->[0] } @select_fields;

    my $query = join ' ' =>
        'INSERT INTO related_product (' . join(', ' => @insert_fields) . ')',
        'SELECT', join(', ' => map { "$_->[1] AS $_->[0]" } @select_fields),
        'FROM',
            # Cross the list of product IDs with itself, so that we
            # generate rows joining every product to every other product
            "($product_ids_query) search_prod",
            "CROSS JOIN ($product_ids_query) related_prod",

            # We only want to create rows for relationships that don't
            # already exist.  So do an anti-join against the database
            # table.  This requires a LEFT JOIN and a WHERE condition
            # which is IS NULL over a non-NULL column in the database
            # table.
            'LEFT JOIN related_product rp',
                'ON', join(' AND ' =>
                    'rp.search_prod_id = search_prod.id',
                    'rp.related_prod_id = related_prod.id',
                    'rp.type_id = ?'
                ),
            'WHERE', join(' AND ' =>
                'search_prod.id <> related_prod.id',
                'rp.search_prod_id IS NULL'
            );

    my @bind_values = ( $type_id, @$product_ids, @$product_ids, $type_id );

    return {
        query       => $query,
        bind_values => \@bind_values
    };
}

### Subroutine : create_website_store_credit     ###
# usage        :                                  #
# description  : creating a credit using direct database insert rather than SOAP call     #
# parameters   : web database handle, {is_customer_number, currency_code value}   #
# returns      : nothing                          #

sub create_website_store_credit {

    my ( $dbh, $args_ref ) = @_;

    if ( !$args_ref->{is_customer_number} ) {
        die "No customer number provided\n";
    }

    if ( !$args_ref->{currency_code} ) {
        die "No currency code provided\n";
    }

    if ( !$args_ref->{credit_value} ) {
        die "No credit value provided\n";
    }

    # round credit value to 2 dp before copying to website
    $args_ref->{credit_value} = sprintf( "%.2f", $args_ref->{credit_value} );

    my $qry = "insert into customer_credit (customer_id, currency_code, value, is_valid, description, created_dts, created_by, last_updated_dts, last_updated_by) values (?, ?, ?, 'T', 'Created', current_timestamp, 'XTRACKER', current_timestamp, 'XTRACKER')";
    my $sth = $dbh->prepare( $qry );
    $sth->execute ($args_ref->{is_customer_number}, $args_ref->{currency_code}, $args_ref->{credit_value});

    return;
}


### Subroutine : update_website_store_credit     ###
# usage        :                                  #
# description  : update a credit using direct database insert rather than SOAP call     #
# parameters   : web database handle, {is_customer_number, currency_code value is_valid}   #
# returns      : nothing                          #

sub update_website_store_credit {
    die 'No, we shouldn\'t be updating customer credit tables from XTracker any more!';
#    my ( $dbh, $args_ref ) = @_;
#
#    if ( !$args_ref->{is_customer_number} ) {
#        die "No customer number provided\n";
#    }
#
#    if ( !$args_ref->{currency_code} ) {
#        die "No currency code provided\n";
#    }
#
#    if ( not defined($args_ref->{credit_value}) ) {
#        die "No credit value provided\n";
#    }
#
#    if ( !$args_ref->{is_valid} ) {
#        die "No valid parameter provided\n";
#    }
#
#    # round credit value to 2 dp before copying to website
#    $args_ref->{credit_value} = sprintf( "%.2f", $args_ref->{credit_value} );
#
#    my $qry = "update customer_credit set currency_code = ?, value = ?, is_valid = ?, last_updated_dts = current_timestamp, last_updated_by = 'XTRACKER' where customer_id = ?";
#    my $sth = $dbh->prepare( $qry );
#    $sth->execute ($args_ref->{currency_code}, $args_ref->{credit_value}, $args_ref->{is_valid}, $args_ref->{is_customer_number});
#
#    return;
}

1;

__END__

# = Extended commentary for _ensure_fcp_related_products_fully_connected_query =
#
# == Summary of the whole operation ==
#
# We need to ensure that there are records in the table "related_product"
# which link every input product ID with every other input product ID.
#
# The product IDs appear in the table "related_product" in the columns
# "search_prod_id" and "related_prod_id".  These columns have foreign key
# constraints
#
#     CONSTRAINT `FK_related_product_1` FOREIGN KEY (`search_prod_id`)
#         REFERENCES `searchable_product` (`id`) ON DELETE CASCADE,
#     CONSTRAINT `FK_related_product_2` FOREIGN KEY (`related_prod_id`)
#         REFERENCES `searchable_product` (`id`) ON DELETE CASCADE,
#
# which we need to take account of.
#
# Both of these foreign key constraints constrain the set of allowable values
# to the set of "id" values in the table "searchable_product".  This in effect
# constrains the set of product ID values for this whole operation.
#
# So we need to constrain the set of input product IDs to the set of "id"
# values in the "searchable_product" table.
#
# Once we have constrained the set of input product IDs, we can go about
# creating a set of tuples which represents every product ID linked with
# every other product ID
#
# To do this we need to do the Cartesian product of the set of product IDs
# with itself, and then subtract all tuples which would otherwise represent
# product IDs linked to themselves.
#
# We then need to create records in the database table where links do not
# already exist.
#
# == How we go about doing it ==
#
# Assume we have 4 input product IDs [ 1, 2, 3, 4 ] and product ID 4 does not
# exist within the table "searchable_product".
#
# The first job is to validate the set of input product IDs against the set of
# values of the "id" column in the table "searchable_product".  This is
# effectively a set intersection operation, so we can compute it either way
# round.  So we could equally take the set of values of the "id" column in
# "searchable_product" and intersect that with the set of input product IDs.
# This can be done as:
#
#     SELECT id FROM searchable_product WHERE id IN (1, 2, 3, 4)
#
# which in our example case will result in
#
#      id
#     ----
#       1
#       2
#       3
#
# To create tuples representing links between every product ID and every other
# product ID, we need to do a Cartesian product of this set with itself, which
# we can do using a CROSS JOIN.
#
# (Computing the input set for each side of the the CROSS JOIN requires a
# query of the table "searchable_product", so we could think in terms of
# computing it once and storing the results in a temporary table.  However,
# this would mean we would need to do additional things to mitigate potential
# concurrency issues.  If we just include this subquery on each side of the
# CROSS JOIN then everything can happen in one query, which should cover many
# of the concurrency issues.  The subquery we are using should be relatively
# cheap to execute, so this should not be a problem.)
#
# Also we need to name the relations on either side of the CROSS JOIN, which
# we can do by putting the name after the query in parentheses.
#
#     (SELECT id FROM searchable_product WHERE id IN (1, 2, 3, 4))
#         search_prod
#     CROSS JOIN
#     (SELECT id FROM searchable_product WHERE id IN (1, 2, 3, 4))
#         related_prod
#
# The result of this join will be a table with each validated product ID next
# to every validated product ID.  (The number of rows will be the square of
# the number of validated product IDs.)
#
#      search_prod.id | related_prod.id
#     ----------------+-----------------
#            1        |        1
#            1        |        2
#            1        |        3
#            2        |        1
#            2        |        2
#            2        |        3
#            3        |        1
#            3        |        2
#            3        |        3
#
# But we do not want to link a product to itself, so we will add a WHERE
# clause later on to discard these.
#
#     ...
#     WHERE search_prod.id <> related_prod.id
#
# We now have a set of rows for every one of which we need to ensure that
# there is a corresponding row in the database
#
#      search_prod.id | related_prod.id
#     ----------------+-----------------
#            1        |        2
#            1        |        3
#            2        |        1
#            2        |        3
#            3        |        1
#            3        |        2
#
# There may already be rows in the database corresponding to some or all of
# these rows.  We only want the rows for which there is not already a
# corresponding row in the database.
#
# So first we LEFT JOIN the database table, matching on both of the product ID
# columns.  We also need to constrain the LEFT JOIN to the target product
# relation type.
#
#     ...
#     LEFT JOIN related_product rp
#         ON
#             rp.search_prod_id = search_prod.id
#             AND rp.related_prod_id = related_prod.id
#             AND rp.type_id
#     ...
#
# Where there is no row in the database table, the corresponding columns in
# the LEFT JOIN result will be NULL.  Assuming the database already contains
# rows for (1, 2) and (2, 1), then we would now have:
#
#      search   | related  | rp.search | rp.related | rp
#      _prod.id | _prod.id | _prod_id  |  _prod_id  | .type_id
#     ----------+----------+-----------+------------+----------
#         1     |     2    |     1     |     2      | COLOUR
#         1     |     3    |   NULL    |   NULL     |  NULL
#         2     |     1    |     2     |     1      | COLOUR
#         2     |     3    |   NULL    |   NULL     |  NULL
#         3     |     1    |   NULL    |   NULL     |  NULL
#         3     |     2    |   NULL    |   NULL     |  NULL
#
# We want to add new records in cases where there currently is no existing
# record.  So we add a WHERE clause to keep only rows which are NULL for the
# columns corresponding to the database table.  As it happens we only need
# test one NOT NULL column in the database --- since the values in the
# database column cannot be NULL, the only time we will see a NULL is when
# there is no row in in the database, and the LEFT JOIN populates the join
# output fields with NULL.
#
#     ...
#     WHERE
#         ...
#         AND rp.search_prod_id IS NULL
#
# We should now have a set of rows for which we need to add corresponding rows
# in the database.
#
#      search   | related  | rp.search | rp.related | rp
#      _prod.id | _prod.id | _prod_id  |  _prod_id  | .type_id
#     ----------+----------+-----------+------------+----------
#         1     |     3    |   NULL    |   NULL     |  NULL
#         2     |     3    |   NULL    |   NULL     |  NULL
#         3     |     1    |   NULL    |   NULL     |  NULL
#         3     |     2    |   NULL    |   NULL     |  NULL
#
# To make complete rows to insert into the database we need to add the missing
# columns, which we can by adding fields to the outer SELECT.
#
#     SELECT
#         search_prod.id     AS search_prod_id,
#         related_prod.id    AS related_prod_id,
#         'COLOUR'           AS type_id,
#         0                  AS sort_order,
#         0                  AS position,
#         current_timestamp  AS created_dts,
#         'XTRACKER'         AS created_by,
#         current_timestamp' AS last_updated_dts,
#         'XTRACKER'         AS last_updated_by
#     FROM
#         ...
#
# We then use INSERT ... SELECT to add the rows produced by the SELECT to the
# database.  The complete query would look like:
#
#     INSERT INTO related_product
#         ( search_prod_id, related_prod_id, type_id, sort_order, position,
#           created_dts, created_by, last_updated_dts, last_updated_by )
#     SELECT
#         search_prod.id     AS search_prod_id,
#         related_prod.id    AS related_prod_id,
#         'COLOUR'           AS type_id,
#         0                  AS sort_order,
#         0                  AS position,
#         current_timestamp  AS created_dts,
#         'XTRACKER'         AS created_by,
#         current_timestamp' AS last_updated_dts,
#         'XTRACKER'         AS last_updated_by
#     FROM
#         (SELECT id FROM searchable_product WHERE id IN (1, 2, 3, 4))
#             search_prod
#         CROSS JOIN
#         (SELECT id FROM searchable_product WHERE id IN (1, 2, 3, 4))
#             related_prod
#         LEFT JOIN related_product rp
#             ON
#                     rp.search_prod_id  = search_prod.id
#                 AND rp.related_prod_id = related_prod.id
#                 AND rp.type_id = 'COLOUR'
#     WHERE
#         search_prod.id <> related_prod.id
#         AND rp.search_prod_id IS NULL
