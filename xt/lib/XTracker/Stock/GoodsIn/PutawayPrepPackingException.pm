package XTracker::Stock::GoodsIn::PutawayPrepPackingException;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;
use XTracker::Database::PutawayPrep::CancelledGroup;
use NAP::DC::Barcode::Container;
use NAP::DC::Exception::Barcode;

=head1 NAME

XTracker::Stock::GoodsIn::PutawayPrepPackingException - Handler for "Putaway
prep from Packing exception" page.

=head2 DESCRIPTION

Allows user to perform Putaway prep process for stock that comes from
Packing exception via "Cancleed location".

Consists of following pages:

    * List the content of "Cancelled location". With ability to start new
      container (or resume one in progress) by scanning container barcode.

    * Details of container that is in progress: its content. With options
      to scan new SKUs from "Cancleed location" (or scan out SKUs bact to
      "Cancleed location"), or to complete current conatiner (with
      answering PRL specific questions - if applies)

=cut


my $ERRORS = {
    ERR_UNEXPECTED_ERROR     => q|Got unexpected error: %s|,
    ERR_CONTAINER_INVALID_ID => q|Invalid container ID was scanned: '%s'|,
    ERR_SKU_UNKNOWN          => q|SKU '%s' is unknown|,
    ERR_SKU_INCOMPATIBLE_WITH_CONTAINER =>
        q|Cannot scan SKU '%s'. Reason: %s.|,
    ERR_SKU_INCOMPATIBLE_WITH_CONTAINER_NO_REASON => q|Cannot add SKU '%s' into '%s': they are incompatible.|,
    ERR_SKU_IS_NOT_FROM_CANCELLED_LOCATION =>
        q|Invalid SKU scan. SKU '%s' is not expected for putaway|,
    ERR_CONTAINER_ALREADY_STARTED_AT_NORMAL_PUTAWAY_PREP =>
        q|Cannot resume container: '%s'. Please use 'Normal' Putaway prep|,
    ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION =>
        q|To complete the container, please select the tote fullness level|,
    ERR_SURPLUS_IN_CONTAINER => q|Container has more stock that "Cancelled location" could source|,
    ERR_CONTAINER_IN_USE     => q|Container '%s' is already in progress|,
    ERR_CONTAINER_IN_USE_AT_PROBLEM_RESOLUTION =>
        q|This container '%s' is currently in progress, please resume from Putaway Problem Resolution|,
    ERR_INVALID_CONTAINER    => q|Failed to scan container '%s'. Reason: %s.|,
};

=head1 METHODS

=head2 error_dictionary

Returns hashref with all error messages" Putaway prep Packing Exception" page issues.

=cut

sub error_dictionary { $ERRORS }

=head2 handler

Main entry point for to the handler.

All unknown exceptions are caught at this level.

=cut

sub handler {
    my $handler = XTracker::Handler->new(shift);

    $handler->{data}{section}       = 'Goods In';
    $handler->{data}{subsection}    = 'Putaway Prep Packing Exception';
    $handler->{data}{subsubsection} = '';
    $handler->{data}{content} = 'goods_in/putaway_prep_packing_exception.tt';

    try {
        _handler($handler);
    } catch {
        xt_warn(sprintf $ERRORS->{ERR_UNEXPECTED_ERROR}, $_);
    };

    return $handler->process_template;
}

=head2 _handler

Wrapper on the all logic, so we can catch unexpected exceptions.

=cut

sub _handler {
    my ($handler) = @_;

    # remove leading and ending spaces in all submitted parameters
    s/^\s+|\s+$//g for grep {defined $_} values %{ $handler->{param_of}};

    my $group_id     = $handler->{param_of}{group_id};
    my $remove_sku   = $handler->{param_of}{remove_sku};
    my $toggle_scan_mode   = $handler->{param_of}{toggle_scan_mode};
    my $container_fullness = $handler->{param_of}{prl_specific_question__container_fullness};
    my $mark_container_as_complete = $handler->{param_of}{container_complete};

    # VALIDATION
    my ($container_id, $pp_container_row, $error) = _get_and_validate_pp_container({
        container_id   => $handler->{param_of}{container_id},
        schema         => $handler->schema,
        scan_container => $handler->{param_of}{scan_container},
    });

    # check if there was validation error
    return _display_cancelled_location_content($handler) if $error;

    my ($variant_row, $start_from_beginning);
    ($variant_row, $error, $start_from_beginning) = _get_and_validate_variant({
        schema           => $handler->schema,
        sku              => $handler->{param_of}{sku},
        container_id     => $container_id,
        pp_container_row => $pp_container_row,
    });

    # go to the very first page when validation indicates that restart is needed
    return _display_cancelled_location_content($handler) if $start_from_beginning;

    # check if there was validation error
    return _display_scan_screen({
        handler                => $handler,
        container_id           => $container_id,
        group_id               => $group_id,
        remove_sku             => $remove_sku,
        putaway_prep_container => $pp_container_row

    }) if $error;

    # ACTION

    if ($toggle_scan_mode) {
        $remove_sku = ! $remove_sku;

    } elsif ($pp_container_row && $mark_container_as_complete) {

        if (
            _do_mark_container_as_completed({
                container_fullness     => $container_fullness,
                putaway_prep_container => $pp_container_row,
                schema                 => $handler->schema,
                operator_id            => $handler->operator_id,
            })
        ) {
            return _display_cancelled_location_content($handler);
        }


    } elsif ($pp_container_row && $remove_sku && $variant_row) {
        # remove SKU from container

        # make sure user tries to remove existing SKU, otherwise complain!
        unless ( $pp_container_row->does_contain_sku($variant_row->sku) ) {
            xt_warn(
                sprintf(
                    $ERRORS->{ERR_SKU_UNKNOWN},
                    $variant_row->sku
                )
            );
        } else {
            $pp_container_row->remove_sku($variant_row->sku);
        }

    } elsif ($variant_row) {
        # add new SKU into container

        _do_add_sku_to_container({
            schema       => $handler->schema,
            variant      => $variant_row,
            container_id => $container_id,
            operator_id  => $handler->operator_id,
        });

        # Fetch the putaway prep container DBIC if it is not known yet
        # (if newly added SKU was very first in the container, the pp_container record
        # was created just now, so we need to instantiate $pp_container_row for it)
        $pp_container_row ||= $handler->schema
            ->resultset('Public::PutawayPrepContainer')
            ->find_in_progress({ container_id => $container_id });
    }


    # DISPLAY

    _display_scan_screen({
        handler                => $handler,
        container_id           => $container_id,
        group_id               => $group_id,
        remove_sku             => $remove_sku,
        putaway_prep_container => $pp_container_row

    });
}

=head2 _display_cancelled_location_content($handler)

Update passed handler with data needed for showing content of "Cancelled location"

=cut

sub _display_cancelled_location_content {
    my ($handler, $pp_container_row) = @_;

    my $cancelled_location_row =
         $handler->schema->resultset('Public::Location')
            ->get_cancelled_location;

    my @cancelled_location_content = map {
            my $args = $_;

            map {+{
                designer => (ref($args->[0]->designer)
                            ? $args->[0]->designer->designer
                            : $args->[0]->designer
                            ),
                name     => $args->[0]->name,
                size     => (ref($args->[0]->designer)
                            ? $args->[1]->size->size
                            : $args->[1]->size_id
                            ),
                sku      => $args->[1]->sku,
                product_id   => $args->[0]->id,
                storage_type => $args->[0]->storage_type,
            }} 1..$args->[2]
        }
        map {[$_->variant->product, $_->variant, $_->quantity]}
        $cancelled_location_row->quantities->all;

    # filter out those items that were already scanned
    if ($pp_container_row) {
        my %skus_in_container = map
            {$_->variant_with_voucher->sku => $_->quantity}
            $pp_container_row->putaway_prep_inventories->all;

        @cancelled_location_content = grep
            { ! defined($skus_in_container{ $_->{sku}}) || --$skus_in_container{ $_->{sku} } < 0 }
            @cancelled_location_content;
    }

    $handler->{data}{cancelled_location_content} =
        \@cancelled_location_content;

    return 1;
}

=head2 _do_mark_container_as_completed(:$container_fullness :$putaway_prep_container :$schema :$operator_id): Bool

For passed schema, answer for container fullness question
and putaway prep container DBIC object
performs attempt to complete correspondent putaway prep container.

Returns true in case of success.

=cut

sub _do_mark_container_as_completed {
    my ($args) = @_;

    my ($container_fullness, $pp_container_row, $schema, $operator_id) =
        @$args{qw/container_fullness putaway_prep_container schema operator_id/};

    my $cancelled_location_row =
        $schema->resultset('Public::Location')->get_cancelled_location;

    if ( %{
        $pp_container_row->check_answers_for_prl_specific_questions({
            container_fullness => $container_fullness
        })
        }
    ) {
        xt_warn($ERRORS->{ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION});
    } elsif (
        # check that content from container that is about to be put
        # away could be sourced from "Cancelled" location
        ! $cancelled_location_row->does_include_content_of_pp_container($pp_container_row)
    ) {
        xt_warn( $ERRORS->{ERR_SURPLUS_IN_CONTAINER} );

    } else {

        # mark new container as completed
        my $container_helper =
            $schema->resultset('Public::PutawayPrepContainer');

        $container_helper->finish({
            container_id       => $pp_container_row->container_id,
            container_fullness => $container_fullness,
        });

        # Move stock that was placed into container from "cancelled location"
        my $operator_row = $schema->resultset('Public::Operator')
            ->get_operator($operator_id);

        $pp_container_row->move_stock_from_location_to_prl({
            location => $cancelled_location_row,
            operator => $operator_row,
        });

        return 1;
    }

    return 0;
}

=head2 _do_add_sku_to_container(:$schema sku :$container_id :$operator_id)

Adds passed SKU to the container with passed ID under the name of user
with ID passed as "operator ID".

=cut

sub _do_add_sku_to_container {
    my ($args) = @_;

    my ($schema, $variant_row, $container_id, $operator_id) =
        @$args{qw/ schema variant container_id operator_id/};


    # get correspondent putaway prep container DBIC or create new one

    my $putaway_prep_helper =
        XTracker::Database::PutawayPrep::CancelledGroup->new({schema => $schema});

    my $container_helper = $schema->resultset('Public::PutawayPrepContainer');

    my $pp_container_row = $container_helper
        ->find_in_progress({ container_id => $container_id })
        ||
        $container_helper->start({
            container_id => $container_id,
            user_id      => $operator_id,
        });


    my $group_id = $pp_container_row->putaway_prep_groups->count
        # we assume that all items from current container come from
        # same CGID
        ? $pp_container_row->putaway_prep_groups->first->canonical_group_id
        : $putaway_prep_helper->generate_new_group_id;


    # consider moving this into validation sub?
    my $cancelled_location_row =
        $schema->resultset('Public::Location')->get_cancelled_location;
    unless (
        $cancelled_location_row->does_include_variants([
            $variant_row, @{$pp_container_row->variants}
        ])
    ) {
        xt_warn( sprintf $ERRORS->{ERR_SKU_IS_NOT_FROM_CANCELLED_LOCATION}, $variant_row->sku );
        return;
    }

    try {
        $container_helper->add_sku({
            group_id     => $group_id,
            sku          => $variant_row->sku,
            container_id => $pp_container_row->container_id,
            putaway_prep => $putaway_prep_helper,
        });
    } catch {
        xt_warn(
            sprintf(
                $ERRORS->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
                $variant_row->sku, $_
            )
        );
    };

}

=head2 _get_and_validate_pp_container

Validate parameters related to container and returns Container ID, PutawayPrepContainer
DBIC object and flag that indicates if container is valid to proceed further.

=cut

sub _get_and_validate_pp_container {
    my ($args) = @_;

    my ($container_id, $schema, $scan_container) =
        @$args{qw/ container_id schema scan_container /};

    # it is essential to have container ID
    return (undef, undef, 1) unless $container_id;

    # validate provided container ID
    my $err;
    try {
        $container_id = defined($scan_container)
            ? NAP::DC::Barcode::Container->new_from_barcode($container_id)
            : NAP::DC::Barcode::Container->new_from_id($container_id);
        $err = 0;
    } catch {
        $err = 1;
        if ($_ ~~ match_instance_of('NAP::DC::Exception::Barcode')) {
            xt_warn(sprintf $ERRORS->{ERR_CONTAINER_INVALID_ID}, $container_id);
        }
        else {
            die $_;
        }
    };
    return ($container_id, undef, 1) if $err;

    # check that container ID is suitable in non putaway prep terms
    my $putaway_prep_helper =
        XTracker::Database::PutawayPrep::CancelledGroup->new({schema => $schema});

    try {
        $putaway_prep_helper->check_container_id({container_id => $container_id});
    } catch {
        xt_warn(
            sprintf
                $ERRORS->{ERR_INVALID_CONTAINER},
                $container_id, $_
        );
    };

    # try to obtain pp_container record for provided container_id
    my $pp_container_rs =
        $schema->resultset('Public::PutawayPrepContainer');
    my $pp_container_row =
        $pp_container_rs->find_in_progress({container_id => $container_id});

    # try to determine if provided container ID relates to the pp_container that is in progress
    if (
        !$pp_container_row
        &&
        $pp_container_rs->find_incomplete({container_id => $container_id})
    ){
        xt_warn(sprintf $ERRORS->{ERR_CONTAINER_IN_USE}, $container_id);
        return ($container_id, undef, 1);
    }

    # make sure provided container is not used at "normal" Putaway prep
    # at this moment - here we cannot resume containers started at "normal" PP
    if (
        $pp_container_row
            &&
        ! $pp_container_row->does_contain_only_cancelled_group
    ) {
        xt_warn(
            sprintf
                $ERRORS->{ERR_CONTAINER_ALREADY_STARTED_AT_NORMAL_PUTAWAY_PREP},
                $pp_container_row->container_id
        );
        return ($container_id, $pp_container_row, 1);
    }

    # make sure current container is not one abandoned at Putaway problem resolution
    # page
    if (
        $pp_container_row
           &&
        $pp_container_row->is_abandoned_from_problem_resolution
    ) {
        xt_warn(
            sprintf
                $ERRORS->{ERR_CONTAINER_IN_USE_AT_PROBLEM_RESOLUTION},
                $pp_container_row->container_id
        );
        return ($container_id, $pp_container_row, 1);
    }

    return ($container_id, $pp_container_row, undef);
}

sub _get_and_validate_variant {
    my ($args) = @_;

    my ($schema, $sku, $container_id, $pp_container_row) =
        @$args{qw/ schema sku container_id pp_container_row/};

    my ($error, $variant_row, $start_from_beginning);

    # empty SKU is still valid, we just do not return variant object
    return ($variant_row, $error) unless $sku;

    try {
        $variant_row = $schema->resultset('Any::Variant')->find_by_sku($sku);
    } catch {
        xt_warn(
            sprintf($ERRORS->{ERR_SKU_UNKNOWN}, $sku)
        );
        $error = 1;
    };

    # ignore rest of the validation if there is not variant object for provided SKU
    return ($variant_row, $error) unless $variant_row;

    my $cancelled_location_row =
        $schema->resultset('Public::Location')->get_cancelled_location;

    # Check that scanned SKU comes from "Cancelled location"
    # (at this page all SKUs - those to be scanned into/out container should belong
    # to "cancelled location")
    unless ($cancelled_location_row->does_include_variants([$variant_row])) {
        xt_warn(
            sprintf($ERRORS->{ERR_SKU_UNKNOWN}, $variant_row->sku)
        );
        $error = 1;
    }

    try {
        $schema->resultset('Public::PutawayPrepContainer')
            ->check_container_id_is_compatible_with_storage_type({
                container_id    => $container_id,
                storage_type_id => $variant_row->product->storage_type_id,
            });
    } catch {
        xt_warn(
            sprintf(
                $ERRORS->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER},
                $variant_row->sku, $_
            )
        );

        # indicate "restart" flag only if provided container is empty
        $start_from_beginning = 1
            unless $pp_container_row && $pp_container_row->putaway_prep_inventories->all;

        $error = 1;
    };

    # if putaway prep container is provided and contains some putaway grep groups,
    # ask it whether if current SKU (correspondent variant object) can be put in it
    if (
        $pp_container_row
         && $pp_container_row->putaway_prep_groups->count
         && !$pp_container_row->can_accept_variant({
            variant_row => $variant_row,
            # container's content is from Cancel location, stock status for all SKUs from this
            # location is the same, thus it is enough to get stock status from first item in container
            stock_status_row => $pp_container_row->putaway_prep_groups->first->get_stock_status_row
        })
    ) {
         xt_warn(
            sprintf(
                $ERRORS->{ERR_SKU_INCOMPATIBLE_WITH_CONTAINER_NO_REASON},
                $variant_row->sku, $pp_container_row->container_id->as_barcode
            )
        );
        $error = 1;
    }

    return ($variant_row, $error, $start_from_beginning);
}

sub _display_scan_screen {
    my ($args) = @_;

    my ($handler, $container_id, $group_id, $remove_sku, $pp_container_row) =
        @$args{qw/handler container_id group_id remove_sku putaway_prep_container/};

    if ( $pp_container_row ) {
        my $container_content = $pp_container_row->get_container_content_statistics;

        $handler->{data}{container_content} = $container_content;
        $handler->{data}{prl_questions} =
            $pp_container_row->get_prl_specific_questions;
        $handler->{data}{container_id} = $pp_container_row->container_id;

        # carry on SKU mode only if container is still have content,
        # otherwise it is default: scan stock into container
        $handler->{data}{remove_sku} = $remove_sku if @$container_content;
    }

    $handler->{data}{container_id}  = $container_id;
    $handler->{data}{group_id}      = $group_id;

    _display_cancelled_location_content($handler, $pp_container_row);

    return 1;
}

