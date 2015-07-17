package XTracker::Stock::GoodsIn::PutawayPrep;

use strict;
use warnings;

use Carp qw/confess/;
use List::MoreUtils qw/pairwise/;
use List::Util qw/first/;
use Plack::App::FakeApache1::Constants qw(:common);

use XTracker::Constants qw($PG_MAX_INT);
use XTracker::Constants::FromDB qw(
    :putaway_prep_group_status
    :putaway_type
);
use XTracker::Error; # xt_warn
use XTracker::Handler;
use XTracker::Database::Product qw(
    get_product_summary
    get_product_id
    get_variant_by_sku
);
use XTracker::Database::StockProcess qw(
    get_quarantine_process_group
    get_customer_return_process_group
    get_samples_return_process_group
    get_sample_process_group
);
use XTracker::Database::StockProcess qw( get_putaway_type );
use XTracker::Database::PutawayPrep;
use XTracker::Database::PutawayPrep::RecodeBased;
use NAP::DC::Barcode::Container;


use Try::Tiny;
use Smart::Match instance_of => { -as => 'match_instance_of' };
use Class::Struct;
use NAP::XT::Exception;

=head1 NAME

XTracker::Stock::GoodsIn::PutawayPrep - Handler for processing PutawayPrep pages.

=head1 DESCRIPTION

Logic for PutawayPrep process pages.

In short PutawayPrep process looks like this:

1. User scans PGID/RGID to init new PutawayPrep process. It is assumed that scanned
PGID/RGID is a source of products for putaway.

2. User scans container to indicate where products are going to be placed.

3. User takes SKU from active PGID/RGID and scan it and place into active
container.

4. User repeats previous step until container is completed, so it is marked as "Complete".
Or in case if active PGID/RGID run out of products, scan new PGID/RGID, so active
group ID is switched to new one, and then repeat previous step.

Also earlier started container could be resumed by simply scanning container ID on the
very first page of PutawayPrep page. Then active PGID/RGID should be specified and then
user goes to step 3.

Putaway Prep process supports removing scanned SKUs from container (relates to point 3)
by switching scanning mode from default one - scan SKUs from PGID/RGID to container - to
reverse one - remove SKUs from container to PGID/RGID. When scanning mode is in "reverse",
all scanned SKUs are going to be removed from container to PGID/RGID.

PGID stands for "Process group ID" (stored in stock_process table), RGID stands
for "Recode group ID" (stored in stock_recode table).

For more details of business logic please have a look at comments in B<handler> subroutine.

=head1 METHODS

=cut

# list of parameters that could be submitted via form
our $PAGE_PARAMETERS = [
    qw/  group_id
         scan_field
         scan
         scan_value
         container_complete
         toggle_scan_mode
         remove_sku
         recode
         prl_specific_question__container_fullness
    /
];

# Data structure that represents PutawayPrep page parameters.
#
struct 'XTracker::Stock::GoodsIn::PutawayPrep::Parameters' => [
    prompts           => '@',
    putaway_prep      => '$',
    container_helper  => '$',
    container_content => '$',
    container_id      => 'NAP::DC::Barcode::Container',
    user_id           => '$',
    prl_questions     => '$',
    map {$_ => '$'} @$PAGE_PARAMETERS,
];

# Error messages dictionary, it specify correspondence between error codes and actual values
#
my $ERRORS = {
    ERR_PGID_SCAN_GENERAL_FAILURE       => 'Failed to scan PGID/Container.' ,
    ERR_RECODE_ID_SCAN_GENERAL_FAILURE  => 'Failed to scan Recode group ID/Container.' ,
    ERR_CONTAINER_SCAN_GENERAL_FAILURE  => 'Failed to scan container',
    ERR_SKU_SCAN_GENERAL_FAILURE        => 'Failed to scan SKU',
    ERR_MARK_AS_COMPLETE_FAILURE        => 'Failed to mark container as Completed',
    ERR_START_PGID_NO_PGID              => 'Undefined Process group ID',
    ERR_START_RECODE_ID_NO_RECODE_ID    => 'Undefined Recode group ID',
    ERR_START_PGID_BAD_CONTAINER_TYPE   => q!PGID '%s'. cannot be placed in container %s. Reason: %s.!,
    ERR_START_RECODE_ID_BAD_CONTAINER_TYPE => q!Recode group ID '%s' cannot be placed in container %s. Reason: %s.!,
    ERR_START_PGID_GENERAL_FAILURE      => q!Failed to scan PGID/Recode group ID '%s'. Reason: %s.!,
    ERR_START_RECODE_ID_GENERAL_FAILURE => q!Failed to scan PGID/Recode group ID '%s'. Reason: %s.!,
    ERR_RESUME_CONTAINER_FAILURE        => 'Unknown/Empty container scanned (%s). '
                                           .'Please tell your supervisor.',
    ERR_RESUME_CONTAINER_USE_PPPE       => q|Cannot resume container: '%s'. Please use 'Putaway prep for Packing Exception'|,
    ERR_FINISH_CONTAINER_RESUMING       => q!Failed to scan PGID/Recode group ID '%s'. Reason: %s.!,
    ERR_START_CONTAINER_FAILURE         => q!Failed to scan container '%s'. Reason: %s.!,
    ERR_START_CONTAINER_INVALID         => q!Failed to scan container '%s'. Invalid barcode.!,
    ERR_SKU_NOT_FROM_PGID               => 'SKU (%s) is not expected for this PGID (%s). '
                                          .'Please try again or tell your supervisor.',
    ERR_SKU_NOT_FROM_RECODE_ID          => 'SKU (%s) is not expected for this Recode group ID (%s). '
                                          .'Please try again or tell your supervisor.',
    ERR_ADD_SKU_TO_CONTAINER_GENERAL    =>  q!Failed to scan '%s'. Reason: %s.!,
    ERR_SCANNED_VALUE_NOT_PGID          => 'Scanned value is not PGID. ',
    ERR_SCANNED_VALUE_NOT_RECODE_ID     => 'Scanned value is not Recode group ID. ',
    ERR_SCANNED_VALUE_NOT_SKU           => 'Scanned value is not SKU. ',
    ERR_SCANNED_VALUE_UNDEFINED         => 'Scanned value is not defined. ',
    ERR_MARK_AS_COMPLETE_FAILURE_REASON => 'Did not mark container %s as Completed. Reason: %s',
    ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION => 'To complete the container, please select the tote fullness level.',
    ERR_NO_DETAILS_FOR_PGID             => 'Failed to retrieve details for PGID: %s. '
                                           .'This looks suspicious, please investigate.',
    ERR_NO_DETAILS_FOR_RECODE_ID        => 'Failed to retrieve details for Recode group ID: %s. '
                                           .'This looks suspicious, please investigate.',
    ERR_REMOVE_SKU_FROM_CONTAINER       => 'Failed to remove SKU %s from container %s.',
    ERR_SKU_UNKNOWN                     => 'SKU %s is unknown. Please try again or tell your supervisor.',
    # use next key to indicate failure which does not have description
    ERR_EMPTY                           => '',
};

=head2 error_dictionary

B<Description>

Returns data structure with error dictionary. It is needed for tests, so we can use error message keys in tests,
rather than hard-coded  messages values.

=cut

sub error_dictionary { $ERRORS }

# User prompts dictionary: sets correspondence between user prompt codes and their values.
#
my $PROMPTS = {
    PRM_INITIAL_PROMPT                  => 'To start putaway preparation, please scan PGID, '
                                            . 'Recode group ID or Container ID.',
    PRM_PGID_PAGE_GENERAL               => 'Scan %s.',
    PRM_RECODE_ID_PAGE_GENERAL          => 'Scan %s.',
    PRM_CONTAINER_SCREEN                => 'Scan next SKU into container, PGID or Recode group ID.',
    PRM_CONTAINER_SCREEN_REMOVE_SKU     => 'Scan SKU that should be removed from container.',
    PRM_RESUME_CONTAINER_ASK_FOR_GROUP  => 'Container resumed - to resume putaway preparation '
                                            . 'please scan a PGID/Recode group ID or complete '
                                            . 'the container.',
    PRM_START_ANOTHER_PGID_FOR_CONTAINER=> 'New PGID started: %s.',
    PRM_START_ANOTHER_RECODE_ID_FOR_CONTAINER=> 'New Recode group ID was started: %s.',
    PRM_CONFIRM_SKU_REMOVAL             => 'SKU %s was removed.',
};

=head2 error_dictionary

B<Description>

Returns dictionaries with user prompts.

=cut

sub prompt_dictionary { $PROMPTS }

=head2 handler

B<Description>

Main entry point to handler.

=cut

sub handler {
    my @in=@_;
    try {
        _handler(@in);
    }
    catch {
        xt_die("Got unexpected error: $_");
    };

    return OK;
}

# Private method that encapsulates all business logic for PutawayPrep process.
#
sub _handler {
    my $handler = XTracker::Handler->new(shift);

    # perform common actions
    my $page_data = get_page_parameters($handler);

    # list of errors that are happened so far
    my @errors;

    my $failures;

    # handle scanning PGID/RGID
    if (is_it_scan_group_id($page_data)) {

        # perform checks to determine to what exactly scanned value relates to:
        #
        #  * Assume that this is first step of PutawayPrep when nothing is known,
        #    so scanned value is PGID/RGID
        if ( not ($failures = try_to_start_process_group($page_data))
             # if any issues occurred, move them to global errors and move
             # on to next if statement (assumption that this is first step is wrong)
             or ( push(@errors, $failures) and 0)
        ) {

            # in case when all is fine and passed scanned value happened to be PGID/RGID
            # that should be scanned, save scanned value as current group ID (PGID/RGID)
            $page_data->group_id($page_data->scan_value);


            # prepare for next step: "scanning container" and
            # set scan_field to be "container_id" and advise user with appropriate prompt
            $page_data->scan_field('container_id');
            my $container_type_name =
                $page_data->putaway_prep->get_container_type_name_for($page_data->group_id);
            $page_data->prompts([{'PRM_<group>_PAGE_GENERAL'=>[$container_type_name]}]);



        #  * Assume that this is attempt to finish process of resuming already started container
        } elsif (not $failures = try_to_finish_container_resuming($page_data)
            # if any issues occurred, move them to global errors and move
            # on to next if statement (assumption is wrong)
            or ( push(@errors, $failures) and 0)
        ) {

            # in case when we successfully finished resuming started container,
            # save scan value as active PGID/RGID (when finishing resuming container - user
            # scans PGID/RGID from where next SKUs are going tp be placed into container )
            $page_data->group_id($page_data->scan_value);


            # next screen is going to to be page with resumed container, ready to scan
            # in new SKUs or mark it as completed.
            $page_data = prepare_for_container_screen($page_data);


        #  * Assume that this is an attempt to start resuming container
        } elsif (not $failures = try_to_resume_container($page_data)
            # if any issues occurred, move them to global errors and go
            # to next if statement (current assumption is wrong)
            or ( push(@errors, $failures) and 0)
        ) {

            # case when current page relates to start resuming container

            # remove all previous warnings added while trying to recognize scanned value
            # as PGIDi/RGID etc
            @errors = ();

            # save just scanned value as Container ID, so it is accessible on next pages
            $page_data->container_id(
                NAP::DC::Barcode::Container->new_from_barcode($page_data->scan_value)
            );

            # prepare page that holds resumed container and prompts user to enter
            # new PGID/RGID, that will be used to fill resumed container
            push @{$page_data->prompts}, 'PRM_RESUME_CONTAINER_ASK_FOR_GROUP';

            # add container related data to $page_data obkject
            $page_data = _fetch_container_data($page_data);

            # on next screen user is going to scan PGID/RGID
            $page_data->scan_field('group_id');

        # if no action is recognized (no assumptions made above were correct)
        } elsif (
                # and no errors were introduced (very exotic case)
                not @errors
                or
                # or all raised errors are ones not for end user
                0 == grep {ref($_) or $_ ne 'ERR_EMPTY'} @errors
        ) {

            # add default error message with general description.
            push @errors, 'ERR_<group>_SCAN_GENERAL_FAILURE';

            # user stays on initial PutawayPrep page
            $page_data = prepare_start_page($handler, $page_data);
        }


    # handle cases when user scans container ID
    } elsif (is_it_scan_container($page_data)) {

        #  Try to to start container, assuming that PGID/RGID is already picked
        if ( not $failures = try_start_container($page_data)
            or ( push(@errors, $failures) and 0)
            # do not step in if any issues occurred, move them to global errors
        ) {

            # save scanned value as Container ID
            $page_data->container_id(
                NAP::DC::Barcode::Container->new_from_barcode($page_data->scan_value)
            );

            # prompt user to scan SKU/PGID/RGID
            $page_data = prepare_for_container_screen($page_data);

        # if container was not started, report issues and ask for another container Id
        } else {

            # if no warnings were added before, use default one
            push @errors, 'ERR_CONTAINER_SCAN_GENERAL_FAILURE' unless @errors;

            $page_data->scan_field('container_id');
            my $container_type_name = 'any container';
            if ($page_data->group_id) {
                $container_type_name =
                    $page_data->putaway_prep->get_container_type_name_for($page_data->group_id);
            }
            $page_data->prompts([{'PRM_<group>_PAGE_GENERAL'=>[$container_type_name]}]);
        }

    # handle case when there are associated PGID/RGID and container and new SKU/PGID/RGID
    # were scanned
    } elsif (is_it_scan_sku_into_container($page_data)) {

        # case when scanned value is empty
        unless ($page_data->scan_value) {
            push @errors, 'ERR_SCANNED_VALUE_UNDEFINED';

        # if scanned value contains digits separated by a dash - it is a SKU
        } elsif ($page_data->scan_value =~ /\d+\-\d+/) {

            # did we fail to add scanned value as SKU into container
            my $sku_failure = try_add_sku_into_container($page_data);

            if ($sku_failure) {
                # besides SKU error add explanation that scanned value is not PGID/RGID
                push @errors, $sku_failure;
            }

        # otherwise it is PGID/RGID
        } else {

            # treat scanned value as a PGID/RGID
            my $group_id_failure = try_to_start_another_process_group($page_data);

            # if no issues occurred - scanned value was PGID/RGID indeed
            unless ($group_id_failure) {

                # remember scanned value as PGID/RGID
                $page_data->group_id( $page_data->scan_value );

                # provide user with new prompt message
                push @{$page_data->prompts}, {
                    'PRM_START_ANOTHER_<group>_FOR_CONTAINER'=>[$page_data->group_id]
                };

            } else {
                # besides PGID/RGID error itself add explanation that scanned value
                # was not recognized as SKU
                push @errors, $group_id_failure;
            }
        }

        # user is staying on the same screen in any cases

        # prompt user to continue scanning SKU/PGID/RGID
        $page_data = prepare_for_container_screen($page_data);


    # handle case when current container was marked as Completed
    } elsif (is_it_mark_container_as_complete($page_data)) {

        # try to mark current container as "Completed"
        if ( not $failures = mark_container_as_complete($page_data)
            # do not step in if any issues occurred, save issues to global errors
            or ( push(@errors, $failures) and 0)
        ) {

            # in case if the completed container used to be recode based one,
            # switch OFF the recode mode
            $page_data->recode(undef);

            # user is going to be shown the very first page of "Putaway prep" process,
            # so:
            #   * no need to remember about current container any more -
            #     it is completed and sent to PRL
            #   * after container is completed - PGID/RGID is going to be re-initiated
            $page_data = prepare_start_page($handler, $page_data);

        # complain if no actions were recognized
        } else {
            # and in case of failure stay on the same screen, but report to user
            # (use default error message if it was not provided)
            push @errors, 'ERR_MARK_AS_COMPLETE_FAILURE' unless @errors;

            $page_data = prepare_for_container_screen($page_data);

        }

    # case when user wants to delete particular SKU from active container
    } elsif( is_it_remove_sku_from_container($page_data)) {

        # check if submitted SKU belongs to currently processed Product group
        # so system allows removal only SKUs that belong to currently active PGID
        try {
            $page_data->putaway_prep->does_sku_belong_to_group_id({
                group_id => $page_data->group_id,
                sku  => $page_data->scan_value,
            });
        } catch {
            use experimental 'smartmatch';
            if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
                push @errors, {
                    'ERR_SKU_NOT_FROM_<group>' => [$page_data->scan_value, $page_data->group_id]
                };
            }
            else {
                die $_;
            }
        };

        # remove scanned SKU from container
        unless (@errors) {
            try {
                my $pp_container = $page_data->container_helper
                    ->find_in_progress({ container_id => $page_data->container_id });

                $pp_container->remove_sku($page_data->scan_value);
            } catch {
                use experimental 'smartmatch';
                if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
                    push @errors, {
                        ERR_REMOVE_SKU_FROM_CONTAINER =>[$page_data->scan_value, $page_data->container_id]
                    };
                }
                else {
                    die $_;
                };
            };
        }

        # update user's prompt with information about removed SKU
        unless (@errors) {
            push @{$page_data->prompts}, {PRM_CONFIRM_SKU_REMOVAL => [$page_data->scan_value]};
        }

        $page_data = prepare_for_container_screen($page_data);

    # handle case when user switches scan mode at container screen:
    # so SKUs could be scan IN or OUT of container
    } elsif ($page_data->toggle_scan_mode ) {

        # update $page_data instance with container related data
        $page_data = _fetch_container_data($page_data);

        # case when we are switching from default scanning mode
        if ($page_data->scan_field eq 'sku') {

           # tell user what to do next
           push @{$page_data->prompts}, 'PRM_CONTAINER_SCREEN_REMOVE_SKU';

           $page_data->scan_field('remove_sku');

        # case when we switching back to scan SKUs to container
        } else {

            # tell user what to do next
            push @{$page_data->prompts}, 'PRM_CONTAINER_SCREEN';

            $page_data->scan_field('sku');
        }

    # if current action was not recognized, show first page of PutawayPrep page
    } else {

        push @{$page_data->prompts}, 'PRM_INITIAL_PROMPT';
        $handler->add_to_data( get_pgid_lists( $handler->schema ) );
        $page_data->scan_field('group_id');
    }


    # if current page has PGID/RGID - fetch its details
    if ($page_data->group_id) {
        my $group_id_details = $page_data->recode
            ? get_recode_details({
                group_id => $page_data->putaway_prep->extract_group_number($page_data->group_id),
                schema   => $handler->schema,
              })
            : get_pgid_details({
                group_id => $page_data->putaway_prep->extract_group_number($page_data->group_id),
                schema   => $handler->schema,
              });

        if (keys %$group_id_details) {
            $handler->{data}{$_} = $group_id_details->{$_} for keys %$group_id_details;
        } else {
            push @errors, {'ERR_NO_DETAILS_FOR_<group>' => [$page_data->group_id,]};
        }
    }


    # transform page data back to "handler"
    $handler->{data}{$_} = $page_data->$_
        for @$PAGE_PARAMETERS, qw/container_content container_id prl_questions/;

    my $current_group_name = $page_data->putaway_prep->name;

    # transform warnings
    xt_warn($_)
        for map {sprintf $ERRORS->{shift @$_}, map {chomp; $_} @$_}
        map { $_->[0] =~ s/<group>/$current_group_name/g; $_ }
        grep {$_->[0] !~ /^ERR_EMPTY$/}
        map {ref($_) ? [keys(%$_), @{(values(%$_))[0]}] : [$_]}
        @errors;

    # transform prompts
    xt_info($_)
        for map {sprintf $PROMPTS->{shift @$_}, @$_}
        map { $_->[0] =~ s/<group>/$current_group_name/g; $_ }
        map {ref($_)?[keys(%$_), @{(values(%$_))[0]}]:[$_]}
        @{$page_data->prompts};


    # perform common actions required before building page
    render_page($handler);
}

=head2 get_page_parameters

B<Description>

Extract submitted page parameters based on passed L<XTracker::Handler>.

B<Parameters>

C<$handler>: object of L<XTracker::Handler>.

B<Returns>

Struct object that has page parameters as its attributes.

=cut

sub get_page_parameters {
    my ($handler) = @_;

    # trim all submitted values
    s/^\s+|\s+$// foreach values %{$handler->{param_of}};

    my $putaway_prep = $handler->{param_of}->{recode}
        ? XTracker::Database::PutawayPrep::RecodeBased->new({schema => $handler->schema})
        : XTracker::Database::PutawayPrep->new({schema => $handler->schema});

    my %raw_page_parameters = %{$handler->{param_of}};

    # make sure that we use object of scanned barcode rather then raw string
    $raw_page_parameters{container_id} = NAP::DC::Barcode::Container
        ->new_from_id($raw_page_parameters{container_id})
            if $raw_page_parameters{container_id};

    # return page passed page parameters
    my $page_param = XTracker::Stock::GoodsIn::PutawayPrep::Parameters->new(
        %raw_page_parameters,
        container_helper => $handler->schema->resultset('Public::PutawayPrepContainer'),
        putaway_prep     => $putaway_prep,
        user_id          => $handler->operator_id,
    );

    # switch to recode mode in
    if (is_it_scan_group_id($page_param)
        and $page_param->scan_value
        and $page_param->scan_value =~ /^r/i
    ) {
        $page_param->recode(1);

        $page_param->putaway_prep(
            XTracker::Database::PutawayPrep::RecodeBased->new({schema => $handler->schema})
        );
    }


    return $page_param;
}

=head2 get_pgid_details

B<Description>

For passed PGID fetch its details: colour, season, style number, images, etc. and
return them as HASH ref.

After copying keys from result data structure into template parameters
it should be possible to use C<page_elements/display_product.tt> sub-template.

B<Parameters>

=over

=item group_id - Process group ID

=item schema - DBIC schema object

=back

B<Returns>

Data structure as HASH ref with all necessary data for showing Process group details on the page.

=cut

sub get_pgid_details {
    my ($args) = @_;

    my ($group_id, $schema) = @$args{qw/group_id schema/};
    my %results;

    my $putaway_type = get_putaway_type( $schema->storage->dbh, $group_id )->{putaway_type};

    # no PGID provided - no clue what to to retrieve
    return \%results unless $group_id;

    my %process_group_query_type = (
        $PUTAWAY_TYPE__GOODS_IN             => 'process_group',
        $PUTAWAY_TYPE__RETURNS              => 'return_process_group',
        $PUTAWAY_TYPE__STOCK_TRANSFER       => 'return_process_group',
        $PUTAWAY_TYPE__SAMPLE               => 'sample_process_group',
        $PUTAWAY_TYPE__PROCESSED_QUARANTINE => 'quarantine_process_group',
    );
    confess "unknown putaway type '$putaway_type'" unless $process_group_query_type{$putaway_type};
    $results{product_id} = get_product_id(
        $schema->storage->dbh, {id => $group_id, type => $process_group_query_type{$putaway_type} }
    );

    # no product ID for PGID - no clue what to fetch
    return \%results unless $results{product_id};

    my $product_data = get_product_summary( $schema, $results{product_id} );

    # copy all product data into result data structure
    $results{$_} = $product_data->{$_} for keys %$product_data;

    # inform template to show PGID details
    $results{group_details_exist} = 1;

    return \%results;
}

=head2 get_recode_details

B<Description>

For passed RGID fetch its details: colour, season, style number, images, etc. and
return them as HASH ref.

After copying keys from result data structure into template parameters
it should be possible to use C<page_elements/display_product.tt> sub-template.

B<Parameters>

=over

=item recode_id - Recode group ID (RGID)

=item schema - DBIC schema object

=back

B<Returns>

Data structure as HASH ref with all necessary data for showing Recode group details on the page.

=cut

sub get_recode_details {
    my ($args) = @_;

    my ($recode_id, $schema) = @$args{qw/group_id schema/};
    my %results;

    my $product_id = $schema->resultset('Public::StockRecode')
                             ->find($recode_id)
                             ->variant
                             ->product_id;

    my $product_data = get_product_summary($schema, $product_id);

    # copy all product data into result data structure
    $results{$_} = $product_data->{$_} for keys %$product_data;

    # inform template to show recode group details
    $results{group_details_exist} = 1;

    $results{product_id} = $product_id;

    return \%results;
}

=head2 render_page

B<Description>

Make sure that all data necessary for building final page is presented.

=cut

sub render_page {
    my ($handler) = @_;

    # setup navigation bits
    $handler->{data}{section}    = 'Goods In';
    $handler->{data}{subsection} = 'Putaway Prep';


    # set page template and left nav links based on view type
    if ($handler->{data}{handheld}) {
        $handler->{data}{content} = 'goods_in/handheld/putaway_prep.tt';
    }
    else {
        $handler->{data}{content} = 'goods_in/putaway_prep.tt';
    }

    return $handler->process_template;
}

=head2 is_it_scan_group_id

B<Description>

Check if current action is "Submitting PGID/RGID".

=cut

sub is_it_scan_group_id {
    my ($page_params) = @_;

    # make sure that user hits scan button
    return unless $page_params->scan;

    return ($page_params->scan_field||'') eq 'group_id';
}

=head2 try_to_start_process_group

B<Description>

Assume that currently submitted page relates to starting new "putaway prep" process.
This method tries to do it.

B<Return>

UNDEF - If based on passed parameters it is possible to start new "Putaway process"
(and actually it was started).

In case of failures array ref of errors are are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub try_to_start_process_group {
    my ($page_data) = @_;

    my $group_id = $page_data->scan_value;

    # if container ID is presented, this is not initiate Process group screen
    return 'ERR_EMPTY' if $page_data->container_id;

    return 'ERR_START_<group>_NO_<group>' unless $group_id;

    # check if PGID/RGID looks like PGID/RGID and if it does not, return "EMPTY" error,
    # because we do not want to report this to end user
    return 'ERR_EMPTY' unless $page_data->putaway_prep->is_group_id_valid($group_id);

    return try {
        $page_data->putaway_prep->is_group_id_suitable({
            group_id => $group_id,
        });
        # everything is OK
        return;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            return {'ERR_START_<group>_GENERAL_FAILURE' => [$group_id, $_]};
        }
        else {
            die $_;
        }
    };
}

=head2 start_another_process_group

B<Description>

Assuming that there is active container, this method re-associate it with newly submitted
PGID/RGID.

This method require to have PGID/RGID to be in "scan_value".

=cut

sub try_to_start_another_process_group {
    my ($page_data) = @_;

    my $group_id = $page_data->scan_value;
    my $container_id = $page_data->container_id;

    return 'ERR_EMPTY' unless $group_id;


    my ($pp, $is_recode);
    # depending on the group ID formap treat it as Recode based or PGID based one.
    if ($group_id =~ /^r\-?/){
        $pp = XTracker::Database::PutawayPrep::RecodeBased->new({schema => $page_data->putaway_prep->schema});
        $is_recode = 1;
    } else {
        $pp = XTracker::Database::PutawayPrep->new({schema => $page_data->putaway_prep->schema});
        $is_recode = 0;
    }

    # check if provided PGID/RGID is valid one
    my $err;
    try {
        $pp->is_group_id_suitable({
            group_id => $group_id,
            # container should always have been scanned at this point:
            container_id => $page_data->container_id,
        });
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = {'ERR_START_<group>_GENERAL_FAILURE' => [$group_id, $_]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    # check if current container is suitable for this PGID/RGID
    try {
        $pp->is_group_id_suitable_with_container({
            group_id => $group_id,
            container_id => $container_id,
        });
        $err = 0;
    }
    catch {
        $err = {'ERR_START_<group>_BAD_CONTAINER_TYPE' => [$group_id, $container_id, $_]};
    };
    return $err if $err;

    $page_data->putaway_prep($pp);
    $page_data->recode($is_recode);

    return;
}

=head2 try_to_resume_container

B<Description>

Assuming that this current page corresponds to start resuming container.
It tries to perform this action based on passed parameters.

'scan_value' should Container ID.

Resuming of existing container is done in two stages:

1) read and validate container ID (current method) ,

2) associate container with PGID/RGID (L<try_to_finish_container_resuming>).

B<Return>

UNDEF - If based on passed parameters it is possible to finish resuming of started container.

In case of failures array ref of errors are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub try_to_resume_container {
    my ($page_data) = @_;

    my $container_id;
    try {
        $container_id = NAP::DC::Barcode::Container->new_from_barcode(
            $page_data->scan_value,
        );
    };

    # check if passed container ID actually looks like real one, and
    # if it does not return empty error because we do not want user to
    # see this error message
    return 'ERR_EMPTY' unless $container_id;

    my $container = $page_data->container_helper->find_in_progress({
        container_id => $container_id,
    });

    return { ERR_RESUME_CONTAINER_FAILURE => [$container_id] } unless $container;

    # check that container is not started at Putaway prep for Packing Exception
    return { ERR_RESUME_CONTAINER_USE_PPPE => [$container_id] }
        if $container->does_contain_only_cancelled_group;

    return;
}

=head2 try_to_finish_container_resuming

B<Description>

Assuming that current page is one that stands for finishing resuming started container,
this method tries to do it.

Submitted parameters should have C<container_id> and scan_value should be C<PGID/RGID>

B<Return>

UNDEF - If based on passed parameters it is possible to finish resuming of started container.

In case of failures array ref of errors are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub try_to_finish_container_resuming {
    my ($page_data) = @_;

    my $container_id = $page_data->container_id;
    my $group_id = $page_data->scan_value;

    # if no container nor PGID were submitted, this is not finish resuming container screen
    return 'ERR_EMPTY' unless $container_id and $group_id;


    my ($pp, $is_recode);
    # depending on the group ID formap treat it as Recode based or PGID based one.
    if ($group_id =~ /^r\-?/){
        $pp = XTracker::Database::PutawayPrep::RecodeBased->new({schema => $page_data->putaway_prep->schema});
        $is_recode = 1;
    } else {
        $pp = XTracker::Database::PutawayPrep->new({schema => $page_data->putaway_prep->schema});
        $is_recode = 0;
    }


    my $err;
    try {
        # check is passed PGID is valid one
        $pp->is_group_id_suitable({
            group_id     => $group_id,
            container_id => $container_id,
        });

        # check if submitted container could accept items from current PGID
        $pp->is_group_id_suitable_with_container({
            group_id     => $group_id,
            container_id => $container_id,
        });
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = {ERR_FINISH_CONTAINER_RESUMING => [$group_id, $_]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    $page_data->putaway_prep($pp);
    $page_data->recode($is_recode);

    return;
}

=head2 is_it_scan_container

B<Description>

Determine if currently use in scanning container action.

B<Returns>

TRUE if container was just scanned

=cut

sub is_it_scan_container  {
    my ($page_data) = @_;

    return unless $page_data->scan;

    return ($page_data->scan_field||'') eq 'container_id';
}

=head2 try_start_container

B<Description>

Assuming taht current page is one for starting container, this method associates passed
container with active PGID.

This method assumes that container ID is in "scan_value" of submitted parameters
and PGID/RGID in "group_id" entry page data.

B<Returns>

UNDEF - If based on passed parameters it is possible to start container.

In case of failures array ref of errors are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub try_start_container {
    my ($page_data) = @_;

    my $container_id;my $err;
    try {
        $container_id = NAP::DC::Barcode::Container->new_from_barcode($page_data->scan_value);
        $err = 0;
    } catch {
        $err = {ERR_START_CONTAINER_INVALID => [$page_data->scan_value]};
    };
    return $err if $err;

    my $group_id = $page_data->group_id;

    # check if container is already in progress
    return { ERR_START_CONTAINER_FAILURE => [$container_id,
        sprintf('Container "%s" is already in progress', $container_id)
    ]} if $page_data->container_helper
        ->find_incomplete({ container_id => $container_id });

    # check if submitted container could accept items from current PGID/RGID
    try {
        $page_data->putaway_prep->is_group_id_suitable_with_container({
            group_id     => $group_id,
            container_id => $container_id,
        });

        # do not actually create a new PutawayPrepContainer row yet,
        # it will only be created when the first SKU is scanned
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = { ERR_START_CONTAINER_FAILURE => [$container_id, $_]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    return;
}

=head2 prepare_for_container_screen

B<Description>

Provide C<$page_data> object that has all necessary data for building
Container screen: page with container details and where user is prompted
to scan new SKU into container or mark container as completed.

=cut

sub prepare_for_container_screen {
    my ($page_data) = @_;

    push @{$page_data->prompts}, 'PRM_CONTAINER_SCREEN';

    $page_data = _fetch_container_data($page_data);

    $page_data->scan_field('sku');

    return $page_data;
}

=head2 _fetch_container_data

B<Description>

Updated passed C<$page_data> object with information regarding container details:
its content (what actually was scanned into it) and questions to be asked before
sending container to PRL.

=cut

sub _fetch_container_data {
    my ($page_data) = @_;

    # pass current container content
    $page_data->container_content(
        _get_container_content({
            putaway_prep     => $page_data->putaway_prep,
            container_helper => $page_data->container_helper,
            container_id     => $page_data->container_id,
        })
    );

    my $container = $page_data->container_helper->find_in_progress({
        container_id => $page_data->container_id
    });
    $page_data->prl_questions( $container->get_prl_specific_questions() )
        if $container;

    return $page_data;
}

=head2 _get_container_content

B<Description>

Private method that is used to get data structure required by template
for showing container content.

B<Parameters>

=over

=item putaway_prep

Resultset for DBIC class that stands for "putaway_prep" page.

=item container_id

Container ID.

=item container_helper

Instance of "Public::PutawayPrepContainer" resultset.

=back

=cut

sub _get_container_content {
    my ($args) = @_;

    my ($putaway_prep, $container_helper, $container_id)
        = @$args{qw/putaway_prep container_helper container_id/};

    my $container = $container_helper->find_in_progress({container_id => $container_id});

    # if no container information is available for provided ID, do not proceed further
    return [] unless $container;

    return $container->get_container_content_statistics;
}

=head2 is_it_scan_sku_into_container

B<Description>

Check if current action is one of scanning SKU into container.

B<Returns>

TRUE if it is.

=cut

sub is_it_scan_sku_into_container {
    my ($page_data) = @_;

    return unless $page_data->scan;

    return ($page_data->scan_field||'') eq 'sku';
}

=head2 add_sku_to_container

B<Description>

Assumes that currently scanned value is SKU that is needed to be placed into
active container. SKU should belong to active PGID.

This method assume that page data contains entries for
"container_id" and "group_id". And submitted "scan_value" parameter has SKU to be moved.

B<Returns>

UNDEF - If based on passed parameters it is possible to to add SKU into container.

In case of failures array ref of errors are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub try_add_sku_into_container {
    my ($page_data) = @_;

    my $container_id = $page_data->container_id;
    my $group_id = $page_data->group_id;
    my $sku  = $page_data->scan_value;
    my $err;

    if (not $page_data->container_helper->find_in_progress({ container_id => $container_id }) ) {
        # this must be the first sku scanned
        # start the PutawayPrepContainer
        try {
            $page_data->container_helper->start({
                container_id => $container_id,
                user_id      => $page_data->user_id,
            });
            $err = 0;
        } catch {
            use experimental 'smartmatch';
            if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
                $err = { ERR_START_CONTAINER_FAILURE => [$container_id, $_]};
            }
            else {
                die $_;
            }
        };
        return $err if $err;
    }

    # check if passed SKU exists in database
    return {ERR_SKU_UNKNOWN => [$sku]}
        unless get_variant_by_sku(
            $page_data->container_helper->result_source->schema->storage->dbh, $sku
        );

    # check if submitted SKU belongs to currently processed Product group
    try {
        $page_data->putaway_prep->does_sku_belong_to_group_id({
            group_id => $group_id,
            sku      => $sku,
        });
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = {'ERR_SKU_NOT_FROM_<group>' => [$sku, $group_id]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    try {

        # current user moves current SKU from Process group into container
        $page_data->container_helper->add_sku({
            group_id     => $group_id,
            sku          => $sku,
            container_id => $container_id,
            putaway_prep => $page_data->putaway_prep,
        });
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = {ERR_ADD_SKU_TO_CONTAINER_GENERAL => [$sku, $_]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    return;
}

=head2 is_it_mark_container_as_complete

B<Description>

Check if currently handled action stands for "Complete container" one.

B<Returns>

TRUE - if is does.

=cut

sub is_it_mark_container_as_complete {
    my ($page_data) = @_;

    return ($page_data->container_complete and defined $page_data->container_id);
}

=head2 mark_container_as_complete

B<Description>

Mark submitted container as "Complete".

The method assumes that page data contains Container ID ("container_id")
and PGID/RGID ("group_id").

B<Description>

UNDEF - If container was successfully marked as completed.

In case of failures array ref of errors are returned. Each item from this array
could be simply C<string> with error key (if this error is simple and does not have any
parameters) or C<HASH REF> where single key stands for error message key and single
value - array ref of parameters.

Please note, that some failures could be "silent", that is user should not see any
messages regarding to this issue. In that case error message key is C<ERR_EMPTY>

=cut

sub mark_container_as_complete {
    my ($page_data) = @_;

    my $container_id = $page_data->container_id;
    my $container = $page_data->container_helper->find_in_progress({
        container_id => $container_id
    });

    # make sure that user replied correctly to question about container fullness
    # (if this question is required)
    return 'ERR_MARK_AS_COMPLETE_NO_ANSWER_FOR_FULLNESS_QUESTION'
        if %{$container->check_answers_for_prl_specific_questions({
            container_fullness => $page_data->prl_specific_question__container_fullness,
        })};
    my $err;
    try {
        # mark passed container as complete, no more items are going to be scanned into it
        $page_data->container_helper->finish({
            container_id       => $container_id,
            container_fullness => $page_data->prl_specific_question__container_fullness,
        });
        $err = 0;
    } catch {
        use experimental 'smartmatch';
        if ($_ ~~ match_instance_of('NAP::XT::Exception')) {
            $err = {ERR_MARK_AS_COMPLETE_FAILURE_REASON =>[$container_id, $_]};
        }
        else {
            die $_;
        }
    };
    return $err if $err;

    return;
}

=head2 prepare_start_page

B<Description>

Prepare data needed for showing initial page of "Putaway Prep" process.

=cut

sub prepare_start_page {
    my ($handler, $page_data) = @_;

    $handler->add_to_data( get_pgid_lists( $handler->schema ) );
     return XTracker::Stock::GoodsIn::PutawayPrep::Parameters->new(
        scan_field => 'group_id',
        prompts => ['PRM_INITIAL_PROMPT'],
        putaway_prep => $page_data->putaway_prep,
        recode => $page_data->recode,
    );
}

=head2 is_it_remove_sku_from_container

B<Description>

Determine if current action is "remove SKU from container".

=cut

sub is_it_remove_sku_from_container {
    my ($page_data) = @_;

    return unless $page_data->scan;

    return ($page_data->scan_field||'') eq 'remove_sku';
}

sub get_pgid_lists {
    my ( $schema ) = @_;
    my $dbh = $schema->storage->dbh;
    my $process = 'putaway_prep';
    my $pgid;
    for (
        [ 'delivery'        => $schema->resultset('Public::StockProcess')->putaway_prep_process_groups ],
        [ 'quarantine'      => get_quarantine_process_group( $dbh, $process ) ],
        [ 'returns'         => get_customer_return_process_group( $dbh, $process ) ],
        [ 'sample_returns'  => get_samples_return_process_group( $dbh, $process ) ],
        [ 'samples'         => get_sample_process_group( $dbh, $process ) ],
        [ 'recodes'         => $schema->resultset('Public::StockRecode')->putaway_prep_process_groups ],
    ) {
        my ( $section, $list ) = @$_;
        $pgid->{$_}{$section} = $list->{$_} for keys %$list;
    }
    return { process_groups => $pgid };
}

1;
