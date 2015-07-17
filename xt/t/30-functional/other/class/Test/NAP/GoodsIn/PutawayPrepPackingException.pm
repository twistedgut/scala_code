package Test::NAP::GoodsIn::PutawayPrepPackingException;

=head1 NAME

Test::NAP::GoodsIn::PutawayPrepPackingException - Test the Putaway Prep Packing Exception page

=head1 DESCRIPTION

On the Putaway Prep Packing Exception page, scan containers in various states.
Verify the correct messages are displayed.

#TAGS goodsin putawayprep packingexception prl

=head1 METHODS

=cut

use NAP::policy "tt", qw/class test/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::GoodsIn::PutawayPrep";
};

use FindBin::libs;

use Test::XTracker::Mechanize::GoodsIn;
use Test::XTracker::RunCondition prl_phase => 'prl';
use XTracker::Constants qw/ :application /;
use XTracker::Constants::FromDB qw/
    :authorisation_level
    :container_status
    :storage_type
/;
use Test::More::Prefix qw/test_prefix/;
use Test::Deep;
use MooseX::Params::Validate qw/ validated_list /;
use Test::NAP::Messaging::Helpers 'atleast';

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    use_ok 'XTracker::Stock::GoodsIn::PutawayPrepPackingException';

    $self->{pp} = XTracker::Database::PutawayPrep->new({ schema => $self->schema });
}

=head2 check_permissions

=cut

sub check_permissions : Tests {
    my ($self) = @_;

    note 'Get non-standard flow object - login as someone with no permissions for'
        . ' "Putaway Problem Packing Exception" page';
    my $flow = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::GoodsIn',
        ],
    );

    $flow->login_with_permissions({
        dept  => 'Distribution Management',
        perms => {
            $AUTHORISATION_LEVEL__OPERATOR => [
                'Goods In/Putaway Prep',
            ],
            $AUTHORISATION_LEVEL__MANAGER => [
                'Goods In/Putaway Prep',
            ],
        },
    });

    $flow->catch_error(
        q/FATAL ERROR: You don't have permission to access Putaway Prep Packing Exception in Goods In.. Unable to continue./,
        'Deny access when attempt to load Resolution page with wrong credentials',
        mech__goodsin__putaway_prep_packing_exception => ()
    );


    note 'Now get proper handler and try to open page again';
    $flow = $self->get_flow;
    $flow->mech__goodsin__putaway_prep_packing_exception;
}


=head2 check_container_scanning

=cut

sub check_container_scanning :Tests {
    my ($self) = @_;

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });
    my $flow = $self->get_flow;


    $flow->mech__goodsin__putaway_prep_packing_exception;
    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_CONTAINER_INVALID_ID},
            'blablabla'
        ),
        'Try to scan non-sense as a container',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            container_id => 'blablabla',
        })
    );


    note 'Try to submit valid fresh container';
    $flow->mech__goodsin__putaway_prep_packing_exception_submit({
        container_id => $container_id->as_barcode
    });

    is_deeply(
        {
            container_id => $container_id,
        },
        $flow->mech->as_data->{form},
        'Container ID picked up and brought to the next page'
    );


    note 'Start putaway prep';
    my $group_id = $self->get_test_pgid(1);
    my ($sku) = @{ $self->{pp}->get_skus_for_group_id($group_id) };
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $group_id)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    note 'Try to use this container for Putaway Prep Packing Exception';
    $flow->mech__goodsin__putaway_prep_packing_exception;

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_CONTAINER_ALREADY_STARTED_AT_NORMAL_PUTAWAY_PREP},
            $container_id
        ),
        'And get error message that this container is not available',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            container_id => $container_id->as_barcode,
        })
    );
}

=head2 scan_in_and_out_of_container

=cut

sub scan_in_and_out_of_container :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });
    my ($sku) = @{ $self->create_stock_in_cancelled_location(1, {sku_multiplicator => 2}) };

    note 'Open "Putaway prep Packing exception" page and scan two items'
        . ' into new container';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku,
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku,
        });

    cmp_deeply(
        $flow->mech->as_data->{form},
        {
            toggle_scan_mode_label => 'Remove SKU',
            container_id => "$container_id",
            container_content => [
                {
                    'Quantity'  => 2,
                    'SKU'       => $sku,
                    'Group ID'  => ignore(),
                }
            ]
        },
        'Check page content'
    );

    note 'Toggle scan mode and scan one item out from container';
    $flow->mech__goodsin__putaway_prep_packing_exception_toggle_scan_mode
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku,
        });
    cmp_deeply(
        $flow->mech->as_data->{form},
        {
            toggle_scan_mode_label => 'Cancel',
            container_id => "$container_id",
            container_content => [
                {
                    'Quantity'  => 1,
                    'SKU'       => $sku,
                    'Group ID'  => ignore(),
                }
            ]
        },
        'Check page content'
    );
}

=head2 check_that_it_is_impossible_to_scan_SKU_not_from_cancelled_location

=cut

sub check_that_it_is_impossible_to_scan_SKU_not_from_cancelled_location : Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate SKU that comes not from cancelled location';
    my ($sku_not_from_cancelled_location) =
        @{ $self->{pp}->get_skus_for_group_id( $self->get_test_pgid(1) ) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Open putaway prep for packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_SKU_UNKNOWN},
            $sku_not_from_cancelled_location
        ),
        'Try to scan SKU not from cancelled location',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            sku => $sku_not_from_cancelled_location,
        })
    );

    note 'Now get the  SKU from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location };

    note 'It is OK to scan it into container';
    $flow->mech__goodsin__putaway_prep_packing_exception_submit({
        sku => $sku,
    });
}

=head2 scan_nonsense_as_a_sku

=cut

sub scan_nonsense_as_a_sku : Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Open putaway prep for packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        });

    my $error_message = sprintf(
        XTracker::Stock::GoodsIn::PutawayPrepPackingException
            ->error_dictionary
            ->{ERR_SKU_UNKNOWN},
        'blablabla'
    );

    $flow->catch_error(
        qr/^$error_message/,
        'Try to scan some nonesense as SKU',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            sku => 'blablabla',
        })
    );
}

=head2 messages_are_sent_after_container_is_complete

=cut

sub messages_are_sent_after_container_is_complete :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate SKU that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Prepare container to be completed from putaway prep packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    my $amq = Test::XTracker::MessageQueue->new;
    note 'Clean up queue dump directory (just in case)';
    $amq->clear_destination();

    my $is_there_prl_specific_questions = defined
        $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id})
            ->get_prl_specific_questions;

    note('Mark container as complete');
    my %complete_container_args;
    $complete_container_args{prl_specific_question__container_fullness} = '.50'
        if $is_there_prl_specific_questions;
    $flow->mech__goodsin__putaway_prep_packing_exception_complete_container(
        \%complete_container_args
    );

    $amq->assert_messages({
        filter_header => superhashof({
            type => 'advice',
        }),
        ( $is_there_prl_specific_questions
              ? ( assert_body => superhashof({
                  container_fullness => '.50',
              }) ) : () ),
        assert_count => 1,
    },'One Advice message was sent'.
        ($is_there_prl_specific_questions?' and Container fullness is passed to Advice message':''));

    $amq->assert_messages({
        filter_header => superhashof({
            type => 'sku_update',
        }),
        assert_count => atleast(1),
    },'SKU update messages are sent');

    $amq->clear_destination();

    note 'Check that just submitted cintainer could not be used for PP';
    $flow->mech__goodsin__putaway_prep_packing_exception;
    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_CONTAINER_IN_USE},
            $container_id
        ),
        'Container in progress is handled correctly',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            container_id => $container_id->as_barcode,
        })
    );

    $self->_check_container_was_submitted({ container_id => $container_id, });
}

=head2 check_that_completed_container_could_be_sourced_from_location

=cut

sub check_that_completed_container_could_be_sourced_from_location :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate SKU that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    note 'Update container behind the scene to include additional item that is not in Cancelled location';
    my $group_id = $flow->mech->as_data->{form}{container_content}[0]{'Group ID'};
    $self->schema->resultset('Public::PutawayPrepContainer')->add_sku({
        group_id     => $group_id,
        sku          => $sku,
        container_id => $container_id,
        putaway_prep => XTracker::Database::PutawayPrep::CancelledGroup->new({schema => $self->schema}),
    });

    my $is_there_prl_specific_questions = defined
        $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id})
            ->get_prl_specific_questions;

    my %complete_container_args;
    $complete_container_args{prl_specific_question__container_fullness} = '.50'
        if $is_there_prl_specific_questions;

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_SURPLUS_IN_CONTAINER}
        ),
        'Surplus in the container is handled correctly',
        mech__goodsin__putaway_prep_packing_exception_complete_container
            => ( \%complete_container_args )
    );
}

=head2 try_to_scan_sku_that_is_not_in_cancelled_location

=cut

sub try_to_scan_sku_that_is_not_in_cancelled_location :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate single instance of SKU that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_SKU_IS_NOT_FROM_CANCELLED_LOCATION},
            $sku
        ),
        'System complains about unknown item',
        mech__goodsin__putaway_prep_packing_exception_submit => ({sku => $sku})
    );
}

=head2 scan_container_id_which_in_wrong_non_putaway_prep_related_status

=cut

sub scan_container_id_which_in_wrong_non_putaway_prep_related_status :Tests {
    my $self = shift;

    note 'Get container for testing';
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });
    my $container = $self->schema->resultset('Public::Container')->find($container_id);
    ok $container, 'Container object was fetched.';

    note 'Update container to have invalid status';
    $container->update({status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS});

    my $flow = $self->get_flow;
    $flow->mech__goodsin__putaway_prep_packing_exception;

    # We do not do exact match of error message because, there "reason" is not
    # constant but hardcoded test, so lets avoid yet one more duplication.
    # Basically matching first part of the error message should be enough.
    my $error_msg = sprintf(
        XTracker::Stock::GoodsIn::PutawayPrepPackingException
            ->error_dictionary
            ->{ERR_INVALID_CONTAINER},
        $container_id, ''
    );

    $flow->catch_error(
        qr/$error_msg/,
        'Page does not accept container in wrong status',
        mech__goodsin__putaway_prep_packing_exception_submit
            => ({ container_id => $container_id->as_barcode })
    );
}

=head2 detect_mismatch_in_storage_types_between_container_and_scanned_sku

=cut

sub detect_mismatch_in_storage_types_between_container_and_scanned_sku :Tests {
    my $self = shift;

    my $flow = $self->get_flow;

    note 'Get SKU that is of product with Oversized storage type';
    my ($sku_a) = @{
        $self->create_stock_in_cancelled_location(1, {
            storage_type_id => $PRODUCT_STORAGE_TYPE__OVERSIZED,
        })
    };

    note 'Get container that is not suitable for Oversized stock';
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Start Putaway prep for Packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        });

    my $error_msq = sprintf(
        XTracker::Stock::GoodsIn::PutawayPrepPackingException
            ->error_dictionary
            ->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
            $sku_a, ''
    );

    $flow->catch_error(
        qr/$error_msq/,
        'Detect mismatch between storage types of Container and SKU',
        mech__goodsin__putaway_prep_packing_exception_submit => ({ sku => $sku_a })
    );

    ok(
        !$flow->mech->as_data->{form}{container_id},
        'User is redirected back to the first page - because container was empty'
    );

    note 'Get SKU that is of product with flat storage type';
    my ($sku_b) = @{ $self->create_stock_in_cancelled_location(1) };

    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku_b
        });

    $flow->catch_error(
        qr/$error_msq/,
        'Detect mismatch between storage types of Container and SKU',
        mech__goodsin__putaway_prep_packing_exception_submit => ({ sku => $sku_a })
    );

    is(
        $container_id,
        $flow->mech->as_data->{form}{container_id},
        'If container is not empty - after error ocurres - user stays on the same page'
    );
}

=head2 check_that_container_has_single_prl_to_be_dispatched_to

=cut

sub check_that_container_has_single_prl_to_be_dispatched_to  :Tests {
    my $self = shift;

    note 'Here we check that it is impossible to pack container with SKUs that are comming';
    note 'into different PRLs';
    my $flow = $self->get_flow;


    note 'Get SKU of "Dematic flat" storage type';
    my ($sku_dematic_flat) = @{
        $self->create_stock_in_cancelled_location(1, {
            storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT,
        })
    };
    note 'Get SKU of "Flat" storage type';
    my ($sku_flat) = @{
        $self->create_stock_in_cancelled_location(1, {
            storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT,
        })
    };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode,
        });

    note 'Try to add both of those SKUs into single tote';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode,
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku_dematic_flat,
        });



    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException
                ->error_dictionary
                ->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER_NO_REASON},
                $sku_flat, $container_id->as_barcode
        ),
        'Detect incompatibility of SKU and container: there is no single PRL that could accept container',
        mech__goodsin__putaway_prep_packing_exception_submit => ({ sku => $sku_flat })
    );
}

=head2 place_two_items_of_the_same_sku_into_container_and_complete_it

=cut

sub place_two_items_of_the_same_sku_into_container_and_complete_it :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'In "Cancelled location" generate two items of the same SKU';
    my ($sku) = @{ $self->create_stock_in_cancelled_location(1, {sku_multiplicator => 2}) };

    note 'Place those two items into contauer';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    my $is_there_prl_specific_questions = defined
        $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id})
            ->get_prl_specific_questions;

    my %complete_container_args;
    $complete_container_args{prl_specific_question__container_fullness} = '.50'
        if $is_there_prl_specific_questions;

    note 'And try to complete container';
    $flow->mech__goodsin__putaway_prep_packing_exception_complete_container(
        \%complete_container_args
    );

    note 'There should not be any errors';

    $self->_check_container_was_submitted({ container_id => $container_id, });
}

sub _check_container_was_submitted {
    my ($self, $container_id) = validated_list(\@_,
        container_id => {isa => 'NAP::DC::Barcode::Container'},
    );

    note 'Check that stock from just submitted container was removed from "Cancelled location"';
    my $pp_container_row =
        $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_transit({container_id => $container_id});
    my $cancelled_location_row =
        $self->schema->resultset('Public::Location')
            ->get_cancelled_location;
    ok(
        !$cancelled_location_row->does_include_variants([
            $pp_container_row->putaway_prep_inventories
                ->first->variant_with_voucher
        ]),
        'Putaway SKU was removed from "Cancelled location"'
    );
}

=head2 try_to_complete_container_with_voucher

=cut

sub try_to_complete_container_with_voucher :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note 'Generate voucher that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location(
        1,
        {
            vouchers => {
                how_many => 1,
            },
        }
    ) };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'M0',
    });

    note 'Prepare container to be completed from putaway prep packing exception';
    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    my $is_there_prl_specific_questions = defined
        $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id})
            ->get_prl_specific_questions;

    note('Mark container as complete');
    my %complete_container_args;
    $complete_container_args{prl_specific_question__container_fullness} = '.50'
        if $is_there_prl_specific_questions;
    $flow->mech__goodsin__putaway_prep_packing_exception_complete_container(
        \%complete_container_args
    );

    $self->_check_container_was_submitted({ container_id => $container_id, });
    note 'There should not be any errors';
}

=head2 try_to_have_voucher_as_one_of_multiple_items

=cut

sub try_to_have_voucher_as_one_of_multiple_items :Tests {
    my $self = shift;

    my $flow = $self->get_flow;

    my ($sku_flat)    = @{ $self->create_stock_in_cancelled_location(1) };
    my ($sku_voucher) = @{ $self->create_stock_in_cancelled_location(
        1,
        {
            vouchers => {
                how_many => 1,
            },
        }
    ) };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'M0',
    });

    $flow->mech__goodsin__putaway_prep_packing_exception
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            container_id => $container_id->as_barcode,
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku_voucher,
        });

    my $error_message_regex = sprintf(
        XTracker::Stock::GoodsIn::PutawayPrepPackingException
            ->error_dictionary
            ->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
        $sku_flat, ".+$container_id.+"
    );

    $flow->catch_error(
        qr/$error_message_regex/,
        'Try to add flat SKU to the container that already has Voucher',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            sku => $sku_flat,
        })
    );
}
