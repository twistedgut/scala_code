package Test::NAP::GoodsIn::PutawayProblemResolution;

=head1 NAME

Test::NAP::GoodsIn::PutawayProblemResolution - Test the Putaway Problem Resolution page

=head1 DESCRIPTION

Test the Putaway Problem Resolution page

#TAGS goodsin putawayprep packingexception migration recode cancel loops

=head1 METHODS

=cut

use NAP::policy "tt", qw/class test/;
use FindBin::libs;
use Test::XTracker::RunCondition prl_phase => 'prl';

BEGIN { # at BEGIN time to play nicely with Test::Class
    extends "NAP::Test::Class";
    with "Test::Role::GoodsIn::PutawayPrep";
};

use MooseX::Params::Validate qw/validated_list/;
use Data::UUID;

use Test::XTracker::Mechanize::GoodsIn;
use XTracker::Constants::FromDB qw/
    :authorisation_level
    :flow_status
    :putaway_prep_container_status
    :putaway_prep_group_status
    :storage_type
/;
use XTracker::Constants qw/:prl_type/;
use XTracker::Schema::Result::Public::PutawayPrepContainer;
use XTracker::Database::PutawayPrep::CancelledGroup;
use XTracker::Database::PutawayPrep::MigrationGroup;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Database::PutawayPrep;
use XTracker::Stock::GoodsIn::PutawayPrepPackingException;
use XT::Domain::PRLs;

use Test::More::Prefix qw/test_prefix/;
use Test::NAP::Messaging::Helpers 'atleast';
use Test::XTracker::Artifacts::RAVNI;
use Test::XT::Data::PutawayPrep;

sub startup : Test(startup => 1) {
    my ( $self ) = @_;

    $self->SUPER::startup;

    use_ok 'XTracker::Stock::GoodsIn::PutawayProblemResolution';

    $self->{pp} = XTracker::Database::PutawayPrep->new({ schema => $self->schema });
}

=head2 advice_response_related_failures

Pretend that we got advice responses with different failure reasons.

=cut

sub advice_response_related_failures :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note("Get PGID with one products in it");
    my $pgid = $self->get_test_pgid(1);

    note("Get SKU");
    my ($sku) = @{ $self->{pp}->get_skus_for_group_id($pgid) };

    # in following test cases these keys mean:
    #   - advice_failure_reason - value of reason field in advice response message,
    #   - is_start_pp_control - there is a UI control for starting new put away preparation
    #       process,
    #   - is_resend_sku_update_control - page has UI elements for re-sending SKU_UPDATE
    #       message.
    foreach my $case (
        {
            setup => {
                test_prefix           => 'Bad sku failure.',
                advice_failure_reason => 'SKUs in Advice not recognised',
            },
            expected => {
                checked_failure     => 'BAD_SKU',
                is_start_pp_control => 1,
            },
        },
        {
            setup => {
                test_prefix           => 'Bad mix failure (based on PRL AdviceResponse).',
                advice_failure_reason => 'Rules were broken in Advice message',
            },
            expected => {
                checked_failure     => 'BAD_MIX',
                is_start_pp_control => 1,
            }
        },
        {
            setup => {
                test_prefix           => 'Bad mix failure (based on failed AdviceResponse from Dematic).',
                advice_failure_reason => 'Invalid mix detected',
            },
            expected => {
                checked_failure     => 'BAD_MIX',
                is_start_pp_control => 1,
            }
        },
        {
            setup => {
                test_prefix           => 'Bad container failure.',
                advice_failure_reason => 'The PRL believes it already has the container and is using it',
            },
            expected => {
                checked_failure     => 'BAD_CONTAINER',
                is_start_pp_control => 1,
            },
        },
        {
            setup => {
                test_prefix           => 'Overweight failure (General Overweight criteria).',
                advice_failure_reason => 'Overweight',
            },
            expected => {
                checked_failure     => 'OVERWEIGHT',
                is_start_pp_control => 1,
            },
        },
        {
            setup => {
                test_prefix           => 'Overweight failure (based on failed AdviceResponse from Dematic).',
                advice_failure_reason => 'Max tote weight violation',
            },
            expected => {
                checked_failure     => 'OVERWEIGHT',
                is_start_pp_control => 1,
            },
        },
        {
            setup => {
                test_prefix           => 'Handle Unknown advice failure Reason.',
                advice_failure_reason => q|Invalid 'Best Before Date'|,
            },
            expected => {
                checked_failure     => 'UNKNOWN',
                is_start_pp_control => 1,
            },
        },
        {
            setup => {
                test_prefix           => 'Check case if overweight comes from PRL.',
                advice_failure_reason => q|Rules were broken in Advice message: |
                    .q|Container weight limit is 54.00lbs. Current contents weight |
                    .q|is 0.00lbs, so can't add item weighing 66.14lbs|,
            },
            expected => {
                checked_failure     => 'OVERWEIGHT',
                is_start_pp_control => 1,
            },
        },

    ) {
        test_prefix($case->{setup}{test_prefix});

        my ($container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => 'T0',
        });

        note("Complete putaway prep on XTracker side");
        $flow->mech__goodsin__putaway_prep
             ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
             ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
             ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
             ->mech__goodsin__putaway_prep_complete_container({
                prl_specific_question__container_fullness => '.50',
             });

        note("Pretend that we got advice response back from PRL");
        $self->fake_advice_response(
            response     => $PRL_TYPE__BOOLEAN__FALSE,
            container_id => $container_id,
            reason       => $case->{setup}{advice_failure_reason},
        );

        note("Open put away problem resolution page for current container");
        $flow->mech__goodsin__putaway_problem_resolution
            ->mech__goodsin__putaway_problem_resolution_submit({
                container_id => $container_id->as_barcode
            });

        my $data = $flow->mech->as_data->{container};

        note("Check that page shows control for starting new put away preparation");
        ok(
            exists($data->{failure_resolution_putaway_prep}),
            'Page allows to start putaway prep.'
        ) if $case->{expected}{is_start_pp_control};

        my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
            ->container_fault_to_resolution()->{ $case->{expected}{checked_failure} };

        is(
            $data->{failure_description},
            sprintf( $expected_err->{description}, $case->{setup}{advice_failure_reason} ),
            'Failure description is correct'
        );

        is_deeply(
            [sort @{$data->{failure_resolution}}],
            [sort map { $_->{text} } @{ $expected_err->{resolutions} }],
            'Resolution suggestions are correct'
        );

        test_prefix('');
    }
}

=head2 no_advice_response_failure

Pretend that no advice message was sent.

=cut

sub no_advice_response_failure : Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note("Get PGID with one products in it");
    my $pgid = $self->get_test_pgid(1);

    note("Get SKU");
    my ($sku) = @{ $self->{pp}->get_skus_for_group_id($pgid) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note("Complete putaway prep on XTracker side");
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_complete_container({
            prl_specific_question__container_fullness => '.50',
         });

    note("Open put away problem resolution page for current container");
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $container_id->as_barcode
        });

    my $data = $flow->mech->as_data->{container};

    note("Check that page shows control for starting new put away preparation");
    ok(
        exists($data->{failure_resolution_putaway_prep}),
        'Page allows to start putaway prep (for no advice response failure).'
    );

    my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
        ->container_fault_to_resolution()->{ NO_ADVICE_RESPONSE };

    is(
        $data->{failure_description},
        $expected_err->{description},
        'Failure description is correct (for no advice response failure).'
    );

    is_deeply(
        [sort @{$data->{failure_resolution}}],
        [sort map { $_->{text} } @{ $expected_err->{resolutions} }],
        'Resolution suggestions are correct (for no advice response failure).'
    );
}

=head2 attempt_to_open_page_for_unknown_valid_container

Make sure unknown valid container ID is handled correctly.

=cut

sub attempt_to_open_page_for_unknown_valid_container :Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;
    $flow->mech__goodsin__putaway_problem_resolution;

    my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
        ->container_fault_to_resolution()->{ NO_ADVICE };

    $flow->catch_error(
        $expected_err->{description}
            .
        join ('', map( {$_->{text}} @{$expected_err->{resolutions}})),
        'Make sure corrent error is shown if unknown valid container was scanned',
        mech__goodsin__putaway_problem_resolution_submit => ({container_id => 'T0000000A'})
    );
}

=head2 handle_container_that_is_not_marked_as_putaway_prep_completed

=cut

sub handle_container_that_is_not_marked_as_putaway_prep_completed : Tests {
    my ($self) = @_;

    my $flow = $self->get_flow;

    note("Get PGID with one products in it");
    my $pgid = $self->get_test_pgid(1);

    note("Get SKU");
    my ($sku) = @{ $self->{pp}->get_skus_for_group_id($pgid) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note("Complete putaway prep on XTracker side");
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $pgid)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku);

    note("Open put away problem resolution page for current container");
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $container_id->as_barcode
        });

    my $data = $flow->mech->as_data->{container};

    my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
        ->container_fault_to_resolution()->{ NO_ADVICE_CONTAINER_IN_PROGRESS };

    is(
        $data->{failure_description},
        $expected_err->{description},
        'Failure description is correct (for putaway prep still in progress case).'
    );

    is_deeply(
        [sort @{$data->{failure_resolution}}],
        [sort map { my $text = $_->{text}; $text =~ s/\<.+?\>//g; $text } @{ $expected_err->{resolutions} }],
        'Resolution suggestions are correct (for putaway prep still in progress case).'
    );
}

=head2 check_permissions

=cut

sub check_permissions : Tests {
    my ($self) = @_;


    # get non-standard flow object - login as someone with no permissions for
    # "Putaway Problem Resolution" page
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
        q/FATAL ERROR: You don't have permission to access Putaway Problem Resolution in Goods In.. Unable to continue./,
        'Deny access when attempt to load Resolution page with wrong credentials',
        mech__goodsin__putaway_problem_resolution => ()
    );


    # now get proper handler and try to open Resolution page
    $flow = $self->get_flow;
    $flow->mech__goodsin__putaway_problem_resolution;
}

=head2 new_container_should_be_the_same_type_as_failed_one

=cut

sub new_container_should_be_the_same_type_as_failed_one : Tests {
    my ($self) = @_;

    my ($flow, $container_id) = @{
        $self->_prepare_bad_sku_screen({
            group_type => XTracker::Database::PutawayPrep->name
        })
    }{qw/flow container_id/};

    note("Open put away problem resolution page for current container");
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $container_id->as_barcode
        });

    note("Issue new Rail container");
    my ($rail_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'R0',
    });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_DIFFERENT_CONTAINER_TYPES},
            ucfirst lc $container_id->name
        ),
        'Container type mismatch is caught.',
        mech__goodsin__putaway_problem_resolution_reputaway_submit  => ({
            new_container_id => $rail_id
        })
    );
}

=head2 remove_skus_from_new_container_happy_path__recode

=cut

sub remove_skus_from_new_container_happy_path__recode :Tests {
    my ($self) = @_;

    test_prefix('Recode based case (RGID).');
    $self->_remove_skus_from_new_container_happy_path(XTracker::Database::PutawayPrep::RecodeBased->name);
    test_prefix('');
}

=head2 remove_skus_from_new_container_happy_path__stock_process

=cut

sub remove_skus_from_new_container_happy_path__stock_process :Tests {
    my ($self) = @_;

    test_prefix('Stock process based (PGID).');
    $self->_remove_skus_from_new_container_happy_path(XTracker::Database::PutawayPrep->name);
    test_prefix('');
}

=head2 remove_skus_from_new_container_happy_path__cancelled_group

=cut

sub remove_skus_from_new_container_happy_path__cancelled_group : Tests {
    my ($self) = @_;

    test_prefix('Cancelled group location (CGID).');
    $self->_remove_skus_from_new_container_happy_path(XTracker::Database::PutawayPrep::CancelledGroup->name);
    test_prefix('');
}

=head2 remove_skus_from_new_container_happy_path__migration_group

=cut

sub remove_skus_from_new_container_happy_path__migration_group : Tests {
    my ($self) = @_;

    test_prefix('Migration group location (MGID).');
    $self->_remove_skus_from_new_container_happy_path(
        XTracker::Database::PutawayPrep::MigrationGroup->name
    );
    test_prefix('');
}


# Checks:
#   * scanning into new container
#   * scan SKUs from new container back into faulty one
#
sub _remove_skus_from_new_container_happy_path {
    my ($self, $group_type) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{$self->_prepare_bad_sku_screen({ group_type => $group_type }) }
        {qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Start putaway problem resolution page, scan faulty container');
    note('And initiate re-completion of putaway into new container');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        });

    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{container}{container_content},
        'Content table of faulty container is correct'
    );
    ok(
        !exists($flow->mech->as_data->{re_putaway_prep}{container_content}),
        'There is not content in new putaway prep container'
    );


    note('Scan two SKUs into new container to re putaway them');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{container}{container_content},
        'Scanning SKUs from faulty container into new one does not decriment content in faulty one'
    );
    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'Putaway prep container has two just scanned items'
    );
    is(
        'Remove SKU',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Check that scan mode is "scan into new container"'
    );

    note('Toggle scan mode to scan SKUs back from new container');
    note('(emulate situation when for example operator by mistake placed');
    note('redundant SKU into new container and needs to remove it back to faulty one)');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_toggle_scan_mode();

    is(
        'Cancel',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Check that scan mode after it was toggled'
    );

    note('Scan out SKU from new container');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_submit({
        sku => $sku
    });

    is_deeply(
        [{
            Quantity    => 1,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'Item was removed from new container.'
    );
    is(
        'Cancel',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Scan mode is stil "scan out of new container"'
    );

    $flow->catch_error(
       sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_NEW_CONTAINER_DOES_NOT_HAVE_SKU},
            '0000-000', $new_container_id
        ),
        'Try to scan out some irrelevant SKU',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            sku => '0000-000'
        })
    );


    note('Flip scan mode back to default');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_toggle_scan_mode();

    is(
        'Remove SKU',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Scan mode was flipped back to normal'
    );
}

=head2 check_compatibility_SKU_with_target_container

=cut

sub check_compatibility_SKU_with_target_container :Tests {
    my $self = shift;

    foreach my $case (
        {
            group_type => XTracker::Database::PutawayPrep::MigrationGroup->name,
        },
        {
            group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
        },
        {
            group_type => XTracker::Database::PutawayPrep::RecodeBased->name,
        },
        {
            group_type => XTracker::Database::PutawayPrep->name,
        },
    ) {
        note 'Check case for putaway prep group of type: ' . $case->{group_type};

        my ($flow, $failed_container_id, $sku, $group_id) =
            @{$self->_prepare_bad_sku_screen({ group_type => $case->{group_type} }) }
            {qw/flow container_id sku group_id/};

        my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => 'T0',
        });

        $flow->mech__goodsin__putaway_problem_resolution
            ->mech__goodsin__putaway_problem_resolution_submit({
                container_id => $failed_container_id->as_barcode
            })
            ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
                new_container_id => $new_container_id->as_barcode,
            });


        my $variant_row = $self->schema->resultset('Any::Variant')->find_by_sku($sku);
        $variant_row->product->update({
            storage_type_id => $PRODUCT_STORAGE_TYPE__OVERSIZED,
        });

        my $error_message = sprintf
            XTracker::Stock::GoodsIn::PutawayProblemResolution
                ->error_dictionary->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
            $sku, ".+$new_container_id.+";

        $flow->catch_error(
            qr/$error_message/,
            'Make sure that we do check SKU compatibility with Target container',
            mech__goodsin__putaway_problem_resolution_reputaway_submit => ({ sku => $sku })
        );

        ok(
            !exists($flow->mech->as_data->{re_putaway_prep}{container_content}),
            'System stays at the same screen'
        );

        my ($oversized_container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => 'V0',
        });

        note 'Make sure it allows to scan items from failed container into one for oversized';
        $flow->mech__goodsin__putaway_problem_resolution
            ->mech__goodsin__putaway_problem_resolution_submit({
                container_id => $failed_container_id->as_barcode
            })
            ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
                new_container_id => $oversized_container_id->as_barcode,
            });
    }
}

=head2 check_redirection_message_when_starting_container_in_progress

=cut

sub check_redirection_message_when_starting_container_in_progress :Tests {
    my ($self, $group_type) = @_;

    foreach my $case (
        {
            group_type => XTracker::Database::PutawayPrep->name,
            error      => 'NO_ADVICE_CONTAINER_IN_PROGRESS',
        },
        {
            group_type => XTracker::Database::PutawayPrep::RecodeBased->name,
            error      => 'NO_ADVICE_CONTAINER_IN_PROGRESS',
        },
        {
            group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
            error      => 'NO_ADVICE_CANCELLED_GROUP_CONTAINER_IN_PROGRESS',
        },
        {
            group_type => XTracker::Database::PutawayPrep::MigrationGroup->name,
            error      => 'NO_ADVICE_MIGRATION_GROUP_CONTAINER_IN_PROGRESS',
        },
    ) {
        note 'Processing group type: ' . $case->{group_type};
        my ($flow, $failed_container_id, $sku) =
            @{$self->_prepare_bad_sku_screen({ group_type => $case->{group_type} }) }
            {qw/flow container_id sku group_id/};

        my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
            prefix => 'T0',
        });

        note 'Start moving stock from failed container into new one';
        note '(but do not complete it)';
        $flow->mech__goodsin__putaway_problem_resolution
            ->mech__goodsin__putaway_problem_resolution_submit({
                container_id => $failed_container_id->as_barcode
            })
            ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
                new_container_id => $new_container_id->as_barcode,
            })
            ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
                sku => $sku,
            });

        note 'Try to use new container as a faulty one';
        $flow->mech__goodsin__putaway_problem_resolution
            ->mech__goodsin__putaway_problem_resolution_submit({
                container_id => $new_container_id->as_barcode,
            });

        my $data = $flow->mech->as_data->{container};

        my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
            ->container_fault_to_resolution()->{ $case->{error} };

        note 'Check that system shows correct error text';
        is(
            $data->{failure_description},
            $expected_err->{description},
            'Failure description is correct (for putaway prep still in progress case).'
        );

        is_deeply(
            [sort @{$data->{failure_resolution}}],
            [sort map { my $text = $_->{text}; $text =~ s/\<.+?\>//g; $text } @{ $expected_err->{resolutions} }],
            'Resolution suggestions are correct (for putaway prep still in progress case).'
        );
    }
}

=head2 empty_started_container_and_try_to_use_it_in_putaway_prep

Check following scenario:

  * user got faulty container and try to resolve it by scanning its content into
    new container;
  * after some stock was moved into new container for some reason she/he realises
    that it is not needed (it is less likely but who knows these users);
  * she/he scans out all SKUs from new container back into faulty one and put
    new container back to the pile of other containers;
  * after a while some user (or some other one) tries to use same empty container
    in putaway prep;
  * system should allow to use it and there should not be any error messages.

This scenario checks that if container that is in "putaway prep in progress"
status happens to be empty - we should not keep its record in the database.

=cut

sub empty_started_container_and_try_to_use_it_in_putaway_prep :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Start putaway problem resolution page, scan faulty container');
    note('Initiate re-completion of putaway into new container and scan one SKU into it');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    is_deeply(
        [{
            Quantity    => 1,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'Putaway prep container has one items'
    );
    is(
        'Remove SKU',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Check that scan mode is "scan into new container"'
    );

    note('Toggle scan mode to allow scan out of putaway prep container back to faulty one');
    note('Scan SKU out of new container');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_toggle_scan_mode
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    ok(
        !exists($flow->mech->as_data->{re_putaway_prep}{container_content}),
        'New putaway prep container is empty again'
    );


    note('Try to use just eptied container in putaway prep for instance');
    note('There should be no errors');
    $flow->mech__goodsin__putaway_prep
        ->mech__goodsin__putaway_prep_submit(scan_value => $group_id)
        ->mech__goodsin__putaway_prep_submit(scan_value => $new_container_id->as_barcode);
}

=head2 mark_new_container_as_completed_but_faulty_one_still_have_content__recode

=cut

sub mark_new_container_as_completed_but_faulty_one_still_have_content__recode :Tests {
    my ($self) = @_;

    test_prefix('Recode based case (RGID).');
    $self->_mark_new_container_as_completed_but_faulty_one_still_have_content(
        XTracker::Database::PutawayPrep::RecodeBased->name
    );
    test_prefix('');
}

=head2 mark_new_container_as_completed_but_faulty_one_still_have_content__stock_process

=cut

sub mark_new_container_as_completed_but_faulty_one_still_have_content__stock_process :Tests {
    my ($self) = @_;

    test_prefix('Stock process based (PGID).');
    $self->_mark_new_container_as_completed_but_faulty_one_still_have_content(
        XTracker::Database::PutawayPrep->name
    );
    test_prefix('');
}

=head2 mark_new_container_as_completed_but_faulty_one_still_have_content__cancelled_group

=cut

sub mark_new_container_as_completed_but_faulty_one_still_have_content__cancelled_group :Tests {
    my ($self) = @_;

    test_prefix('Cancelled group based (CGID).');
    $self->_mark_new_container_as_completed_but_faulty_one_still_have_content(
        XTracker::Database::PutawayPrep::CancelledGroup->name
    );
    test_prefix('');
}

=head2 mark_new_container_as_completed_but_faulty_one_still_have_content__migration_group

=cut

sub mark_new_container_as_completed_but_faulty_one_still_have_content__migration_group :Tests {
    my ($self) = @_;

    test_prefix('Migration group based (MGID).');
    $self->_mark_new_container_as_completed_but_faulty_one_still_have_content(
        XTracker::Database::PutawayPrep::MigrationGroup->name
    );
    test_prefix('');
}
sub _mark_new_container_as_completed_but_faulty_one_still_have_content {
    my ($self, $group_type) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => $group_type,
            })
        }
        {qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open faulty container in putaway problem resolution page');
    note('Start new container for re-completion putaway');
    note('Scan sku from faulty into new container');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{container}{container_content},
        'Faulty container still has two items'
    );
    is_deeply(
        [{
            Quantity    => 1,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'One item was scanned into new container to be put away'
    );

    note('All messages being sent further down - are dumped into directory');
    my $amq = Test::XTracker::MessageQueue->new;
    # clean up queue dump directory (just in case)
    $amq->clear_destination();

    note('Mark new container as putaway prep complete');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
        prl_specific_question__container_fullness => '.50',
    });

    $amq->assert_messages({
        filter_header => superhashof({
            type => 'advice',
        }),
        assert_body => superhashof({
            container_fullness => '.50',
        }),
    },'New Advice messages was sent, Container fullness is passed to Advice message');
    $amq->assert_messages({
        filter_header => superhashof({
            type => 'sku_update',
        }),
        assert_count => atleast(1),
    },'SKU update messages were sent');

    $amq->clear_destination();

    is_deeply(
        [{
            Quantity    => 1,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{container}{container_content},
        'Faulty container has two items'
    );
}

=head2 putaway_all_content_from_faulty_container_into_new_one

=cut

sub putaway_all_content_from_faulty_container_into_new_one :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open faulty container in putaway problem resolution page');
    note('Start new container for re-completion putaway');
    note('Scan sku from faulty into new container');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{container}{container_content},
        'Faulty container still has two items'
    );
    is_deeply(
        [{
            Quantity    => 2,
            SKU         => $sku,
            'Group ID'  => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'Both items were scanned into new container to be put away'
    );

    note('Mark new container as putaway prep complete');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
        prl_specific_question__container_fullness => '.50',
    });

    my $faulty_container = $self->schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_incomplete({ container_id => $failed_container_id });

    ok( !$faulty_container, "Faulty container is gone!");
    ok(
        !exists($flow->mech->as_data->{re_putaway_prep}),
        'There is nothing about new container on the page'
    );
    ok(
        !exists($flow->mech->as_data->{container}),
        'There is no nothing about faulty container on the page'
    );
}

=head2 scan_nonsense_as_container_for_putaway_prep

=cut

sub scan_nonsense_as_container_for_putaway_prep :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name
            })
        }{qw/flow container_id sku/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open faulty container on putaway problem resolution page');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        });

    $flow->catch_error(
       sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_INVALID_CONTAINER_FOR_PUTAWAY_PREP},
            'blabla', $failed_container_id
        ),
        'Try to scan non-sense as container ID for putaway prep',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            new_container_id => 'blabla'
        })
    );
}

=head2 scan_nonsense_as_sku

=cut

sub scan_nonsense_as_sku :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open putaway problem resolution page for faulty container');
    note('Start new container for re-completion of putaway prep');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_FAULTY_CONTAINER_DOES_NOT_HAVE_SKU},
            'blabla', $failed_container_id
        ),
        'Try to scan non-sense into new container for putaway prep',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            sku => 'blabla     '
        })
    );
}

=head2 submission_of_empty_string

=cut

sub submission_of_empty_string :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open putaway problem resolution page and scan faulty container');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_NO_NEW_CONTAINER_WAS_SCANNED}
        ),
        'Try to submit empty string as putaway prep container',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            new_container_id => ''
        })
    );

    note('Start putaway prep');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_submit({
        new_container_id => $new_container_id->as_barcode,
    });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_NO_SKU_WAS_SCANNED}
        ),
        'Try to submit empty string as SKU',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            sku => ''
        })
    );

    note('Scan SKU into new container');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_submit({
        sku => $sku
    });

    note('Toggle scan mode to scan SKUs back from new container');
    note(
        '(emulate situation when for example operator by mistake placed '
       .'redundant SKU into new container and needs to remove it back to faulty one)'
    );
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_toggle_scan_mode();

    is(
        'Cancel',
        $flow->mech->as_data->{re_putaway_prep}{toggle_scan_mode_label},
        'Check that scan mode is "scan out of new container"'
    );

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_NO_SKU_WAS_SCANNED}
        ),
        'Try to submit empty string as SKU while removing',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            sku => ''
        })
    );
}

=head2 scan_into_new_container_more_stock_than_in_faulty_container

=cut

sub scan_into_new_container_more_stock_than_in_faulty_container :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open putaway problem resolution page, start new putaway prep container');
    note('And scan three items into new container, though original faulty one has');
    note('only two.');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
            prl_specific_question__container_fullness => '.50',
        });

    note('Confirm that faulty container is resolved');
    $flow->mech__goodsin__putaway_problem_resolution;

    my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
        ->container_fault_to_resolution()->{ NO_ADVICE };
    $flow->catch_error(
        $expected_err->{description}
            .
        join ('', map( {$_->{text}} @{$expected_err->{resolutions}}))
        ,
        'Faulty container was resolved',
        mech__goodsin__putaway_problem_resolution_submit => ({
            container_id => $failed_container_id->as_barcode,
        })
    );
}

=head2 scan_faulty_container_as_one_for_re_putaway

=cut

sub scan_faulty_container_as_one_for_re_putaway :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name
            })
        }{qw/flow container_id/};

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode,
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution
                ->error_dictionary->{ERR_NEW_PP_CONTAINER_IS_SAME_AS_FAULTY},
            $failed_container_id
        ),
        'Try to scan same faulty container as new one for putaway prep',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({
            new_container_id => $failed_container_id->as_barcode,
        })
    );
}

=head2 check_conforming_faulty_container_as_empty

=cut

sub check_conforming_faulty_container_as_empty :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($new_container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note('Open putaway problem resolution page for faulty container');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        });

    ok(
        $flow->mech->as_data->{container}{empty_faulty_container_button},
        'There is a control for marking afulty container as empty'
    );

    note('Start new putaway prep');
    $flow->mech__goodsin__putaway_problem_resolution_reputaway_submit({
        new_container_id => $new_container_id->as_barcode,
    });

    ok(
        (not exists $flow->mech->as_data->{container}{empty_faulty_container_button}),
        'User is not able to mark faulty container as empty while doing putaway prep'
    );

    note('Reopen problem resolution page and scan faulty conatainer');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        });

    note('Confirm that faulty container is empty');
    my $xt_to_prls = Test::XTracker::Artifacts::RAVNI->new("xt_to_prls");
    $flow->mech__goodsin__putaway_problem_resolution_mark_faulty_container_as_empty;

    note "One container_empty to each configured PRL";
    my $prl_count = XT::Domain::PRLs::get_number_of_prls;
    $prl_count and $xt_to_prls->expect_messages({
        messages => [
            map { +{ type => "container_empty" } }
            1 .. $prl_count,
        ],
    });

    my $expected_err = XTracker::Stock::GoodsIn::PutawayProblemResolution
        ->container_fault_to_resolution()->{ NO_ADVICE };
    $flow->catch_error(
        $expected_err->{description}
            .
        join ('', map( {$_->{text}} @{$expected_err->{resolutions}}))
        ,
        'Faulty container was resolved',
        mech__goodsin__putaway_problem_resolution_submit => ({
            container_id => $failed_container_id->as_barcode,
        })
    );
}

=head2 use_absolutely_new_container_for_putaway_prep

=cut

sub use_absolutely_new_container_for_putaway_prep :Tests {
    my ($self) = @_;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep->name,
            })
        }{qw/flow container_id sku group_id/};

    note('Get new container ID which does not exist in database');
    my ($new_container_id) = Test::XT::Data::Container->get_unique_ids({
        prefix => 'T0',
    });

    note('Open putaway problem resolution page with faulty container');
    note('Try to start new putaway prep with absolutely new container');
    note('(which does not have any records in XTracker database)');
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $new_container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        });

    is_deeply(
        [{
            Quantity   => 1,
            SKU        => $sku,
            'Group ID' => $group_id,
        }],
        $flow->mech->as_data->{re_putaway_prep}{container_content},
        'New container started and contains one item'
    );
}


# PRIVATE METHODS

# Prepares faulty container based on advice response. Container has two SKUs in it.
# Parameters:
#   group_type => indicates whether to deal with PGID, Recode, Migration or
#                 Cancelled group;
#                 if omitted - fall back to PGID
# Returns hashef with keys
#   flow        => flow object,
#   container_id=> ID of prepare container,
#   sku         => SKU used to prepare container,
#   group_id    => source PGID/RGID for used SKUs.
#
sub _prepare_bad_sku_screen {
    my ($self, $group_type) = validated_list(\@_,
        group_type => { isa => 'Str' },
    );

    if ($group_type eq XTracker::Database::PutawayPrep::CancelledGroup->name) {
        return $self->_prepare_bad_sku_screen_for_cancelled_group;
    }

    if ($group_type eq XTracker::Database::PutawayPrep::MigrationGroup->name) {
        return $self->_prepare_bad_sku_screen_for_migration_group;
    }

    my $flow = $self->get_flow;

    note("Get Group ID with one products in it");
    my ($group_id, $group_barcode, $pp_helper);

    if ($group_type eq XTracker::Database::PutawayPrep::RecodeBased->name) {
        ($group_id, $group_barcode) = $self->get_test_recode;
        $pp_helper = XTracker::Database::PutawayPrep::RecodeBased->new({ schema => $self->schema });
    } else {
        $group_id = $self->get_test_pgid(1);
        $group_barcode = $group_id;
        $pp_helper = XTracker::Database::PutawayPrep->new({ schema => $self->schema });
    }

    note("Get SKU");
    my ($sku) = @{ $pp_helper->get_skus_for_group_id($group_id) };

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note("Complete putaway prep on XTracker side");
    $flow->mech__goodsin__putaway_prep
         ->mech__goodsin__putaway_prep_submit(scan_value => $group_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $container_id->as_barcode)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_submit(scan_value => $sku)
         ->mech__goodsin__putaway_prep_complete_container({
            prl_specific_question__container_fullness => '.50',
         });

    note("Pretend that we got advice response back from PRL with BAD SKU failure");
    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__FALSE,
        container_id => $container_id,
        reason       => 'SKUs in Advice not recognised',
    );

   return {
        flow         => $flow,
        sku          => $sku,
        container_id => $container_id,
        group_id     => $group_id,
    }
}

sub _prepare_bad_sku_screen_for_cancelled_group {
    my $self = shift;

    my $flow = $self->get_flow;

    note 'Generate SKU that comes from cancelled location';
    my ($sku) = @{ $self->create_stock_in_cancelled_location(1, {sku_multiplicator => 2}) };
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
        })
        ->mech__goodsin__putaway_prep_packing_exception_submit({
            sku => $sku
        });

    my $amq = Test::XTracker::MessageQueue->new;
    note 'Clean up queue dump directory (just in case)';
    $amq->clear_destination();

    my $pp_container = $self->schema->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id});
    my $is_there_prl_specific_questions = defined $pp_container->get_prl_specific_questions;

    note('Mark container as complete');
    my %complete_container_args;
    $complete_container_args{prl_specific_question__container_fullness} = '.50'
        if $is_there_prl_specific_questions;
    $flow->mech__goodsin__putaway_prep_packing_exception_complete_container(
        \%complete_container_args
    );


    note("Pretend that we got advice response back from PRL with BAD SKU failure");
    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__FALSE,
        container_id => $container_id,
        reason       => 'SKUs in Advice not recognised',
    );

   return {
        flow         => $flow,
        sku          => $sku,
        container_id => $container_id,
        group_id     => 'c' . $pp_container->putaway_prep_groups->first->putaway_prep_cancelled_group_id,
    }
}

sub _prepare_bad_sku_screen_for_migration_group {
    my $self = shift;

    note 'Generate SKU that comes from a migrated location';

    # Create a test location...
    my $location_row = $self->schema->resultset('Public::Location')->create({
        location => 'Test location ' . Data::UUID->new->create_hex,
    });
    # ...which requires this flow status in order to be useable.
    $location_row->add_to_location_allowed_statuses({
        status_id => $FLOW_STATUS__IN_TRANSIT_TO_PRL__STOCK_STATUS,
    });

    my $quantity = 2;
    my ($sku) = @{ $self->create_stock_in_location(1, {
        sku_multiplicator => $quantity,
        location          => $location_row,
    }) };
    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Send fake migration stock_adjust method';
    $self->fake_stock_adjust({
        sku                    => $sku,
        total_quantity         => $quantity,
        delta_quantity         => -$quantity,
        reason                 => 'MIGRATION',
        migration_container_id => $container_id->as_barcode,
        migrate_container      => 'Y',
    });

    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__FALSE,
        container_id => $container_id,
        reason       => 'SKUs in Advice not recognised',
    );

    my ($pp_container)
        = $self->schema->resultset('Public::PutawayPrepContainer')
            ->search({ container_id => $container_id});

    return {
        flow         => $self->get_flow,
        sku          => $sku,
        container_id => $container_id,
        group_id     => 'm' . $pp_container->putaway_prep_groups->first->putaway_prep_migration_group_id,
    }
}

=head2 abandon_failed_container_in_the_middle_of_reputaway

Check following scenario:

  - Get failed container with two items of the same SKU in it;
  - Scan failed container on Problem resolution page;
  - Scan one item from faulty container into new one;
  - Abandon problem resolution page without completion of any containers:
    pretend that operator was so hungry that he ran to lunch just at 1:00 pm
  - User returns to Problem resolution page and discover two containers - one
    initial failed one and one that was not finished;
  - User scans first container that happened to be the unfinished one;
  - User scans single item from unfinished container into new container and
    complete new one;
  - User scans initially failed container;
  - System prompts to re-putaway its stock into new container;
  - System thinks that container has two items but in fact it has only one,
    (which is right)
  - User scans single item from failed container into new one and mark new one
    as Completed
  - User marks initially failed container as Empty

=cut

sub abandon_failed_container_in_the_middle_of_reputaway :Tests {
    my $self = shift;

    note 'Prepare failed container based on Cancelled group (with 2 items in it)';
    my ($flow, $failed_container_id, $sku_a, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($container_id_a) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Start failed container on Problem Resolution page';
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id_a->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku_a
        });

    note 'Do not finish started container, lets pretend that lunch time has come!';

    is(
        $sku_a,
        $flow->mech->as_data->{container}{container_content}[0]{SKU},
        'Chech SKU for faulty container'
    );
    is(
        2,
        $flow->mech->as_data->{container}{container_content}[0]{Quantity},
        'Chech SKU for faulty container'
    );


    my ($container_id_b) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'After abandoning Problem resolution page return to it';
    note 'resume started container and put its cvontent into new container';
    note 'and mark new container as completed';

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $container_id_a->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id_b->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku_a
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
            prl_specific_question__container_fullness => '.50',
        });

    my $pp_container_rs = $self->schema
        ->resultset('Public::PutawayPrepContainer');

    my $container_b_row =
        $pp_container_rs->find_incomplete({ container_id => $container_id_b });
    ok($container_b_row->is_in_transit, 'Container with stock from resumed container is in transit');

    my $container_a_row =
        $pp_container_rs->find_incomplete({ container_id => $container_id_a });
    ok(!$container_a_row, 'Resumed container is not here any more');


    my ($container_id_c) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Scan initially failed container and put its content into new container';
    note 'complete new container';

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id_c->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku_a
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
            prl_specific_question__container_fullness => '.50',
        });

    my $container_c_row =
        $pp_container_rs->find_incomplete({ container_id => $container_id_c });
    ok(
        $container_c_row->is_in_transit,
        'Container with rest of stock from initially failed container is in transit'
    );

    note 'mark initially failed container as Empty';

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        });
    is(
        $sku_a,
        $flow->mech->as_data->{container}{container_content}[0]{SKU},
        'Chech SKU for faulty container'
    );
    is(
        1,
        $flow->mech->as_data->{container}{container_content}[0]{Quantity},
        'Chech SKU for faulty container'
    );

    $flow->mech__goodsin__putaway_problem_resolution_mark_faulty_container_as_empty;

    my $failed_container_row =
        $pp_container_rs->find_incomplete({ container_id => $failed_container_id });

    ok(!$failed_container_row, 'Initially failed container is not here any more');
}


=head2 on_problem_resolution_page_resume_container_started_on_pppe

=cut

sub on_problem_resolution_page_resume_container_started_on_pppe :Tests {
    my $self = shift;

    my $flow = $self->get_flow;

    my ($sku) = @{ $self->create_stock_in_cancelled_location(1, {sku_multiplicator => 2}) };
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

    my ($container_id_a) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id_a->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_complete_container({
            prl_specific_question__container_fullness => '.50',
        });

    my $pp_container_rs = $self->schema
        ->resultset('Public::PutawayPrepContainer');

    my $container_row = $pp_container_rs->find_incomplete({ container_id => $container_id });
    ok(!$container_row, 'Failed container is not here any more');

    my $container_a_row = $pp_container_rs->find_incomplete({ container_id => $container_id_a });
    ok($container_a_row->is_in_transit, 'New container went to PRL');
}

=head2 for_failed_container_from_pppe_scan_sku_more_than_its_quantity

=cut

sub for_failed_container_from_pppe_scan_sku_more_than_its_quantity :Tests {
    my $self = shift;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku,
        });

    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayProblemResolution->error_dictionary
                ->{ERR_SKU_IS_NOT_FROM_SOURCE_CONTAINER},
           $sku
        ),
        'System allows to scan as many items as source container has',
        mech__goodsin__putaway_problem_resolution_reputaway_submit => ({sku => $sku})
    );
}

=head2 on_pppe_try_to_resume_container_with_failed_advice

=cut

sub on_pppe_try_to_resume_container_with_failed_advice :Tests {
    my $self = shift;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($container_id_a) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    $flow->mech__goodsin__putaway_prep_packing_exception;
    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException->error_dictionary
                ->{ERR_CONTAINER_IN_USE},
            $failed_container_id
        ),
        'Container with failed advice cannot be resummed on PPPE.',
        mech__goodsin__putaway_prep_packing_exception_submit  => ({
            container_id => $failed_container_id->as_barcode
        })
    );
}

=head2 on_pppe_try_to_scan_container_abandoned_at_putaway_problem_resolution

=cut

sub on_pppe_try_to_scan_container_abandoned_at_putaway_problem_resolution :Tests {
    my $self = shift;

    my ($flow, $failed_container_id, $sku, $group_id) =
        @{
            $self->_prepare_bad_sku_screen({
                group_type => XTracker::Database::PutawayPrep::CancelledGroup->name,
            })
        }{qw/flow container_id sku group_id/};

    my ($container_id) = Test::XT::Data::Container->create_new_containers({
        prefix => 'T0',
    });

    note 'Start failed container on Problem Resolution page';
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $failed_container_id->as_barcode
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            new_container_id => $container_id->as_barcode,
        })
        ->mech__goodsin__putaway_problem_resolution_reputaway_submit({
            sku => $sku,
        });

    note 'Go to Putaway prep for packing exception (PPPE) and try to resume abandoned container';
    $flow->mech__goodsin__putaway_prep_packing_exception;
    $flow->catch_error(
        sprintf(
            XTracker::Stock::GoodsIn::PutawayPrepPackingException->error_dictionary
                ->{ERR_CONTAINER_IN_USE_AT_PROBLEM_RESOLUTION},
            $container_id
        ),
        'Containers abandoned at Problem resolution page should not be awailable for resuming at PPPE',
        mech__goodsin__putaway_prep_packing_exception_submit => ({
            container_id => $container_id->as_barcode
        })
    );
}


=head2 complete_putaway_from_problem_resolution

We used to have stock_process rows left with complete=false even when all
related putaway prep groups were complete, because resolving a container as
empty with the putaway problem resolution page deleted all the inventory from
there but didn't see if that made any stock processes ready to complete.

See DCA-2625 for more details.

=cut

sub complete_putaway_from_problem_resolution : Tests {
    my ($self) = @_;

    my $data_setup = Test::XT::Data::PutawayPrep->new;
    my $pp_container_rs = $self->schema->resultset('Public::PutawayPrepContainer');

    note "Create a stock process and put all items for it into one container";
    my ($stock_process, $product)
        = $data_setup->create_product_and_stock_process(1, {
            group_type => $self->{pp}->name,
        });
    my $group_id = $product->{ $self->{pp}->container_group_field_name };

    note("start a container");
    my $pp_container1 = $data_setup->create_pp_container();
    my $pp_group = $data_setup->create_pp_group({
        group_id   => $group_id,
        group_type => $self->{pp}->name,
    });

    my $sku_count = $stock_process->quantity;
    note("Add $sku_count skus to the container");

    $pp_container_rs->add_sku({
        group_id     => $group_id,
        container_id => $pp_container1->container_id,
        sku          => $product->{sku},
        putaway_prep => $self->{pp},
    }) for 1 .. $sku_count;

    note("finish putaway prep for first container");
    $pp_container_rs->finish({ container_id => $pp_container1->container_id });
    $pp_container1->discard_changes;
    is(
        $pp_container1->status_id,
        $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        'container is in transit',
    );

    note "Start a second container";
    my $pp_container2 = $data_setup->create_pp_container();

    note "Add a surplus item to second container, but don't send advice for it";
    $pp_container_rs->add_sku({
        group_id     => $group_id,
        container_id => $pp_container2->container_id,
        sku          => $product->{sku},
        putaway_prep => $self->{pp},
    });

    map {$_->discard_changes} ($pp_container1, $pp_container2, $pp_group, $stock_process);

    is( $pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_TRANSIT,
        "First container status is In Transit" );
    is( $pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
        "Second container status is In Progress" );
    is( $pp_group->status_id, $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        "PP group status is In Progress" );

    note "Put away first container successfully";
    $self->fake_advice_response(
        response     => $PRL_TYPE__BOOLEAN__TRUE,
        container_id => $pp_container1->container_id,
    );

    ok(!$stock_process->complete, "Stock process not yet marked as complete");

    map {$_->discard_changes} ($pp_container1, $pp_container2, $pp_group, $stock_process);
    is( $pp_container1->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__COMPLETE,
        "First container status now Complete" );
    is( $pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__IN_PROGRESS,
        "Second container status still In Progress" );
    is( $pp_group->status_id, $PUTAWAY_PREP_GROUP_STATUS__IN_PROGRESS,
        "PP group status still In Progress" );

    # Note: We're not sending a failed advice_response here because in the
    # real world examples we found for DCA-2625, it didn't look like the user
    # had got as far as completing the container before resolving it with
    # putaway problem resolution.

    note "Open problem resolution page and scan second container";
    my $flow = $self->get_flow;
    $flow->mech__goodsin__putaway_problem_resolution
        ->mech__goodsin__putaway_problem_resolution_submit({
            container_id => $pp_container2->container_id->as_barcode
        });

    note "Say that second container is empty";
    $flow->mech__goodsin__putaway_problem_resolution_mark_faulty_container_as_empty;

    map {$_->discard_changes} ($pp_container1, $pp_container2, $pp_group, $stock_process);
    is( $pp_container2->status_id, $PUTAWAY_PREP_CONTAINER_STATUS__RESOLVED,
        "Second container status now Resolved" );
    is( $pp_group->status_id, $PUTAWAY_PREP_GROUP_STATUS__COMPLETED,
        "PP group status now Completed" );

    ok($stock_process->complete, "Stock process now marked as complete");

}

