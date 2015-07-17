package XT::DC::Messaging::Spec::PurchaseOrder;

use strict;
use warnings;

use NAP::Messaging::Utils 'ignore_extra_fields_deep';

sub purchase_order {
    return ignore_extra_fields_deep {
        type => '//any',
        of => [
            __PACKAGE__->voucher_po,
            __PACKAGE__->product_po,
        ],
    };
}

sub voucher_po {
    return ignore_extra_fields_deep {
        type     => '//rec', # voucher po
        required => {
            po_number => '//str',
            channel_id => '//int',
            date => '/nap/datetime',
            created_by => '//int',
            status => {
                type => '//any',
                # Hrmmmm - this kinda duplicates Constants::FromDB
                of => [ map {
                    {
                        type => '//str', value => $_,
                    }
                } 'Created', 'On Order', 'Part Delivered', 'Delivered', 'Cancelled' ]
            }
        },
        optional => {
            id => '//int',
            vouchers => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        pid => '//int',
                        # Number of codes implies quantity.
                        codes => {
                            type => '//arr',
                            contents => '//str',
                        },
                    },
                },
            }
        }
    };
}

sub product_po {
    return ignore_extra_fields_deep {
        type     => '//rec', # product po
        required => {
            po_number => '//str',
            channel_id => '//int',
            date => '/nap/datetime',
            created_by => '//str',
            payment_deposit => '//num',
            payment_settlement_discount => '//num',
            payment_term => '//str',
            ship_origin => '//str',
            designer => '//str',
            supplier => '//str',
            season => '//str',
            act => '//str',
            status => { # XXX TODO check this!
                type => '//any',
                # Hrmmmm - this kinda duplicates Constants::FromDB
                of => [ map {
                    {
                        type => '//str', value => $_,
                    }
                } 'Placed', 'Confirmed', 'Cancelled' ]
            }
        },
        optional => {
            confirmed_by => {
                type => '//any',
                of => ['//int','//nil'],
            },
            placed_by => {
                type => '//any',
                of => ['//str','//nil'],
            },
            stock => {
                type => '//arr',
                contents => __PACKAGE__->product_po_stock,
            },
        },
    };
}

sub product_po_stock {
    return ignore_extra_fields_deep {
        type => '//rec',
        required => {
            'cancel_ship_date' => '/nap/datetime',
            'items' => {
                type => '//arr',
                contents => {
                    type => '//rec',
                    required => {
                        variant_id => '//int',
                        quantity => '//int',
                    },
                    optional => {
                        size => '//str',
                    },
                },
            },
            'product_id' => '//int',
            'shipment_window_type' => '//str',
            'start_ship_date' => '/nap/datetime',
        },
        optional => {
            'size_scheme' => '//str',
            markdown => {
                type => '//rec',
                required => {
                    category => '//str',
                    percentage => '//num',
                    start_date => '/nap/datetime',
                },
            },
        },
    };
}

1;
