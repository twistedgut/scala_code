package XT::DC::Messaging::Spec::Product;
require XT::DC::Messaging::Spec::PurchaseOrder;
use strict;
use warnings;

use NAP::Messaging::Utils 'ignore_extra_fields_deep';

=head2 create_voucher

Returns C<Data::Rx> validation fields for create_voucher.

=cut

sub create_voucher {
    return $_[0]->_voucher;
}

=head2 update_voucher

Returns C<Data::Rx> validation fields for update_voucher.

=cut

sub update_voucher {
    return $_[0]->_voucher;
}

sub _voucher {
    return ignore_extra_fields_deep {
        type     => '//rec',
        required => {
            id                       => '//int',
            channel_id               => '//int',
            variant_id               => '//int',
            name                     => '//str',
            landed_cost              => {
                type => '//any',
                of   => [ '//num', '//nil', ],
            },
            value                    => '//int',
            currency_code            => '//str',
            is_physical              => '//bool',
            created                  => '/nap/datetime',
            disable_scheduled_update => '//bool',
            operator_id              => '//int',
            visible                  => '//bool',
        },
        optional => {
            upload_date => {
                type => '//any',
                of   => ['/nap/datetime','//nil'],
            },
        },
    };
}

=head2 make_live

Returns C<Data::Rx> validation fields for make_live.

=cut
sub make_live {

    # define voucher structure
    my $voucher = {
            type    => '//rec',
            required => {
                id          => '//int',
                channel_id  => '//int',
                upload_date => '/nap/datetime',
            },
        };
    # define product structure - not known at time of dev
    my $product = {
            type    => '//any',
        };

    return ignore_extra_fields_deep {
        type => '//any',
        of => [
            {
                type => '//rec',
                required => {
                    voucher => $voucher,
                },
            },
            {
                type => '//rec',
                required => {
                    product => $product,
                },
            },
        ],
    };
}


sub create_product {
    return $_[0]->_product;
}

sub _product {
    my $strnull= {
        type => '//any',
        of => [ '//str', '//nil' ],
    };

    return ignore_extra_fields_deep {
        type => '//rec',
        required => {
            business_id              => '//int',
            product_id               => '//int',
            name                     => '//str',
            world                    => '//str',
            division                 => '//str',
            hs_code                  => '//str',
            designer                 => '//str',
            description              => $strnull,
            classification           => '//str',
            product_type             => '//str',
            sub_type                 => '//str',
            colour                   => '//str',
            style_number             => '//str',
            season                   => '//str',
            colour_filter            => '//str',
            product_department       => '//str',
            designer_colour          => '//str',
            designer_colour_code     => $strnull,
            size_scheme              => '//str',
            act                      => '//str',
            style_notes              => $strnull,
            scientific_term          => '//str',
            operator_id              => '//int',
            size_scheme_variant_size => {
                type     => '//arr',
                contents => {
                    type     => '//rec',
                    required => {
                        variant_id    => '//int',
                        size          => '//str',
                        designer_size => '//str',
                    },
                    optional => {
                        third_party_sku => '//str',
                    }
                },
            },

            channels                 => {
                type     => '//arr',
                contents => {
                    type     => '//rec',
                    required => {
                        channel_id=> '//int',
                        payment_term             => '//str',
                        payment_settlement_discount => '//str',
                        payment_deposit          => '//str',
                        runway_look              => '/nap/bool',
                        sample_correct           => '/nap/bool',
                        sample_colour_correct    => '/nap/bool',
                        original_wholesale       => '//num',
                        wholesale_currency       => '//str',
                        trade_discount           => '//num',
                        uplift                   => '//num',
                        unit_landed_cost         => '//num',
                        landed_currency          => '//str',
                        default_price            => '//num',
                        default_currency         => '//str',
                        upload_after             => $strnull,
                        product_tags             => {
                            type => '//arr',
                            contents => '//str',
                        },
                    },
                    optional => {
                        external_image_urls    => {
                            type     => '//arr',
                            contents => '//str',
                        },
                        business_id              => '//int',
                        business_name            => '//str',
                        upload_date              => '//str',
                        upload_list_name         => '//str',
                        initial_markdown         => {
                            type     => '//rec',
                            required => {
                                percentage => '//num',
                                start_date => '//str',
                            },
                        },
                        region_prices            => {
                            type     => '//arr',
                            contents => {
                                type     => '//rec',
                                required => {
                                    price    => '//num',
                                    currency => '//str',
                                    region   => '//str',
                                },
                            },
                        },
                        country_prices           => {
                            type     => '//arr',
                            contents => {
                                type     => '//rec',
                                required => {
                                    price    => '//num',
                                    currency => '//str',
                                    country  => '//str',
                                },
                            },
                        },
                    },
                },
            },
        },
        optional => {
            business_name            => '//str',
            restrictions             => {
                type     => '//arr',
                contents => {
                    type     => '//rec',
                    required => {
                        title => '//str',
                    },
                },
            },
        },
    };
}

=head2 delete_voucher

Returns C<Data::Rx> validation fields for delete_voucher.

=cut

sub delete_voucher {
    return ignore_extra_fields_deep {
        type => '//rec',
        required => {
            id => '//int',
        },
    };
}

=head2 create_orderless_voucher

Returns C<Data::Rx> validation fields for creating orderless vouchers.

=cut

sub create_orderless_voucher {
    return ignore_extra_fields_deep {
        type     => '//rec', # orderless voucher po
        required => {
            source              => '//str',
            send_reminder_email => '/nap/bool',
            expiry_date         => {
                type => '//any',
                of => [ '/nap/datetime', '//nil', ]
            },
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
            },
        },
    };
}

sub purchase_order {
    goto &XT::DC::Messaging::Spec::PurchaseOrder::purchase_order;
}

=head2 assign_virtual_voucher_code_to_shipment

Returns C<Data::Rx> validation fields for the response from Fulcrum with the Virtual Voucher Codes

=cut

sub assign_virtual_voucher_code_to_shipment {
    return ignore_extra_fields_deep {
        type => '//rec',
        required => {
            channel_id  => '//int',
            shipments   => {
                type    => '//arr',
                contents=> {
                    type=> '//rec',
                    required => {
                        shipment_id => '//int',
                        shipment_items => {
                            type    => '//arr',
                            contents=> {
                                type    => '//rec',
                                required=> {
                                    shipment_item_id=> '//int',
                                    voucher_pid     => '//int',
                                    voucher_code    => '//str',
                                },
                            }
                        },
                    },
                },
            },
        },
    };
}

sub send_detailed_stock_levels {
    return ignore_extra_fields_deep {
        type => '//rec',
        required => {
            product_id => '//int',
            channel_id => '//int',
        },
    };
}

1;
