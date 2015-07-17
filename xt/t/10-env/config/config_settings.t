#!/usr/bin/env perl

use NAP::policy "tt",         'test';

=head2 Test System Config Settings

This tests that specific settigns exist and have the correct values or counts of values.

The format of the HashRef $config_group_settings is:

Distribution Centre ( Currently DC1 or DC2 )
    Channel Name ( select name from channel )
        active      optional    Whether the group is flagged as active or not, defaults to TRUE.
        count       optional    Checks the group has the correct number of settings, regardless of name.
        min         optional    Checks the group has at least this number of settings, regardless of name.
        max         optional    Checks the group has at most this number of settings, regardless of name.
        settings    required    This is a HashRef of the settings you want to test (see below).

settings
    Each key is the name of the setting you want to test.
    The value is either a HashRef (single value) or an ArrayRef of HashRefs (multiple values).

    Each HashRef has the following structure:
        active      optional    Whether the setting is flagged as active or not, defaults to TRUE.
        count       optional    Checks the setting has the correct number of values.
        min         optional    Checks the setting has at least this number of values.
        max         optional    Checks the setting has at most this number of values.


NOTE: If count, min or max in either the group or settings are not specified, they will not be checked.

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition
    export      => [ '$distribution_centre' ];

isa_ok(
    my $schema = Test::XTracker::Data->get_schema,
    "XTracker::Schema"
);

# -----------------------------------------------------------------------------------------------------------------------------------

my $config_group_settings->{DC1}    = {

        'NONE'  => {
            'ShippingRestrictionActions' => {
                count    => 5,
                settings => {
                    'Chinese origin'         => { count => 1, values => { value => 'restrict' } },
                    'CITES'                  => { count => 1, values => { value => 'restrict' } },
                    'Designer Country'       => { count => 1, values => { value => 'restrict' } },
                    'Designer Service Error' => { count => 1, values => { value => 'silent_restrict' } },
                    'HAZMAT_LQ'              => { count => 1, values => { value => 'restrict' } },

                },
            },
            'order_search' => {
                count => 2,
                settings => {
                    'by_designer_search_window' => { count => 1, values => { value => '186 DAYS' } },
                    'result_limit'              => { count => 1, values => { value => 10000 } },
                },
            },
            'OrderImporterPreParser' => {
                count => 1,
                settings => {
                    'tender_type-klarna' => { count => 1, values => { value => 'Card' } },
                },
            },
            'PSPNamespace' => {
                count    => 6,
                settings => {
                    'giftvoucher_sku'   => { count => 1, values => { value => 'gift_voucher' } },
                    'giftvoucher_name'  => { count => 1, values => { value => 'Gift Voucher' } },
                    'storecredit_sku'   => { count => 1, values => { value => 'store_credit' } },
                    'storecredit_name'  => { count => 1, values => { value => 'Store Credit' } },
                    'shipping_sku'      => { count => 1, values => { value => 'shipping' } },
                    'shipping_name'     => { count => 1, values => { value => 'Shipping' } },

                },
            },
            Send_Metrics_to_Graphite => {
                count => 1,
                settings => {
                    is_active => { values => { value => 1 }}
                }
            }
        },
        'NET-A-PORTER.COM' => {

            'CreditHoldExceptionParams' => {
                'count' => 4,
                'settings' => {
                    'month' => { 'count' => 1  },
                    'order_total' => { 'count' => 1 },
                    'include_channel' => { 'count' => 2},
                },
            },

            'FraudCheckRatingAdjustment' => {
                'count' => 1,
                'settings' => {
                    'card_check_rating' => { 'count' => 1 },
                },
            },

            Reservation => {
                    min => 4,
                    settings => {
                        expire_pending_after => { count => 1, values => { value => '1 year' } },
                        sale_commission_unit => { count => 1, values => { value => 'DAYS' } },
                        sale_commission_value => { count => 1, values => { value => '21' } },
                        commission_use_end_of_day => { count => 1, values => { value => '1' } },
                    },
                },

            Customer => {
                count => 1,
                settings => {
                    no_shipping_cost_recalc_customer_category_class => { count => 1, values => { value => 'EIP' } },
                },
            },
            'Welcome_Pack' => {
                ignore_active => 1,     # users can make the group Active via the U.I. whenever they want
                count   => 5,
                settings => {
                    en => { count => 1 },
                    fr => { count => 1 },
                    de => { count => 1 },
                    zh => { count => 1 },
                    exclude_on_product_type => { count => 1, values => { value => 'PORTER Magazine' } },
                },
            },
            Language    => {
                count   => 5,
                settings    => {
                    EN  => { count => 1, values => { value => 'On' }, },
                    DE  => { count => 1, values => { value => 'On' }, },
                    FR  => { count => 1, values => { value => 'On' }, },
                    ZH  => { count => 1, values => { value => 'On' }, },
                    update_customer_language_on_every_order => { count => 1, values => { value => 'Off' }, },
                },
            },

            PreOrder => {
                count => 4,
                settings => {
                    is_active          => { values => { value => '1' } },
                    can_apply_discount => { values => { value => '1' } },
                    max_discount       => { values => { value => '30' } },
                    discount_increment => { values => { value => '5' } },
                },
            },
            PreOrderDiscountCategory => {
                count => 4,
                settings => {
                    'EIP'           => { values => { value => '0' } },
                    'EIP Centurion' => { values => { value => '0' } },
                    'EIP Premium'   => { values => { value => '0' } },
                    'EIP Elite'     => { values => { value => '0' } },
                },
            },
            SendToMercury => {
                count => 1,
                settings => {
                    can_send_shipment_updates => {values => { value => 'Off' }}
                }
            }

        }, # NET-A-PORTER.COM

        'theOutnet.com' => {

            'CreditHoldExceptionParams' => {
                'count' => 4,
                'settings' => {
                    'month' => { 'count' => 1 },
                    'order_total' => { 'count' => 1 },
                    'include_channel' => { 'count' => 2},
                },
            },

            'FraudCheckRatingAdjustment' => {
                'count' => 1,
                'settings' => {
                    'card_check_rating' => { 'count' => 1 },
                },
            },

            Customer => {
                count => 1,
                settings => {
                    no_shipping_cost_recalc_customer_category_class => { count => 1, values => { value => 'EIP' } },
                },
            },
            'Welcome_Pack' => {
                active => 0,
                count  => 0,
            },
            Language    => {
                count   => 5,
                settings    => {
                    EN  => { count => 1, values => { value => 'On' }, },
                    DE  => { count => 1, values => { value => 'Off' }, },
                    FR  => { count => 1, values => { value => 'Off' }, },
                    ZH  => { count => 1, values => { value => 'Off' }, },
                    update_customer_language_on_every_order => { count => 1, values => { value => 'Off' }, },
                },
            },

            PreOrder => {
                count => 2,
                settings => {
                    is_active          => { values => { value => '0' } },
                    can_apply_discount => { values => { value => '0' } },
                },
            },
            SendToMercury => {
                count => 1,
                settings => {
                    can_send_shipment_updates => {values => { value => 'Off' }}
                }
            },
        }, # theOutnet.com

        'MRPORTER.COM' => {
            'FraudCheckRatingAdjustment' => {
                'count' => 1,
                'settings' => {
                    'card_check_rating' => { 'count' => 1 },
                },
            },

            Reservation => {
                    min => 4,
                    settings => {
                        expire_pending_after => { count => 1, values => { value => '1 year' } },
                        sale_commission_unit => { count => 1, values => { value => 'DAYS' } },
                        sale_commission_value => { count => 1, values => { value => '21' } },
                        commission_use_end_of_day => { count => 1, values => { value => '1' } },
                    },
                },

            Customer => {
                count => 1,
                settings => {
                    no_shipping_cost_recalc_customer_category_class => { count => 1, values => { value => 'EIP' } },
                },
            },
            'Welcome_Pack' => {
                count => 1,
                settings => {
                    'DEFAULT' => { count => 1 },
                },
            },
            Language    => {
                count   => 5,
                settings    => {
                    EN  => { count => 1, values => { value => 'On' }, },
                    DE  => { count => 1, values => { value => 'Off' }, },
                    FR  => { count => 1, values => { value => 'Off' }, },
                    ZH  => { count => 1, values => { value => 'Off' }, },
                    update_customer_language_on_every_order => { count => 1, values => { value => 'Off' }, },
                },
            },

            PreOrder => {
                count => 2,
                settings => {
                    is_active          => { values => { value => '0' } },
                    can_apply_discount => { values => { value => '0' } },
                },
            },
            SendToMercury => {
                count => 1,
                settings => {
                    can_send_shipment_updates => {values => { value => 'Off' }}
                }
            },
        }, # MRPORTER.COM

        'JIMMYCHOO.COM' => { 'FraudCheckRatingAdjustment' => {
                'count' => 1,
                'settings' => {
                    'card_check_rating' => { 'count' => 1 },
                },
            },

            Customer => {
                count => 0,
            },
            'Welcome_Pack' => {
                active => 0,
                count  => 0,
            },
            Language    => {
                count   => 5,
                settings    => {
                    EN  => { count => 1, values => { value => 'On' }, },
                    DE  => { count => 1, values => { value => 'On' }, },
                    FR  => { count => 1, values => { value => 'On' }, },
                    ZH  => { count => 1, values => { value => 'Off' }, },
                    update_customer_language_on_every_order => { count => 1, values => { value => 'On' }, },
                },
            },

            PreOrder => {
                count => 2,
                settings => {
                    is_active          => { values => { value => '0' } },
                    can_apply_discount => { values => { value => '0' } },
                },
            },
            SendToMercury => {
                count => 1,
                settings => {
                    can_send_shipment_updates => {values => { value => 'Off' }}
                }
            },
            Refund => {
                settings => {
                    deny_store_credit => { values => { value => 1 } },
                },
            },
        }, # JIMMYCHOO.COM
};

$config_group_settings->{DC2}   = {
                %{ $config_group_settings->{DC1} },

                # add any DC2 specific Settings here
                # and/or overdide any DC1 settings here

                'NONE'  => {
                    %{ $config_group_settings->{DC1}{NONE} },

                    'ShippingRestrictionActions'    => {
                        count    => 6,
                        settings => {
                            'Chinese origin'         => { count => 1, values => { value => 'restrict' } },
                            'CITES'                  => { count => 1, values => { value => 'notify'   } },
                            'Fish & Wildlife'        => { count => 1, values => { value => 'notify'   } },
                            'HAZMAT'                 => { count => 1, values => { value => 'restrict' } },
                            'Designer Country'       => { count => 1, values => { value => 'restrict' } },
                            'Designer Service Error' => { count => 1, values => { value => 'silent_restrict' } },
                        },
                    },
                },

                'JIMMYCHOO.COM' => { 'FraudCheckRatingAdjustment' => {
                        'count' => 1,
                        'settings' => {
                            'card_check_rating' => { 'count' => 1 },
                        },
                    },

                    Customer => {
                        count => 0,
                    },
                    'Welcome_Pack' => {
                        active => 0,
                        count  => 0,
                    },
                    Language    => {
                        count   => 5,
                        settings    => {
                            EN  => { count => 1, values => { value => 'On' }, },
                            DE  => { count => 1, values => { value => 'Off' }, },
                            FR  => { count => 1, values => { value => 'Off' }, },
                            ZH  => { count => 1, values => { value => 'Off' }, },
                            update_customer_language_on_every_order => { count => 1, values => { value => 'On' }, },
                        },
                    },
                    Refund => {
                        settings => {
                            deny_store_credit => { values => { value => 1 } },
                        },
                    },
                }, # JIMMYCHOO.COM
            };

$config_group_settings->{DC3}   = {
                %{ $config_group_settings->{DC1} },

                # add any DC3 specific Settings here
                # and/or overdide any DC1 settings here

                'NONE'  => {
                    %{ $config_group_settings->{DC1}{NONE} },

                    'ShippingRestrictionActions'    => {
                        count    => 5,
                        settings => {
                            'Chinese origin'         => { count => 1, values => { value => 'restrict' } },
                            'CITES'                  => { count => 1, values => { value => 'restrict' } },
                            'Fish & Wildlife'        => { count => 1, values => { value => 'notify'   } },
                            'Designer Country'       => { count => 1, values => { value => 'restrict' } },
                            'Designer Service Error' => { count => 1, values => { value => 'silent_restrict' } },
                        },
                    },
                },

                'JIMMYCHOO.COM' => { 'FraudCheckRatingAdjustment' => {
                        'count' => 1,
                        'settings' => {
                            'card_check_rating' => { 'count' => 1 },
                        },
                    },

                    Customer => {
                        count => 0,
                    },
                    'Welcome_Pack' => {
                        active => 0,
                        count  => 0,
                    },
                    Language    => {
                        count   => 5,
                        settings    => {
                            EN  => { count => 1, values => { value => 'On' }, },
                            DE  => { count => 1, values => { value => 'Off' }, },
                            FR  => { count => 1, values => { value => 'Off' }, },
                            ZH  => { count => 1, values => { value => 'Off' }, },
                            update_customer_language_on_every_order => { count => 1, values => { value => 'On' }, },
                        },
                    },
                    Refund => {
                        settings => {
                            deny_store_credit => { values => { value => 1 } },
                        },
                    },
                }, # JIMMYCHOO.COM
            };

# -----------------------------------------------------------------------------------------------------------------------------------

sub _path {
    my ( $channel, $group, $setting, $sequence ) = @_;

    my $seperator = '/';
    my $result = $channel;

    $result .= "$seperator$group"   if defined $group;
    $result .= "$seperator$setting" if defined $setting;
    $result .= "[$sequence]"        if defined $sequence;

    return $result;

}

sub _cmm {
    my $value   = shift;
    my $test    = shift;
    my $type    = shift;
    my $message = _path( @_ );

    if ( $type eq 'count' ) {

        cmp_ok( $value, '==', $test, "$message has exactly $test value" . ( $test == 1 ? '' : 's' ) )
            if defined $test;

    } elsif ( $type eq 'min' ) {

        cmp_ok( $value, '>=', $test, "$message has at least $test value" . ( $test == 1 ? '' : 's' ) )
            if defined $test;

    } elsif ( $type eq 'max' ) {

        cmp_ok( $value, '<=', $test, "$message has at most $test value" . ( $test == 1 ? '' : 's' ) )
            if defined $test;

    }

}

if ( ref( $config_group_settings ) eq 'HASH' ) {
    ## no critic(ProhibitDeepNests)

    ok( exists( $config_group_settings->{ $distribution_centre } ), "Config Settings found for DC: " . $distribution_centre );

    my $rs_channel = $schema->resultset('Public::Channel');
    isa_ok( $rs_channel, 'XTracker::Schema::ResultSet::Public::Channel' );

    my $rs_config_group = $schema->resultset('SystemConfig::ConfigGroup');
    isa_ok( $rs_config_group, 'XTracker::Schema::ResultSet::SystemConfig::ConfigGroup' );

    note 'Begining Tests';

    # Go through each channel.
    while ( my ( $channel_name, $groups ) = each %{ $config_group_settings->{$distribution_centre} } ) {

        # Get the correct channel ID, or undef if NONE is specified.
        my $channel_id = $channel_name eq 'NONE'
            ? undef
            : $rs_channel->find( { name => $channel_name } )->id;

        # Go through each group.
        while ( my ( $group_name, $group ) = each %$groups ) {
            # Construct the full path to the value.
            my $group_message = _path( $channel_name, $group_name );

            # Some defaults.
            $group->{active}    //= 1;
            $group->{settings}  ||= {};

            # Search for the group in this channel.
            my $config_group = $rs_config_group->find( { name => $group_name, channel_id => $channel_id } );

            # If we found the group.
            if ( $config_group ) {

                my $config_group_settings = $config_group->config_group_settings;

                cmp_ok( $config_group->active, '==', $group->{active}, "$group_message is " . ( $group->{active} ? '' : 'not ' ) . 'active' )
                            unless ( $group->{ignore_active} );

                # Count how many settings this group has.
                my $settings_count = $config_group_settings->count;

                # Check the count, min and max match.
                _cmm( $settings_count, $group->{count}, 'count', $channel_name, $group_name );
                _cmm( $settings_count, $group->{min}, 'min', $channel_name, $group_name );
                _cmm( $settings_count, $group->{max}, 'max', $channel_name, $group_name );

                # Go through each setting.
                while ( my ( $setting_name, $setting ) = each %{ $group->{settings} } ) {

                    # Count the number of values for this setting.
                    my $values_count = $config_group_settings->search( { 'setting' => $setting_name } )->count;

                    # Check the count, min and max match.
                    _cmm( $values_count, $setting->{count}, 'count', $channel_name, $group_name, $setting_name );
                    _cmm( $values_count, $setting->{min}, 'min', $channel_name, $group_name, $setting_name );
                    _cmm( $values_count, $setting->{max}, 'max', $channel_name, $group_name, $setting_name );

                    # If we've been given just a single value to check, expand it into an ArrayRef.
                    $setting->{'values'} = [ $setting->{'values'} ]
                        if ref( $setting->{'values'} ) eq 'HASH';
                    # This is used to store the current sequence of the value.

                    my @values  =  defined $setting->{'values'}  ? @{ $setting->{'values'} } : ();

                    my $sequence = scalar( @values ) > 1 ? 1 : 0 ;

                    # Go through all the requested values to check.
                    foreach my $value ( @values ) {
                        # Construct the full path to the value.
                        my $message = _path( $channel_name, $group_name, $setting_name, $sequence );

                        # Default value.
                        $value->{active} ||= 1;
                        # Attempt to locate the value for this setting.
                        my $record = $config_group_settings->search( {
                            'setting'   => $setting_name,
                            'sequence'  => $sequence++,
                        } );

                        if ( $record && $record->count == 1 ) {
                        # Check the value is correct.

                            cmp_ok( $record->first->value, 'eq', $value->{value}, "$message has correct value of '$value->{value}'" );
                            cmp_ok( $record->first->active, '==', $value->{active}, "$message is " . ( $value->{active} ? '' : 'not ' ) . 'active' );

                        } else {
                        # Fail the test if we cannot find the value.

                            fail "$message cannot find matching value";

                        }

                    } # Each Value to Check

                } # Each Setting

            } # If we found the group.

            else {

                fail( "$group_message cannot find the group" );

            }

        } # Each Group

    } # Each Channel

    note 'Completed Tests';

} # If HASH

done_testing;
