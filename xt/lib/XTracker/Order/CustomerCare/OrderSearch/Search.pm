package XTracker::Order::CustomerCare::OrderSearch::Search;

use NAP::policy "tt", qw( exporter );

use DateTime;

use Perl6::Export::Attrs;
use XTracker::Constants ':database';
use XTracker::Constants::Regex ':sku';
use XTracker::Constants::FromDB qw(
    :flag
    :order_status
    :shipment_status
);

use XTracker::Utilities     qw( trim isdates_ok );
use XTracker::Database::Utilities  qw( enliken is_valid_database_id );
use XTracker::Logfile qw( xt_logger );
use XTracker::DBEncode qw( decode_db );
my @any_query_types = qw( customer_number product_id shipment_id order_number pre_order_number );

=head1 NAME

XTracker::Order::CustomerCare::OrderSearch::Search

=head1 METHODS

=head2 find_orders($dbh, $args, $limit) : \@results

Note that this sub has been altered to return sample shipments too, hence it's
misnamed.

=cut

sub find_orders :Export(:search) {
    my ( $dbh, $arghash, $limit ) = @_;

    my ( $type, $terms, $sales_channel )
        = @$arghash{ qw( search_type search_terms sales_channel ) };

    die "No search type provided, and one must be"
        unless $type;

    if ( $type eq 'by_date' ) {
        # date queries actually have a different result set needing
        # different processing, so we just handle that elsewhere

        return _find_orders_by_date( $dbh, $arghash, $limit );
    }

    # Do nothing if we don't have search terms or if the search terms are whitespace only
    # This is done after date search because it should not apply there!
    return unless ( defined $terms && $terms =~ /\S+/ );

    if ( $type eq 'any' ) {
        my @coalesced;
        my %seen;

        foreach my $any_type ( @any_query_types ) {
            my $interim = find_orders( $dbh, { search_type   => $any_type,
                                               search_terms  => $terms,
                                               sales_channel => $sales_channel },
                                        $limit
                                     );

            # Only add new shipments to the array we return
            push @coalesced, grep { !$seen{$_->{id}}++ } @$interim;
        }
        # Make sure our array is sorted by 'id' - this is a little nasty, the
        # idea is that it's supposed to match the queries' 'order by' statement
        # below, so it'll have to be manually kept in sync.
        @coalesced = sort { $b->{id} <=> $a->{id} } @coalesced;

        return \@coalesced;
    }

    my ( $query, @args ) = _build_order_query_args( $type, $terms, $sales_channel );

    my @results;

    if ( $query && @args ) {
        if ( $limit ) {
            $query .= "\nLIMIT ?";
            push @args, $limit;
        }
        my $sth = $dbh->prepare( $query );

        $sth->execute( @args );

        while ( my $row = $sth->fetchrow_hashref() ) {
            $row->{$_} = decode_db( $row->{$_} ) for (qw(first_name last_name));
            push @results, $row;
        }
    }

    return \@results;
}

sub _find_orders_by_date {
    my ( $dbh, $arghash, $limit ) = @_;

    my ( $query, @args )
      = _build_date_query_args( $arghash, $arghash->{sales_channel});

    if ( $limit ) {
        $query .= "\nLIMIT ?";
        push @args, $limit;
    }

    my $sth = $dbh->prepare( $query );
    $sth->execute( @args );

    my @results;

    while ( my $row = $sth->fetchrow_hashref() ) {
        $row->{$_} = decode_db( $row->{$_} ) for (qw(first_name last_name));
        push @results, $row;
    }

    return \@results;
}

# Let's define a pile of SQL fragments, the better to make queries with!
my $customer_query = {
    select =>  <<EOS
SELECT DISTINCT
    o.id AS order_id,
    o.order_nr,
    s.id,
    TO_CHAR(s.date, 'DD-MM-YYYY HH24:MI') AS date,
    ss.status,
    sc.class,
    c.first_name,
    c.last_name,
    COALESCE(ch.name,sch.name) AS sales_channel,
    ccat.category as customer_category,
    oa.country
EOS
,

    # Use this hash if you're joining against a shipment (aliased to 's')
    shipment_joins => <<EOJ
JOIN shipment_status ss ON s.shipment_status_id = ss.id
JOIN shipment_class sc  ON s.shipment_class_id = sc.id

-- orders joins
LEFT JOIN link_orders__shipment los ON s.id = los.shipment_id
LEFT JOIN orders o                  ON los.orders_id = o.id
LEFT JOIN channel ch                ON o.channel_id = ch.id
LEFT JOIN customer c                ON o.customer_id = c.id
LEFT JOIN customer_category ccat    ON c.category_id = ccat.id

-- sample joins
LEFT JOIN link_stock_transfer__shipment lsts ON s.id = lsts.shipment_id
LEFT JOIN stock_transfer st                  ON lsts.stock_transfer_id = st.id
LEFT JOIN channel sch                        ON st.channel_id = sch.id
EOJ
,

    # Use this hash if you're joining against an order (aliased to 'o')
    order_joins => <<EOJ
JOIN channel ch                ON o.channel_id = ch.id
JOIN customer c                ON o.customer_id = c.id
JOIN customer_category ccat    ON c.category_id = ccat.id
JOIN link_orders__shipment los ON o.id = los.orders_id
JOIN shipment s                ON los.shipment_id = s.id
JOIN order_address oa          ON s.shipment_address_id = oa.id
JOIN shipment_status ss        ON s.shipment_status_id = ss.id
JOIN shipment_class sc         ON s.shipment_class_id = sc.id
-- This is a 'pseudo-join' to make the COALESCE in the SELECT and the
-- channel_name WHERE statements work. Suggestions for a less-hacky
-- implementation (preferably in the SELECT clause) welcome
LEFT JOIN (VALUES (NULL)) AS sch (name) ON 1=1
EOJ
,

    # Use this hash if you're joining against a shipping address (aliased to 'oa')
    address_join => <<EOJ
LEFT JOIN order_address oa ON oa.id = s.shipment_address_id
EOJ
,
    # These are subrefs that return a list, the first element of which is the
    # query, and the subsequent ones are their bind parameters
    where => {
        channel_name => sub {
            my ($channel_name) = @_;
            return () unless $channel_name;
            return (q{(ch.name = ? OR sch.name = ?)}, ($channel_name) x 2);
        },
    },

    order_by => 'ORDER BY s.id DESC',
};

# variant for date queries
my $date_query = {
    select => q{ o.id as order_id,
                 o.order_nr,
                 round ( o.total_value + o.store_credit,2) total_value,
                 c.first_name,
                 c.last_name,
                 cc.category AS customer_category,
                 oa.country,
                 cur.currency,
                 of.id AS first_order,
                 ch.name AS sales_channel,
                 s.shipment_type_id,
                 osl.date AS credit_hold_date
    },

    tables => qq{ orders o
             LEFT JOIN order_flag of  ON o.id = of.orders_id
                                     AND of.flag_id = $FLAG__1ST
             LEFT JOIN order_status_log osl  ON o.id = osl.orders_id
                                            AND osl.order_status_id = $ORDER_STATUS__CREDIT_HOLD,
                  customer c,
                  customer_category cc,
                  order_address oa,
                  currency cur,
                  channel ch,
                  link_orders__shipment los,
                  shipment s
    },

    where => q{       o.id = los.orders_id
                  AND los.shipment_id = s.id
                  AND o.customer_id = c.id
                  AND c.category_id = cc.id
                  AND s.shipment_address_id = oa.id
                  AND o.currency_id = cur.id
                  AND o.channel_id = ch.id
    },

    channel_name => q{ AND ch.name = ? }
};

sub _build_date_query_args {
    my ( $search_terms, $sales_channel ) = @_;

    die "No search terms provided for date search"
        unless $search_terms;

    die "No date_type provided for date search"
        unless exists $search_terms->{date_type}
                   && $search_terms->{date_type};

    die "No date provided for date search"
        unless exists $search_terms->{date}
                   && $search_terms->{date};

    die "Date '$search_terms->{date}' not recognized as valid"
        unless isdates_ok( $search_terms->{date} );

    my $query;

    if ( $search_terms->{date_type} eq 'dispatch' ) {
        $query = qq{ SELECT DISTINCT
                    TO_CHAR(ssl.date, 'HH24:MI') AS date,
                            $date_query->{select}
                       FROM shipment_status_log ssl,
                            $date_query->{tables}
                      WHERE DATE_TRUNC('day', ssl.date) = ?
                        AND ssl.shipment_status_id = $SHIPMENT_STATUS__DISPATCHED
                        AND s.id = ssl.shipment_id
                        AND $date_query->{where}
                   };
    }
    else {
        $query = qq{ SELECT DISTINCT
                    TO_CHAR(o.date, 'HH24:MI') AS date,
                            $date_query->{select}
                       FROM $date_query->{tables}
                      WHERE DATE_TRUNC('day', o.date) = ?
                        AND $date_query->{where}
                    };
    }

    my @args = ( $search_terms->{date} );

    $sales_channel = trim( $sales_channel );

    if ( $sales_channel ) {
        $query .= $date_query->{channel_name};
        push @args, $sales_channel;
    }
    #Order BY o.date
    $query .= "\nORDER BY 1 DESC";

    return $query, @args;
}

# different enough from the main queries
sub _build_name_query_args {
    my ( $search_terms, $channel_name ) = @_;

    my ( $first_name, $last_name );
    if ( grep { exists $search_terms->{$_} } qw/first_name last_name/ ) {
        ($first_name, $last_name)
            = map { trim($_) } @{$search_terms}{qw/first_name last_name/};
    }
    elsif ( exists $search_terms->{customer_name} ) {
        # Make sure we can split this a maximum of two times - our last item is
        # always $last_name, anything before it is $first_name
        ($last_name, $first_name)
            = map { trim ($_) } reverse split( /\s+/, $search_terms->{customer_name}, 2);
    }

    die 'Neither first name nor last name provided, and at least one must be'
        if ( !$first_name && !$last_name );

    my @name_where;
    my @args;
    if ( $first_name ) {
        push @name_where, '[alias].first_name ILIKE ?';
        push @args, enliken( $first_name );
    }
    if ( $last_name ) {
        push @name_where, '[alias].last_name ILIKE ?';
        push @args, enliken( $last_name );
    }

    # now replace '[alias]' with the appropriate
    # alias for searching the 'customer' table
    # and for searching the 'order_address' table
    my @customer_clause_where = map { s{\Q[alias]\E}{c}r } @name_where;
    my @address_clause_where = map { s{\Q[alias]\E}{oa}r } @name_where;

    $channel_name = trim( $channel_name );

    if ( $channel_name ) {
        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        push @customer_clause_where, $channel_clause;
        push @address_clause_where, $channel_clause;
        push @args, @params;
    }

    my $query = union_wrapper_helper( join qq{\n},
        $customer_query->{select},
        "FROM orders o",
        $customer_query->{order_joins},
        "WHERE " . join( qq{\nAND }, @customer_clause_where ),
        "UNION",
        $customer_query->{select},
        "FROM orders o",
        $customer_query->{order_joins},
        "WHERE " . join( qq{\nAND }, @address_clause_where ),
    );

    # double up on the args because of the UNION
    push @args, @args;

    return $query, @args;
}

=head2 union_wrapper_helper($union_query_string) : $complete_query

We need to requalify our order by where we do union, this wrapper helps us do
that.

=cut

sub union_wrapper_helper {
    # NOTE: A little hacky this - if $customer_query->{order_by} changes to an
    # alias other than 's', this query will break.
    return sprintf(
            <<EOQ
SELECT DISTINCT
    order_id,
    order_nr,
    id,
    date,
    status,
    class,
    first_name,
    last_name,
    sales_channel,
    customer_category,
    country
FROM (
%s
) s
$customer_query->{order_by}
EOQ
        ,
        shift
    );
}

#
# here is the bulk of the stuff for searching
#

# defined as functions, because they depend on query fragments
# constructed at run-time, which are passed to them as two parameters
#
# each returns the query for the related search, along with its bind parameters
#
#
my $postgres_queries = {
    order_number  => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE o.order_nr = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM orders o",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    customer_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE c.is_customer_number = ?', $channel_clause//();
        unshift @params, $term;

        # Could be optimised by creating an 'customer_joins' entry point, but
        # it's probably fast enough already
        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM orders o",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    basket_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE o.basket_nr = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM orders o",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    email => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE o.email ILIKE ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM orders o",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    shipment_id => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE s.id = ?', $channel_clause//();
        unshift @params, $term;

        return ( join(
            qq{\n},
            $customer_query->{select},
            "FROM shipment s",
            $customer_query->{shipment_joins},
            $customer_query->{address_join},
            $where,
            $customer_query->{order_by},
            ), @params
        );
    },

    pre_order_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE lo_po.pre_order_id = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM link_orders__pre_order lo_po",
                "JOIN orders o ON lo_po.orders_id = o.id",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    psp_ref => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE op.psp_ref = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM orders.payment op",
                "JOIN orders o ON op.orders_id = o.id",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    box_id => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE sb.id = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM shipment_box sb",
                "JOIN shipment s ON sb.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    tracking_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE sb.tracking_number = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM shipment_box sb",
                "JOIN shipment s ON sb.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    product_id =>  sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE v.product_id = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM variant v",
                "JOIN shipment_item si ON v.id = si.variant_id",
                "JOIN shipment s ON si.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    rma_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE r.rma_number = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM return r",
                "JOIN shipment s ON r.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    sku => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND },
            'WHERE v.product_id = ? AND v.size_id = ?',
            $channel_clause//();

        my ($product_id, $size_id) = $term =~ $SKU_REGEX;
        die "Invalid SKU $term\n" unless ( $product_id && $size_id );

        validate_int($_) for $product_id, $size_id;
        unshift @params, $product_id, $size_id;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM variant v",
                "JOIN shipment_item si ON v.id = si.variant_id",
                "JOIN shipment s ON si.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    allocation_id => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE a.id = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM allocation a",
                "JOIN shipment s ON a.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    telephone_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND },
            <<EOC
WHERE (
    regexp_replace(o.telephone, '[^0-9]','','g')        = regexp_replace(?, '[^0-9]','','g')
 OR regexp_replace(o.mobile_telephone, '[^0-9]','','g') = regexp_replace(?, '[^0-9]','','g')
 OR regexp_replace(s.telephone, '[^0-9]','','g')        = regexp_replace(?, '[^0-9]','','g')
 OR regexp_replace(s.mobile_telephone, '[^0-9]','','g') = regexp_replace(?, '[^0-9]','','g')
)
EOC
,
            $channel_clause//();
        unshift @params, ($term) x 4;

        # This is still a very slow query...
        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM shipment s",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    postcode => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND },
            'WHERE ( ship.postcode ILIKE ? OR bill.postcode ILIKE ? )',
            $channel_clause//();
        unshift @params, ($term) x 2;

        # Well this query is still very slow... could do with more optimisation
        # but we'd probably have to customise the query
        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM order_address ship",
                "JOIN shipment s ON ship.id = s.shipment_address_id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                "JOIN order_address bill ON o.invoice_address_id = bill.id",
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    billing_address => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);

        # we really, *really* ought to be doing this differently --
        # LIKEs across multiple columns that start with '%' simply
        # cannot be indexed, so this is always going to result in
        # table scans
        my $where = join qq{\nAND }, <<EOC
WHERE (
    oad.address_line_1 ILIKE ?
 OR oad.address_line_2 ILIKE ?
 OR oad.address_line_3 ILIKE ?
 OR oad.towncity       ILIKE ?
 OR oad.county         ILIKE ?
 OR oad.country        ILIKE ?
 OR oad.postcode       ILIKE ?
)
EOC
,
            $channel_clause//();
        unshift @params, ($term) x 7;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM order_address oad",
                "JOIN orders o ON oad.id = o.invoice_address_id",
                $customer_query->{order_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    shipping_address => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, <<EOC
WHERE (
    oa.address_line_1 ILIKE ?
 OR oa.address_line_2 ILIKE ?
 OR oa.address_line_3 ILIKE ?
 OR oa.towncity       ILIKE ?
 OR oa.county         ILIKE ?
 OR oa.country        ILIKE ?
 OR oa.postcode       ILIKE ?
)
EOC
,
            $channel_clause//();
        unshift @params, ($term) x 7;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM order_address oa",
                "JOIN shipment s ON oa.id = s.shipment_address_id",
                $customer_query->{shipment_joins},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    airwaybill => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @channel_params )
            = $customer_query->{where}{channel_name}($channel_name);

        my @where_clauses = map {
            join qq{\nAND }, "WHERE $_", $channel_clause//()
        }
        '( LOWER(s.outward_airway_bill) = LOWER(?) OR LOWER(s.return_airway_bill)  = LOWER(?) )',
        'LOWER(ri.return_airway_bill) = LOWER(?)';
        my @params = (($term) x 2, @channel_params, ($term) x 1, @channel_params);

        # This query is still very slow. Note that there are no indexes on any
        # of lower($search_term) columns, but adding them didn't seem to make
        # much of a difference (down from a cost of 1.5M to 1.3M)... won't add
        # them for now.
        my $query = union_wrapper_helper(
            join qq{\n},
                $customer_query->{select},
                "FROM shipment s",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where_clauses[0],
                "UNION",
                $customer_query->{select},
                "FROM return_item ri",
                "JOIN return r ON ri.return_id = r.id",
                "JOIN shipment s ON r.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where_clauses[1],
        );
        return $query, @params;
    },

    invoice_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE r.invoice_nr = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM renumeration r",
                "JOIN shipment s ON r.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },

    rpg_number => sub {
        my ($term, $channel_name) = @_;

        my ( $channel_clause, @params )
            = $customer_query->{where}{channel_name}($channel_name);
        my $where = join qq{\nAND }, 'WHERE sp.group_id = ?', $channel_clause//();
        unshift @params, $term;

        return (
            join( qq{\n},
                $customer_query->{select},
                "FROM stock_process sp",
                "JOIN delivery_item di          ON sp.delivery_item_id  = di.id",
                "JOIN delivery d                ON di.delivery_id = d.id",
                "JOIN link_delivery__return ldr ON d.id = ldr.delivery_id",
                "JOIN return r                  ON ldr.return_id = r.id",
                "JOIN shipment s                ON r.shipment_id = s.id",
                $customer_query->{shipment_joins},
                $customer_query->{address_join},
                $where,
                $customer_query->{order_by},
            ), @params
        );
    },
};

sub _build_order_query_args {
    my ( $type, $term, $channel_name ) = trim( @_ );

    die 'No search type defined'   unless $type;
    die 'No search term provided' unless $term;

    if ( grep { /$type/ } qw/customer_name first_name last_name/ ) {
        return _build_name_query_args( $term, $channel_name );
    }

    return _make_query_args( _fix_type_term( $type, $term ), $channel_name );
}

=head2 validate_int($value) : dies|1

Dies on failure, returns 1 on success

=cut

sub validate_int {
    my $value = shift;
    die "$value isn't a valid integer\n" unless is_valid_database_id($value);
    return 1;
}

sub _make_query_args {
    my ( $type, $term, $channel_name ) = @_;

    # deliberately non-squawky -- we allow callers to ask for
    # non-existent search types, so that they can ask around with
    # impunity, rather than having to bake knowledge of what kinds of
    # queries are available up into the callers

    return () unless exists $postgres_queries->{$type};

    # Slightly better error messages than Pg barf for our delicate users
    my @int_fields = (qw{
        allocation_id
        customer_number
        rpg_number
        pre_order_number
        product_id
        shipment_id
    });
    validate_int($term) if grep { $type eq $_ } @int_fields;

    my ( $query, @args ) = $postgres_queries->{$type}($term, $channel_name);

    return $query, @args;
}

sub _fix_type_term {
    my ( $type, $term ) = @_;

    if ( $type =~ m{\A(?:billing_address|shipping_address|postcode|email)\z} ) {
        # fix search term for like queries
        $term = enliken( $term );
    }
    elsif ( $type eq 'airwaybill' ) {
        # strip out spaces from AWB searches
        $term =~ s/\s//g;

        # user searching by License Plate number - switch search type
        # and strip off leading characters not stored in DB
        if ( $term =~ m/(\w+00022)(?<tracking_number>\d+)/ ) {
            # DCS-1210: Renamed field 'licence_plate_number' to 'tracking_number'
            $type = 'tracking_number';
            $term = $+{tracking_number};
        }
    }
    elsif ( $type eq 'box_id' ) {
        # blast the post-hyphen component of a box ID

        $term =~ s/\-\d+$//;
    }

    return $type, $term;
}

1;
