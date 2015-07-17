package Test::NAP::GoodsIn::PutawayPrepRecode;

=head1 NAME

Test::NAP::GoodsIn::PutawayPrepRecode - Test the Putaway Prep pages with Recodes

=head1 DESCRIPTION

Test the Putaway Prep pages with Recodes.

#TAGS goodsin putawayprep prl recode

=head1 METHODS

=cut

use NAP::policy "tt", qw/test class/;

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::GoodsIn::PutawayPrep";
};

use FindBin::libs;

use XTracker::Constants::FromDB qw(
    :storage_type
    :container_status
);
use XTracker::Database::Container qw(:utils);

use Test::XTracker::RunCondition prl_phase => 'prl';
use Test::XTracker::Mechanize::GoodsIn;
use Test::Differences;

sub startup : Tests(startup => 2) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    use_ok 'XTracker::Stock::GoodsIn::PutawayPrep';

    $self->{pp} = XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $self->schema });

    $self->{flow} = $self->get_flow; # we only need to log in once
}

# Return data structure with error keys and templates
#
sub error_dictionary {
    my ($test) = @_;

    return $test->{__error_dictionary} ||= XTracker::Stock::GoodsIn::PutawayPrep->error_dictionary;
}

# Return data structure with prompt keys and teplates
#
sub prompt_dictionary {
    my ($test) = @_;

    return $test->{__prompt_dictionary} ||=
        XTracker::Stock::GoodsIn::PutawayPrep->prompt_dictionary;
}


=head2 check_toggling_scan_mode

Check if toggling scanning mode works as expected, please see comments in test
for further details.

=cut

sub check_toggling_scan_mode :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get PGID with one products in it
    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got PGID';

    # get SKU
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    # Initiate Putaway Prep process and scan two items of SKU
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # make sure page has correct content
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $recode_barcode,
                container_id      => $container_id,
                recode            => 1,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Two SKUs are in container.'
    );

    # toggle scan mode to "reverse" and scan out SKU
    $flow->mech__goodsin__putaway_prep_change_scan_mode;

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN_REMOVE_SKU},
        'User prompt is correct after switching to reverse scan mode.'
    );

    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # check that one SKU was removed
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $recode_barcode,
                container_id      => $container_id,
                recode            => 1,
                container_content => [
                     {
                       'Quantity'  => '1',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'One SKU is left.'
    );

    # check that after SKU is removed - scan mode is set to default one automatically
    # by scanning SKU, which should be added to container
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # check that one SKU was removed
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $recode_barcode,
                container_id      => $container_id,
                recode            => 1,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Two SKUs again.'
    );


    # check that canceling "reverse" scan mode works, so toggle scan mode
    # twice and scan SKU - it should be added to container
    $flow->mech__goodsin__putaway_prep_change_scan_mode
         ->mech__goodsin__putaway_prep_change_scan_mode;

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User prompt is correct after canceling SKU removing mode.'
    );

    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $recode_barcode,
                container_id      => $container_id,
                recode            => 1,
                container_content => [
                     {
                       'Quantity'  => '3',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'And now three SKUs are left.'
    );
}

=head2 check_quantity_values

Check quantity fields in container table.

Consider both screens: ordinary container screen and resume container.

=cut

sub check_quantity_values :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    # get SKU
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    # Initiate Putaway Prep process and scan two items of same SKU
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);


    # Check that page content has one record for scanned SKUs but correspondent
    # quantity is 2
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                group_id          => $recode_barcode,
                recode            => 1,
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Have quantity "2" for scanned SKU.'
    );

    # pretend that current container was given up but then resumed
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that resume container screen has correct quantity for each number
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id      => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Quantity persists over container resuming.'
    );
}

=head2 after_container_is_resumed_pgid_is_validated

Here we try to resume existing container with some nonsense as group ID.

=cut

sub after_container_is_resumed_pgid_is_validated :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    # get all skus
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    $flow->mech__goodsin__putaway_prep
         # init reocde ID
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # resume container
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $error_msg = sprintf(
        $test->error_dictionary->{ERR_START_PGID_GENERAL_FAILURE},
        'blablabla',
        'PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID'
    );

    # try to submit nonsense as a PGID
    $flow->catch_error(
        $error_msg,
        'Submitting wrong Recode ID while resuming container is handled correctly.',
        mech__goodsin__putaway_prep_submit => (scan_value => 'blablabla')
    );
}

=head2 try_to_scan_nonsense_into_container

Check situation if there is an attempt to scan some nonsense into container,
instead of SKU or new Group ID.

=cut

sub try_to_scan_nonsense_into_container :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    # get all skus
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_RECODE_ID_GENERAL_FAILURE},
        "rblablabla", 'PGID/Recode group ID is invalid. Please scan a valid PGID/Recode group ID';

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init recode ID
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);
    # scan something completely irrelevant, so it is neither SKU nor PGID
    $flow->catch_error(
        $error_msg,
        'Correct error message is shown to end user after attempt to scan some invalid Recode group or SKU.',
        mech__goodsin__putaway_prep_submit => (scan_value => 'rblablabla')
    );

    # check that user is prompted with correct message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User prompt is correct'
    );
}

=head2 resume_container_with_another_recode_id

Start container with one PGID and then resume with another one.

=cut

sub resume_container_with_another_recode_id :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init recode ID
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);


    # open PutawayPrep page once again,
    # so we have contained uncomplete
    $flow->mech__goodsin__putaway_prep;

    # scan container ID, so it is resumed
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    # check that user is prompted with right message
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_RESUME_CONTAINER_ASK_FOR_GROUP},
        'User is asked to enter PGID when resuming container'
    );


    # check page content, there should not be Recode ID yet
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
            },
        },
        'Check page content. Recode ID is undefined.'
    );

    my ($recode_id2, $recode_barcode2) = $test->get_test_recode;
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($recode_id2) };

    # try to resume container with the second recode ID
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode2);

    # check that correct user prompt is shown
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User is advised to begin scaning SKUs from secondi Record group.'
    );

    # check that page now contains second recode ID as active one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                recode       => 1,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                   ],
                group_id => $recode_barcode2,
            },
        },
        'Check page content. Second recode group is active.'
    );

    # scan SKU from second recode group into container
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku2);

    # correct prompt is in place
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN},
        'User is advised to continue scaning SKUs from second recode group.'
    );

    # check that page has correct data that reflect one SKU from
    # first recode group and one from second. And active recode group
    # is second one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                recode       => 1,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => $recode_id2,
                       'SKU'  => $sku2,
                     },
                   ],
                group_id => $recode_barcode2,
            },
        },
        'Check page content. Container has SKUs from different recode groups.'
    );
}

=head2 try_to_add_recode_group_of_wrong_storage_type

Start container with one recode group and try to add a recode group that needs
a different container type.

=cut

sub try_to_add_recode_group_of_wrong_storage_type :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # we'll use a tote
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # get recode group with flat product in it
    # flat items can go in totes
    my ($recode_id, $recode_barcode) = $test->get_test_recode({
        product_storage_type_id => $PRODUCT_STORAGE_TYPE__FLAT
    });
    ok $recode_id, 'Got Recode group';

    # get sku
    my ($sku) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init recode group
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    # now get a recode group with oversized items, which can't go in totes in DC2/DC3
    my ($recode_id2, $recode_barcode2) = $test->get_test_recode({
        product_storage_type_id => $PRODUCT_STORAGE_TYPE__OVERSIZED
    });
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($recode_id2) };

    my $compatible_storage_types = get_compatible_storage_types_for($container_id);

    # try to scan PGID relating to a storage type that can't go in a tote
    # and this should fail.
    my $error_msg = sprintf $test->error_dictionary->{ERR_START_RECODE_ID_BAD_CONTAINER_TYPE},
            $recode_barcode2, $container_id,
            "Invalid container. Container '$container_id' is for storage type(s) '"
            . join(', ', @$compatible_storage_types)
            . "'. Please scan valid container";

    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $recode_barcode2)
    );
}

=head2 mark_container_as_completed

=cut

sub mark_container_as_completed :Tests {
    my ($test) = @_;

    # get recode group to be used in test
    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got recode ID';

    # get SKUs from recode group ID
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init recode group
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
         # scan sku into container again
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);


    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                recode => 1,
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $recode_barcode,
            },
        },
        'Check page content'
    );

    # complete container, assume PRL specific questions have NOT been asked
    $flow->mech__goodsin__putaway_prep_complete_container;
}

=head2 mark_dematic_flat_container_as_completed

=cut

sub mark_dematic_flat_container_as_completed :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # get PGID to use in test
    my ($recode_id, $recode_barcode) = $test->get_test_recode({
        product_storage_type_id => $PRODUCT_STORAGE_TYPE__DEMATIC_FLAT
    });
    ok $recode_id, 'Got recode ID';

    # get SKUs from recode group ID
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init recode group
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan first sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
         # scan sku into container again
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);


    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                recode => 1,
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $recode_barcode,
            },
        },
        'Check page content'
    );

    # check handling of PRL specific question while marking container as completed
    $test->check_prl_specific_answer({
        flow => $flow,
    });
}

=head2 try_to_scan_sku_that_is_not_associated_with_current_recode_id

=cut

sub try_to_scan_sku_that_is_not_associated_with_current_recode_id :Tests {
    my ($test) = @_;

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    # get SKU from first recode group
    my ($sku1) = @{ $test->{pp}->get_skus_for_group_id($recode_id) };

    # get SKU that relates to different recode group
    my ($recode_id2, $recode_barcode2) = $test->get_test_recode;
    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($recode_id2) };

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new recode group (scan first recode ID)
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan SKU from first recode group into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);

    my $error_msg = sprintf $test->error_dictionary->{ERR_SKU_NOT_FROM_RECODE_ID},
            $sku2, $recode_barcode;

    # try to scan SKU that does not relate to first (active) recode group
    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $sku2)
    );

    # check that user has correct prompt
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );
}

=head2 scan_three_items_from_two_recode_groups_into_container

=cut

sub scan_three_items_from_two_recode_groups_into_container :Tests {
    my ($test) = @_;

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    my ($sku1) =  @{ $test->{pp}->get_skus_for_group_id($recode_id) };


    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });


    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new recode
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1)
         # scan sku into container
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku1);

    # check user prompt
    is(
        $flow->mech->app_info_message,
        $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );

    # check if page contains all required info
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $recode_barcode,
                recode => 1,
            },
        },
        'Check page content'
    );

    # get new recode group with new SKU
    my ($recode_id2, $recode_barcode2) = $test->get_test_recode;

    my ($sku2) = @{ $test->{pp}->get_skus_for_group_id($recode_id2) };

    # scan second recode ID
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode2);

    # check that new recode group was initiated
    is(
        $flow->mech->app_info_message,
        sprintf($test->prompt_dictionary->{PRM_START_ANOTHER_RECODE_ID_FOR_CONTAINER},
             $recode_barcode2
        )
        . $test->prompt_dictionary->{PRM_CONTAINER_SCREEN}
    );

    # check if current recode group was switched to newly passed one
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku1,
                     },
                   ],
                group_id => $recode_barcode2,
                recode => 1,
            },
        },
        'Active recode group changed to be new one'
    );


    # scan SKU from second recode group
    $flow->mech__goodsin__putaway_prep_submit(scan_value => $sku2);

    is( $flow->mech->app_info_message, $test->prompt_dictionary->{PRM_CONTAINER_SCREEN});

    # check that third sku was added into appropriate place
    is_deeply(
        $flow->mech->as_data,
        {
            form => {
                container_id => $container_id,
                container_content => [
                     {
                       'Quantity'  => '2',
                       'PGID' => $recode_id,
                       'SKU'  => $sku1,
                     },
                     {
                       'Quantity'  => '1',
                       'PGID' => $recode_id2,
                       'SKU'  => $sku2,
                     }
                   ],
                group_id => $recode_barcode2,
                recode => 1,
            },
        },
        'Third SKU is in right place'
    );
}

=head2 scan_correct_container

Check case when correct container was scanned.

Test for different storage types.

=cut

sub scan_correct_container :Tests  {
    my ($test) = @_;


    my $flow = $test->{flow};

    # flat things go in totes, oversized things in oversize containers
    foreach my $combination (
        {
            'container_type'  => 'Tote With Orientation',
            'prefix'          => 'T1',
            'storage_type_id' => $PRODUCT_STORAGE_TYPE__FLAT,
        },
        {
            'container_type'  => 'Oversize Container',
            'prefix'          => 'V111',
            'storage_type_id' => $PRODUCT_STORAGE_TYPE__OVERSIZED,
        },
    ) {
        my ($recode_id, $recode_barcode) = $test->get_test_recode({
            product_storage_type_id => $combination->{storage_type_id}
        });
        ok $recode_id, 'Got Group ID';

        my ($container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => $combination->{prefix},
        });

        $flow->mech__goodsin__putaway_prep
             ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode);

        is( $flow->mech->app_info_message,
            sprintf($test->prompt_dictionary->{'PRM_RECODE_ID_PAGE_GENERAL'},$combination->{container_type}));

        $flow->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

        is_deeply($flow->mech->as_data,
            {
                form => {
                    group_id     => $recode_barcode,
                    container_id => $container_id,
                    container_content => [],
                    recode => 1,
                },
            },
            'Form has all necessary data.'
        );

        # comment is correct
        is( $flow->mech->app_info_message, $test->prompt_dictionary->{PRM_CONTAINER_SCREEN});

    }
}

=head2 scan_incorrect_container

Check case when some incorrect container ID is scanned.

=cut

sub scan_incorrect_container :Tests {
    my ($test) = @_;

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode);

    my $error_msg = sprintf $test->error_dictionary->{ERR_START_CONTAINER_INVALID},
        'bla bla bla';

    $flow->catch_error(
        $error_msg,
        "Scan some nonsense instead of real container ID.",
        mech__goodsin__putaway_prep_submit => ('scan_value' => 'bla bla bla')
    );

    is_deeply($flow->mech->as_data,
        {
            form => {
                group_id => $recode_barcode,
                recode => 1,
            },
        },
        'Product group ID was passed from previous screen.'
    );
}

=head2 scan_correct_recode_id

Check case when user successfully scan Product process ID.

=cut

sub scan_correct_recode_id :Tests {
    my ($test) = @_;

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    my $flow = $test->{flow};

    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode);

    is_deeply($flow->mech->as_data,
        {
            form => {
                group_id => $recode_barcode,
                recode => 1,
            },
        },
        'Recode ID was passed from previous screen.'
    );

    # user prompt is correct
    is(
        $flow->mech->app_info_message,
        sprintf($test->prompt_dictionary->{'PRM_RECODE_ID_PAGE_GENERAL'},'Tote With Orientation')
    );
}

=head2 try_to_scan_container_in_wrong_status

Check if correct error is displayed if scanned container has incorrect status.

=cut

sub try_to_scan_container_in_wrong_status :Tests {
    my ($test) = @_;

    my $flow = $test->{flow};

    # we'll use a tote
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    my $container = $test->schema->resultset('Public::Container')->find($container_id);
    ok $container, 'Container object was fetched.';

    # make current container to have invalid status
    $container->update({status_id => $PUBLIC_CONTAINER_STATUS__PICKED_ITEMS});

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';


    # init new putaway prep page and scan recode ID
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode);

    # get container's status name
    my $container_status = $test->schema->resultset('Public::ContainerStatus')
        ->find($container->status_id);
    $container_status = $container_status->name;

    # compose error message
    my $error_msg = sprintf $test->error_dictionary->{ERR_START_CONTAINER_FAILURE},
        $container_id,
        qq!Container '$container_id' is not available for put away prep,!
        . qq! it is currently being used for '$container_status'. Please scan another container!;

    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => $container_id->as_barcode)
    );
}

=head2 scan_unknown_sku_into_container

Check scenario when non existing SKU is scanned into container.

=cut

sub scan_unknown_sku_into_container :Tests {
    my ($test) = @_;

    my ($recode_id, $recode_barcode) = $test->get_test_recode;
    ok $recode_id, 'Got Recode ID';

    my $flow = $test->{flow};
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    # init new putaway prep page
    $flow->mech__goodsin__putaway_prep
         # init new Recode group
         ->mech__goodsin__putaway_prep_submit(scan_value => $recode_barcode)
         # scan new container
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode);

    my $error_msg = sprintf $test->error_dictionary->{ERR_SKU_UNKNOWN}, '000000-000';

    $flow->catch_error(
        $error_msg,
        'Correct error message is shown',
        mech__goodsin__putaway_prep_submit => (scan_value => '000000-000')
    );
}

1;
