package XTracker::Stock::GoodsIn::PutawayProblemResolution;

use NAP::policy "tt";

use List::Util qw/first/;
use List::MoreUtils qw/uniq/;

use XTracker::Error;
use XTracker::Handler;
use NAP::DC::Barcode::Container;
use NAP::DC::Exception::Barcode;
use XTracker::Constants::FromDB qw/:putaway_prep_container_status/;
use XTracker::Schema::Result::Public::PutawayPrepContainer;
use XTracker::Database::PutawayPrep::RecodeBased;
use XTracker::Database::PutawayPrep;

=head1 NAME

XTracker::Stock::GoodsIn::PutawayProblemResolution - Handler for Putawa problem resolution page.

=head2 DESCRIPTION

Process all requests related to putaway problem resolution page.

Page supports following actions:

* Scan faulty container and display possible resolutions available.

* Confirm faulty container as empty: all associated inventory records are removed
and faulty container is marked as resolved.

* For particular faulty container it allows to perform putaway preparation
into new container:

** scan new container where stock from faulty container is going to be transfered

** transfer stock between faulty and new containers

** mark new putaway prep container as completed and ready to be sent to PRL
(PRL specific questions are prompted if necessary)

** if faulty container as a result of stock transfer appears to be empty
it is marked as resolved
=cut

# Dictionary with error messages Putaway problem resolution page issues
#
my $ERRORS = {
    ERR_UNEXPECTED_ERROR                   => q|Got unexpected error: %s|,
    ERR_FAULTY_CONTAINER_DOES_NOT_HAVE_SKU => q|SKU (%s) is not expected for faulty container '%s'|
                                            . q|. Please try again or tell your supervisor|,
    ERR_NEW_CONTAINER_DOES_NOT_HAVE_SKU    => q|SKU (%s) is not expected for container '%s'|
                                            . q|. Please try again or tell your supervisor|,
    ERR_INVALID_CONTAINER_FOR_PUTAWAY_PREP => q|Invalid container ID '%s' was scanned while trying|
                                            . q| to re-complete putaway for faulty container '%s'|,
    ERR_NO_SKU_WAS_SCANNED                 => q|Scanned value is not defined|,
    ERR_NO_NEW_CONTAINER_WAS_SCANNED       => q|Scanned value is not defined|,
    ERR_DIFFERENT_CONTAINER_TYPES          => q|New container should be '%s'|,
    ERR_NEW_PP_CONTAINER_IS_SAME_AS_FAULTY => q|Faulty container '%s' is not permitted for |
                                            . q|putaway preparation, please scan a new container|,
    ERR_FAULTY_CONTAINER_INVALID_ID        => q|Invalid container ID was scanned: '%s'|,
    ERR_NO_PRL_SPECIFIC_ANSWER             => q|Please, answer PRL specific questions|,
    ERR_SKU_RELATES_TO_MULTIPLE_GROUPS     => q|Cannot figure out which group provided SKU (%s)|
                                            . q| belongs to...|,
    ERR_SKU_IS_NOT_FROM_SOURCE_CONTAINER   => q|Invalid SKU scan. SKU '%s' is not expected for putaway|,
    ERR_SKU_INCOMPATIBLE_WITH_CONTAINER    => q|Cannot scan SKU '%s'. Reason: %s. Please refresh the page to restart the process.|,
};

=head1 METHODS

=head2 error_dictionary

Returns hashref with all error messages Putaway problem resolution page issues.

=cut

sub error_dictionary { $ERRORS }

=head2 handler

Main entry point for to Putaway problem resolution handler.

All unknown exceptions are caught at this level.

=cut

sub handler {
    my $handler = XTracker::Handler->new(shift);

    # populate general page meta data at this level, so if any unexpected
    # exceptions are thrown, page has reasonable appearance
    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Putaway Problem Resolution';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content}       = 'goods_in/putaway_problem_resolution.tt';

    try {
        _handler($handler);
    } catch {
        xt_warn(sprintf $ERRORS->{ERR_UNEXPECTED_ERROR}, $_);
    };

    return $handler->process_template;
}

=head2 _handler

Holds all logic related to Putaway problem resolution page.

Main reason why it is separate sub: any unknown exceptions are propagated further up
and are dealt by "handler".

=cut

sub _handler {
    my ($handler) = @_;

    my $container_id = $handler->{param_of}{container_id};

    # if not container ID is provided - lead user to very first page
    return unless $container_id;

    # Validate passed container ID.
    #
    # We distinguish between container ID submitted via web form on Putaway Problem
    # resolution page and one that passed as parameter via redirect (e.g. from
    # Putaway overview page).
    # One that come as a result from form submission is treated as barcode with
    # container ID, so for instance in case of tote with orientation - orientation
    # bits should be presented.
    # In other cases container ID is treated as canonical ID, e.g. in case of totes
    # with orientation it omits orientation bit.
    my $err;
    try {
        $container_id = defined($handler->{param_of}{scan})
            ? NAP::DC::Barcode::Container->new_from_barcode($container_id)
            : NAP::DC::Barcode::Container->new_from_id($container_id);
        $err = 0;
    } catch {
        $err = 1;
        if ($_ ~~ match_instance_of('NAP::DC::Exception::Barcode')) {
            xt_warn(sprintf $ERRORS->{ERR_FAULTY_CONTAINER_INVALID_ID}, $container_id);
        }
        else {
            die $_;
        }
    };
    return if $err;

    # assume that provided container is one in putaway prep progress
    my $pprep_container_row = $handler->schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_incomplete({ container_id => $container_id });

    # if user provided valid but unknown container ID - treat this situation as
    # NO ADVICE error - part when no putaway prep was started
    unless ($pprep_container_row) {
        my $fault = container_fault_to_resolution()->{NO_ADVICE};
        xt_warn($fault->{description});
        xt_warn($_->{text}) foreach @{$fault->{resolutions}};
        return;
    }

    # perform emptying of faulty container if needed
    $pprep_container_row->resolve_container_as_empty({
        user_id => $handler->operator_id,
    }) if $handler->{param_of}{empty_faulty_container};

    # handle putaway prep actions if needed
    my $template_params = _handle_putaway_prep({
        %{$handler->{param_of}},
        schema           => $handler->schema,
        faulty_container => $pprep_container_row,
        operator_id      => $handler->operator_id,
    });
    $handler->{data}{$_} = $template_params->{$_} for keys %$template_params;


    # re-fetch fresh data for faulty container
    $pprep_container_row = $handler->schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_incomplete({ container_id => $container_id });

    if ($pprep_container_row) {

        my $container_fault_code = $pprep_container_row->get_container_fault // '';
        my $container_fault;

        if ( $container_fault_code ne 'UNKNOWN'
            and exists container_fault_to_resolution()->{ $container_fault_code }
        ) {
            # case when provided fault code is known
            $container_fault = container_fault_to_resolution()->{ $container_fault_code };
        } else {
            # code is unknown: show it to and user and prompt correspondent resolution
            $container_fault = container_fault_to_resolution()->{ UNKNOWN };
            $container_fault->{description} =
                sprintf( $container_fault->{description}, $pprep_container_row->failure_reason // '' );
        }

        # we have issues for this container - lets fetch all possible info!
        $handler->{data}{container}           = $pprep_container_row;
        $handler->{data}{container_content}   = $pprep_container_row->get_container_content_statistics;
        $handler->{data}{groups}              = $pprep_container_row->get_statistics_for_related_groups;
        $handler->{data}{advice_response_date}= $pprep_container_row->get_advice_response_date;
        $handler->{data}{container_fault}     = $container_fault;
    }
}

=head2 _handle_putaway_prep(hashref_with_parameters): hashref_with_template_params

Performs all actions related to putaway preparation done on putaway problem resolution page.
Prepare all necessary data for templates.

B<Parameters>

=item schema

DBIC schema object.

=item faulty_container

DBIC object of putawa prep container representing container that is been resolved.

=item operator_id

Reference number of user that currently performs an action.

=item new_container_id

ID of the container where stock from faulty container is transfered.

=item container_complete

Flag that indicates if current request relates to marking new container as putaway
preparation complete.

=item remove_sku

Flag that indicates if current request relates to removing stock from new putaway
preparation container.

=item sku

SKU that is being processed at this request.

=item toggle_scan_mode

Flag that indicates if we changes scanning mode for new putaway preparation container.
There are tow mode: 1) default one - when stock is transfered from faulty container
into new one; 2) when stock is transfered from new container back into faulty one
- it is needed when for instance user by mistake scanned some SKU and want to revert
this action.

=item prl_specific_question__container_fullness

Answer to the PRL specific question about tote fullness.

=item current_scan

String with value that shows what kind of entity was just scanned. Could be "sku"
or "container".

=item pprep_scan

Flag that indicates whether current request was invoked as result of web form
submission (pprep_scan is TRUE) or as a result of redirection.

B<Returns>

Hashref with data that is needed to be passed into template. That is result structure
should me merged into data structure with template parameters.

=cut

sub _handle_putaway_prep {
    my ($args) = @_;

    my %template_params;

    my (
        $new_container_id, $mark_new_container_as_complete, $remove_sku, $sku, $toggle_scan_mode,
        $faulty_container, $schema, $operator_id, $container_fullness, $current_scan, $scan_submit
    ) = @$args{qw/
        new_container_id container_complete remove_sku sku toggle_scan_mode
        faulty_container schema operator_id prl_specific_question__container_fullness
        current_scan pprep_scan
    /};

    # trim leading and tailing spaces from values that are passed as text
    s/^\s+|\s+$// foreach grep {$_} ($sku, $new_container_id);

    # complain if empty string was submitted instead of SKU
    if ( ($current_scan||'') eq 'sku' and $scan_submit and not $sku ) {
        xt_warn($ERRORS->{ERR_NO_SKU_WAS_SCANNED});
    }

    # complain if empty string was submitted instead of new container ID
    if ( ($current_scan||'') eq 'container' and $scan_submit and not $new_container_id ) {
        xt_warn($ERRORS->{ERR_NO_NEW_CONTAINER_WAS_SCANNED});
        return;
    }

    # check ID for new container
    try {
        $new_container_id =
            (($current_scan||'') eq 'container')
            ? NAP::DC::Barcode::Container->new_from_barcode( $new_container_id)
            : $new_container_id
            ? NAP::DC::Barcode::Container->new_from_id( $new_container_id )
            : undef;
    } catch {
        if ($_ ~~ match_instance_of('NAP::DC::Exception::Barcode')) {
            xt_warn(sprintf $ERRORS->{ERR_INVALID_CONTAINER_FOR_PUTAWAY_PREP},
                    $new_container_id, $faulty_container->container_id
                );
            $new_container_id = undef;
        }
        else {
            die $_;
        }
    };

    # if there is ID of new container - it means we are doing re-putaway prep
    if ( $new_container_id
        # check equality of container types only if source container have compatible stock
        && $faulty_container->does_contain_compatible_content
        && $faulty_container->container_id->type ne $new_container_id->type
    ) {

        # new target container has different type compare to failed one - complain
        # and discard new container ID
        xt_warn(
            sprintf $ERRORS->{ERR_DIFFERENT_CONTAINER_TYPES},
            ucfirst lc $faulty_container->container_id->name
        );
        $new_container_id = undef;

    } elsif ( $faulty_container->container_id eq ($new_container_id||'') ) {

        # for some reasons user scanned faulty container as the new container...
        xt_warn(
            sprintf $ERRORS->{ERR_NEW_PP_CONTAINER_IS_SAME_AS_FAULTY},
            $new_container_id
        );
        $new_container_id = undef;

    } elsif ($new_container_id) {

        # ACTIONS

        if ($mark_new_container_as_complete) {
            _do_mark_container_as_complete({
                source_container    => $faulty_container,
                target_container_id => $new_container_id,
                schema              => $schema,
                container_fullness  => $container_fullness,
            });
        } elsif ($remove_sku and $sku) {
            _do_remove_sku_from_new_container({
                sku         => $sku,
                container_id=> $new_container_id,
                schema      => $schema,
            });
        } elsif ($sku) {
            _do_source_sku_from_container_to_container({
                sku                 => $sku,
                source_container    => $faulty_container,
                target_container_id => $new_container_id,
                schema              => $schema,
                operator_id         => $operator_id,
            });
        }

        # DISPLAY

        if (
            my $new_pprep_container_row = $schema
                ->resultset('Public::PutawayPrepContainer')
                ->find_in_progress({ container_id => $new_container_id })
        ) {
            # fetch new container content and pass it to template
            my $new_container_content =
                $new_pprep_container_row->get_container_content_statistics;
            $template_params{new_container_content} = $new_container_content;

            # fetch data for new putaway prep container and pass it to template
            my $group_details = get_putaway_prep_group_details({
                pp_container => $new_pprep_container_row,
                schema       => $schema,
            });
            $template_params{$_} = $group_details->{$_} for keys %$group_details;

            if ($toggle_scan_mode) {
                # case when user just changed the scanning mode for new container:
                # either turned on to scan out of new container or set it back to normal
                $template_params{remove_sku} = $remove_sku ? undef : 1;

            } else {
                # carry "remove_sku" flag to the next page
                $template_params{remove_sku} = $remove_sku;
            }

            # if new container does not have content - it is always "scan in" mode
            $template_params{remove_sku} = undef unless @$new_container_content;

            # show PRL specific questions if they exist
            $template_params{prl_questions} = $new_pprep_container_row->get_prl_specific_questions;

            # get info about SKUs that are present in new container but not in faulty one
            # (this is possible when XTracker thinks there is less stock in faulty
            # container than it is in real world)
            $template_params{surplus_in_new_conatiner} =
                $new_pprep_container_row->get_content_difference($faulty_container);


        } elsif ($mark_new_container_as_complete) {
            # if new container is no longer stays in "putaway prep progress" status
            # and current request was "mark new container as completed" - do not show
            # new container info - it should be sent to PRL
            $new_container_id = undef;
        }
    }

    $template_params{new_container_id} = $new_container_id;

    return \%template_params;
}

=head2 container_fault_to_resolution

Returns configuration hash REF that determines user interface for each known
problems with put away prep container.

Keys for result are all possible strings returned by
L<XTracker::Schema::Result::Public::PutawayPrepContainer/get_container_fault>

Values are hash refs with detailed description of occurred error in "description" key,
and array ref of configs for resolution interface in "resolutions".

Resolution configs consist of: "text" - description of possible steps to resolve current
issue, and optional key "control" which could have following strings as value:
"START_PUTAWAY_PREP".

START_PUTAWAY_PREP means that page will show controls to allow start put away prep
process.

=cut

sub container_fault_to_resolution {
    my $class = shift;

    my $resolution_bad_mix = {
        text    => q|Scan each SKU into its own container to re-complete put away preparation|,
        control => 'START_PUTAWAY_PREP',
    };

    my $resolution_bad_container = {
        text    => q|Scan all SKUs into a new container to re-complete putaway preparation.|
                 . q| Please take the faulty container to your supervisor for investigation and|
                 . q| to close any outstanding advices for this container in the PRL.|,
        control => 'START_PUTAWAY_PREP',
    };

    my $default_resolution = {
        text    => q|Scan each SKU into its own container to re-complete put away preparation|,
        control => 'START_PUTAWAY_PREP',
    };

    return {
        BAD_SKU => {
            description => q|The container has a SKU that is not recognised by the PRL.|,
            resolutions => [$resolution_bad_mix],
        },
        BAD_MIX => {
            description => q|The container has a mix of items that can not be stored together.|,
            resolutions => [$resolution_bad_mix],
        },
        NO_ADVICE => {
            description => q|This container has not started Putaway Preparation.|,
            resolutions => [
                {
                    text => q|Please take the container back to the Goods In mezzanine|
                           .q| for investigation and to complete Putaway Preparation.|,
                }
            ]
        },
        NO_ADVICE_CONTAINER_IN_PROGRESS => {
            description => q|This container has not completed put away preparation and is|
                          .q| still in progress.|,
            resolutions => [
                {
                    text => q|Please resume the container in <a href="/GoodsIn/PutawayPrep">|
                           .q|the put away preparation screen</a> to complete put away preparation.|
                }
            ],
        },
        NO_ADVICE_CANCELLED_GROUP_CONTAINER_IN_PROGRESS => {
            description => q|This container has not completed put away preparation.|,
            resolutions => [
                {
                    text => q|Please move stock from this container into new one|
                           .q|to complete put away preparation.|,
                    control => 'START_PUTAWAY_PREP',
                }
            ],
        },
        NO_ADVICE_MIGRATION_GROUP_CONTAINER_IN_PROGRESS => {
            description => q|This container has not completed migration.|,
            resolutions => [
                {
                    text => q|Please move stock from this container into new one|
                           .q|to complete migration.|,
                    control => 'START_PUTAWAY_PREP',
                }
            ],
        },
        NO_ADVICE_RESPONSE => {
            description => q|The container has not yet had an advice response from the PRL.|,
            resolutions => [
                {
                    text => q|Please take the container to the PRL to attempt putaway.|,
                },
                {
                    text => q|If putaway is not possible, please check with service desk |
                           .q|or your supervisor whether there |
                           .q|are any technical problems which may have caused the delay.|,
                },
                $resolution_bad_container
            ]
        },
        BAD_CONTAINER => {
            description => q|This container cannot be used for put away.|,
            resolutions => [$resolution_bad_container],
        },
        OVERWEIGHT => {
            description => q|This container is overweight.|,
            resolutions => [
                {
                    text    => q|Please re-scan the SKUs into multiple containers to |
                              .q|spread the weight and complete put away preparation.|,
                    control => 'START_PUTAWAY_PREP'
                }
            ]
        },
        UNKNOWN => {
            description => q|Got a problem: "%s".|,
            resolutions => [$default_resolution],
        },

    };
}

=head2 _do_mark_container_as_complete

Performs completion of new putaway prep container:

    Checks if user has answered to PRL specific questions.

    Marks new container as completed.

    Update faulty container with changes in its content and mark as resolved one
    if it becomes empty.

=cut

sub _do_mark_container_as_complete {
    my ($args) = @_;

    my ($source_container, $target_container_id, $schema, $container_fullness) =
        @$args{qw/source_container target_container_id schema container_fullness/};


    # validate container fullness question if needed
    my $target_container = $schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_in_progress({ container_id => $target_container_id });

    # abort if user answered to PRL specific questions incorrectly
    return xt_warn($ERRORS->{ERR_NO_PRL_SPECIFIC_ANSWER})
        if %{$target_container->check_answers_for_prl_specific_questions({
            container_fullness => $container_fullness
        })};

    # mark new container as completed
    my $container_helper = $schema->resultset('Public::PutawayPrepContainer');
    $container_helper->finish({
        container_id       => $target_container_id,
        container_fullness => $container_fullness,
    });


    # get info about SKUs which number in new container is greater then in faulty,
    # e.g. in reality it appeared that faulty container had more stock then
    # XTracker was aware of.
    my $surplus = $target_container->get_content_difference($source_container);

    # loop through container that was just finished and subtract its content
    # from faulty container (with correction based on surplus)
    foreach my $inventory ($target_container->putaway_prep_inventories->all){
        my $sku = $inventory->variant_with_voucher->sku;

        $source_container->remove_sku($sku)
            foreach 1 .. $inventory->quantity - ($surplus->{$sku} || 0);
    }

    # if nothing left in original faulty container mark it as resolved one
    $source_container->resolve unless $source_container->putaway_prep_inventories->count;

    # make sure that stock adjust messages relate to source container
    # are transfered to new container
    $target_container->copy_stock_adjust_log_from($source_container);
}

=head2 _do_remove_sku_from_new_container

Removes SKU from container ID.

B<Parameters

    sku          : SKU to be removed,
    container_id : ID of container where SKU is going to be removed,
    schema       : DBIC schema object

=cut

sub _do_remove_sku_from_new_container {
    my ($args) = @_;

    my ($sku, $container_id, $schema) = @$args{qw/sku container_id schema/};

    my $new_pprep_container_row = $schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_in_progress({ container_id => $container_id });

    # make sure user tries to remove existing SKU, otherwise complain!
    unless (
        first {$sku eq $_->variant_with_voucher->sku}
        $new_pprep_container_row->putaway_prep_inventories->all
    ) {
        xt_warn(
            sprintf(
                $ERRORS->{ERR_NEW_CONTAINER_DOES_NOT_HAVE_SKU},
                $sku, $new_pprep_container_row->container_id
            )
        );
        return;
    }

    $new_pprep_container_row->remove_sku($sku);
}

=head2 _do_source_sku_from_container_to_container

Transfers passed SKU between containers:

    Check that provided SKU belongs to the source container.

    Check that source container has stock originated from same PGID/RGID.

    Update new container so now it contains passed SKU in it.

Note: Source container is updated after new container is marked as "Completed".

=cut

sub _do_source_sku_from_container_to_container {
    my ($args) = @_;

    my ($sku, $source_container, $target_container_id, $schema, $operator_id)
        = @$args{qw/sku source_container target_container_id schema operator_id/};
    my $container_helper = $schema->resultset('Public::PutawayPrepContainer');

    # get list of inventory records from source container that have the same SKU
    # as passed one
    my @pp_inventory_with_same_sku =
        map {$_->[1]}
        grep {$_->[0] eq $sku}
        map {[$_->variant_with_voucher->sku, $_]}
        $source_container->putaway_prep_inventories->all;

    # check that there are such SKUs, otherwise we cannot do any transfer
    # because provided SKU cannot be found in source container - abort current action
    unless (@pp_inventory_with_same_sku) {
        xt_warn(
            sprintf(
                $ERRORS->{ERR_FAULTY_CONTAINER_DOES_NOT_HAVE_SKU},
                $sku, $source_container->container_id
            )
        );
        return;
    }

    # although it should not happen in real life but just in case lets check that
    # all stock in source container originated from same PGID/RGID
    if (1 != uniq map {$_->putaway_prep_group->canonical_group_id} @pp_inventory_with_same_sku){
        # this should never happen!
        xt_warn(sprintf $ERRORS->{ERR_SKU_RELATES_TO_MULTIPLE_GROUPS}, $sku);
        return;
    }

    # get the PGID/RGID and instantiate correspondent XTracker::Database::PutawayPrep
    # helper object (needed for adding stock into new container)
    my $pp_group_row = $pp_inventory_with_same_sku[0]->putaway_prep_group;
    my $canonical_group_id = $pp_group_row->canonical_group_id;
    my $group_id = $canonical_group_id; $group_id =~ s/^.//;

    my $variant_row = $schema->resultset('Any::Variant')->find_by_sku($sku);

    # check that SKU is compatible with target container
    my $err;
    try {
        $schema->resultset('Public::PutawayPrepContainer')
            ->check_container_id_is_compatible_with_storage_type({
                container_id    => $target_container_id,
                storage_type_id => $variant_row->product->storage_type_id,
            });
        $err = 0;
    } catch {
        $err = 1;
        xt_warn(
            sprintf(
                $ERRORS->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
                $variant_row->sku, $_
            )
        );
    };
    return if $err;

    # initiate and instantiate putaway prep container DBIC for new container ID
    my $new_pprep_container_row = $schema
        ->resultset('Public::PutawayPrepContainer')
        ->find_in_progress({ container_id => $target_container_id })
        ||
        $container_helper->start({
            container_id => $target_container_id,
            user_id      => $operator_id,
        });

    my $putaway_prep = $pp_group_row->is_stock_recode
        ? XTracker::Database::PutawayPrep::RecodeBased->new
        : $pp_group_row->is_cancelled_group
        ? XTracker::Database::PutawayPrep::CancelledGroup->new
        : $pp_group_row->is_migration_group
        ? XTracker::Database::PutawayPrep::MigrationGroup->new
        : XTracker::Database::PutawayPrep->new;

    # In case we are doing with containers sourced from Cancelled group - restrict
    # SKUs to be scanned only from initially failed container
    if ($putaway_prep->name eq XTracker::Database::PutawayPrep::CancelledGroup->name) {
        my $variant_row = $schema->resultset('Any::Variant')->find_by_sku($sku);
        if (
            $source_container->how_many_items_of({ variant_row => $variant_row })
            <
            1 + $new_pprep_container_row->how_many_items_of({ variant_row => $variant_row })
        ) {
            xt_warn(sprintf $ERRORS->{ERR_SKU_IS_NOT_FROM_SOURCE_CONTAINER}, $sku);
            return;
        }
    }

    try {
        # finally add passed SKU into new container
        $container_helper->add_sku({
            group_id     => $group_id,
            sku          => $sku,
            container_id => $new_pprep_container_row->container_id,
            putaway_prep => $putaway_prep,
        });
    } catch {
        xt_warn(
            sprintf(
                $ERRORS->{ERR_UNEXPECTED_ERROR}, $_
            )
        );
    };
}

=head2 get_putaway_prep_group_details($pp_container, $schema) : hashref

For putaway prep container DBIC object returns information about PGID/RGID related
to the latest SKU that was scanned into container.

Information is in form of hashref that is ready to be merged into template parameters.
And template in its turn should include C<page_elements/display_product.tt>
sub-template.

B<Parameters>

    pp_container : DBIC instance of putaway prep container

    schema : DBIC schema object

=cut

sub get_putaway_prep_group_details {
    my ($args) = @_;

    # unpack and validate parameters
    my ($pp_container, $schema) = @$args{qw/pp_container schema/};
    confess 'No Putaway prep container object was provided' unless $pp_container;
    confess 'No Schema object was provided' unless $schema;

    my %result;

    # if new container already has any content, use the newest SKU from it to get
    # PGID/RGID details
    my $newest_inventory = $pp_container->putaway_prep_inventories->first
        or return \%result;

    $result{putaway_prep_group_id} = $newest_inventory->putaway_prep_group->canonical_group_id;

    # Cancelled group does not have details that we can show on problem resolution page
    return \%result if $newest_inventory->putaway_prep_group->is_cancelled_group;

    # Migration group also doesn't have any useful details
    return \%result
        if $newest_inventory->putaway_prep_group->is_migration_group;

    my $group_details = $newest_inventory->putaway_prep_group->is_stock_recode
        ? XTracker::Stock::GoodsIn::PutawayPrep::get_recode_details({
            group_id => $newest_inventory->putaway_prep_group->recode_id,
            schema   => $schema,
          })
        : XTracker::Stock::GoodsIn::PutawayPrep::get_pgid_details({
            group_id => $newest_inventory->putaway_prep_group->group_id,
            schema   => $schema,
          });
    $result{$_} = $group_details->{$_} for keys %$group_details;

    return \%result;
}
