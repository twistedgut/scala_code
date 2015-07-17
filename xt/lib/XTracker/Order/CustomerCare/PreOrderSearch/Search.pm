package XTracker::Order::CustomerCare::PreOrderSearch::Search;

use NAP::policy "tt", qw( exporter );

use DateTime;
use Perl6::Export::Attrs;
use XTracker::Constants ':database';
use XTracker::Constants::FromDB qw(
    :pre_order_status
);

use XTracker::Utilities     qw( trim );
use XTracker::Database::Utilities  qw( enliken is_valid_database_id );
use XTracker::Logfile qw( xt_logger );

sub find_pre_orders :Export(:search) {
    my ( $schema, $arghash, $limit ) = @_;

    my ( $type, $terms )
        = @$arghash{ qw( search_type search_terms ) };

    die "No schema object passed" unless $schema;

    die "No search type provided, and one must be"
        unless $type;

    die "No search terms provided" unless $terms;

    my $pre_orders = $schema->resultset('Public::PreOrder')->search_rs({
        -or => [
            'me.pre_order_status_id' => $PRE_ORDER_STATUS__COMPLETE,
            'me.pre_order_status_id' => $PRE_ORDER_STATUS__PART_EXPORTED,
            ],
        },
        { join => [ 'customer',
                    'pre_order_status',
                    'invoice_address',
                    'pre_order_payment',
                    'shipment_address',
                    { 'pre_order_items' => 'variant' },
                  ],
          order_by => [ qw/me.customer_id me.id/ ],
        }
    );
    $pre_orders = $pre_orders->search_rs({}, {rows => $limit,}) if $limit;

    $pre_orders = _get_complete_rs($type, $terms, $pre_orders);

    my $retval = {};

    if ( $pre_orders ) {
        while (my $po = $pre_orders->next) {
            $retval->{$po->id} = {
                customer => $po->customer->first_name.' '.$po->customer->last_name,
                items => $po->pre_order_items_rs->count,
                outstanding => $po->search_related_rs("pre_order_items", {
                    'pre_order_item_status_id' => $PRE_ORDER_STATUS__PART_EXPORTED
                })->count,
                created => $po->created->dmy,
                status => $po->pre_order_status->status,
            };
        }
    }

    return $retval;
}

sub _get_complete_rs {
    my ($type, $term, $rs) = @_;
    $term = trim($term);

    # Let's do this here, after trimming our $term.
    _validate_int($term)
        for grep { $type eq $_ } qw{any pre_order_number product_id};

    my $out;

    given ($type) {
        when (/any/) {
            my $condition = [];
            foreach my $field ( 'me.id', 'customer.id', 'variant.product_id' ) {
                push @$condition, $field => $term;
            }
            $out = $rs->search_rs({
                -or => $condition,
            });
        }
        when (/customer_name/) {
            my ($first, $last) = split( /\s+/, $term, 2);
            if ( $last ) {
                $out = $rs->search_rs({
                    -or => [
                        -and => [
                            'customer.first_name' => { ILIKE => enliken(trim($first)) },
                            'customer.last_name' => { ILIKE => enliken(trim($last)) },
                        ],
                        -and => [
                            'invoice_address.first_name' => {
                                ILIKE => enliken(trim($first))
                            },
                            'invoice_address.last_name' => {
                                ILIKE => enliken(trim($last))
                            },
                        ],
                        -and => [
                            'shipment_address.first_name' => {
                                ILIKE => enliken(trim($first))
                            },
                            'shipment_address.last_name' => {
                                 ILIKE => enliken(trim($last))
                            },
                        ],
                    ],
                });
            }
            else {
                # Where we have no first name search only on last
                $last = $first;
                $out = $rs->search_rs({
                    -or => [
                        'customer.last_name' => { ILIKE => enliken(trim($last)) },
                        'invoice_address.last_name' => {
                            ILIKE => enliken(trim($last))
                        },
                        'shipment_address.last_name' => {
                            ILIKE => enliken(trim($last))
                        },
                    ]
                });
            }
        }
        when (/customer_number/) {
            $out = $rs->search({
                'customer.id' => $term,
            });
        }
        when (/first_name/) {
            $out = $rs->search({
                'customer.first_name' => { ILIKE => enliken(trim($term)) },
            });
        }
        when (/last_name/) {
            $out = $rs->search({
                'customer.last_name' => { ILIKE => enliken(trim($term)) },
            });
        }
        when (/email/) {
            $out = $rs->search({
                'customer.email' => { ILIKE => enliken(trim($term)) },
            });
        }
        when (/pre_order_number/) {
            $out = $rs->search({
                'me.id' => $term,
            });
        }
        when (/telephone_number/) {
            $out = $rs->search({
                -or => [
                    'me.telephone_day' => $term,
                    'me.telephone_eve' => $term,
                ],
            });
        }
        when (/product_id/) {
            $out = $rs->search({
                'variant.product_id' => $term,
            });
        }
        when (/sku/) {
            my ($product_id, $size_id) = split(/-/, $term, 2);

            _validate_int($_) for $product_id, $size_id;

            $out = $rs->search({
                -and => [
                    'variant.product_id' => $product_id,
                    'variant.size_id' => $size_id,
                    ],
            });
        }
        when (/postcode/) {
            $out = $rs->search({
                -or => [
                'invoice_address.postcode' => { ILIKE => enliken($term) },
                'shipment_address.postcode' => { ILIKE => enliken($term) },
                ],
            });
        }
        when (/billing_address/) {
            $out = $rs->search({
                -or => [
                'invoice_address.address_line_1' => { ILIKE => enliken($term) },
                'invoice_address.address_line_2' => { ILIKE => enliken($term) },
                'invoice_address.address_line_3' => { ILIKE => enliken($term) },
                'invoice_address.towncity' => { ILIKE => enliken($term) },
                'invoice_address.county' => { ILIKE => enliken($term) },
                'invoice_address.country' => { ILIKE => enliken($term) },
                'invoice_address.postcode' => { ILIKE => enliken($term) },
                ],
            });
        }
        when (/shipping_address/) {
            $out = $rs->search({
                -or => [
                'shipment_address.address_line_1' => { ILIKE => enliken($term) },
                'shipment_address.address_line_2' => { ILIKE => enliken($term) },
                'shipment_address.address_line_3' => { ILIKE => enliken($term) },
                'shipment_address.towncity' => { ILIKE => enliken($term) },
                'shipment_address.county' => { ILIKE => enliken($term) },
                'shipment_address.country' => { ILIKE => enliken($term) },
                'shipment_address.postcode' => { ILIKE => enliken($term) },
                ],
            });
        }
    }
    return $out;
}

sub _validate_int {
    my $supposedly_an_int = shift;
    die "PID $supposedly_an_int is not a valid integer\n"
        unless is_valid_database_id($supposedly_an_int);
    return 1;
}

1;
