package XT::Service::Promotion::CreateEdit;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use Class::Std;

use Data::Dump qw(pp);
use Data::FormValidator;
use Data::FormValidator::Constraints qw(:closures);
use DateTime;

use XT::Domain::Promotion;
use XT::Domain::Product;

use XT::Data::Promotion::CreateEdit;

use XT::Service qw( $OK $FAILED );

use XTracker::Constants::FromDB qw( :promotion_coupon_target :promotion_jointype :promotion_status :promotion_price_group );
use XTracker::Promotion::Common qw( construct_left_nav );
use XTracker::DFV qw( :promotions );
use XTracker::Error;
use XTracker::Handler;
use XTracker::Logfile qw(xt_logger);
use XTracker::Session;

use base qw/ XT::Service /;

#
# profile for DFV validation
#
our %DFV_PROFILE_FOR = (
    store_promotion => {
        required => [qw(
            promotion_name
            promotion_start
            promotion_start_hour
            promotion_start_minute
            target_city

            discount_type

            applicability_website

            restrict_by_weeks
            restrict_x_weeks
        )],

        optional => [qw(
            promotion_id

            promotion_end
            promotion_end_hour
            promotion_end_minute

            title
            subtitle

            percentage_discount_amount
            discount_pounds
            discount_euros
            discount_dollars

            coupon_prefix
            coupon_target_type
            coupon_restrictions
            coupon_generation

            price_group

            trigger_pounds
            trigger_euros
            trigger_dollars

            season_checkboxes
            designer_checkboxes
            producttype_checkboxes
            product_pid_list

            shipping_checkboxes

            group_include_checkboxes
            group_exclude_checkboxes
            include_join_type
            exclude_join_type

            coupon_restriction_freelimit
        )],

        dependencies => {
            discount_type => {
                percentage_discount => [ qw( percentage_discount_amount title subtitle ) ],
                lump_sum_discount   => [ qw(title subtitle) ],
                free_shipping       => [ qw(title subtitle) ],
            },
            coupon_target_type => {
                $PROMOTION_COUPON_TARGET__CUSTOMER_SPECIFIC     => [ qw( coupon_prefix coupon_generation coupon_restrictions ) ],
                $PROMOTION_COUPON_TARGET__FRIENDS_AND_FAMILY    => [ qw( coupon_prefix coupon_generation coupon_restrictions ) ],
                $PROMOTION_COUPON_TARGET__GENERIC               => [ qw( coupon_prefix ) ],
            },
            # we inserted these (id's) by hand
            coupon_restrictions => {
                25 => [ qw( coupon_restriction_freelimit ) ],
                26 => [ qw( coupon_restriction_freelimit ) ],
            },
        },

        filters => [qw(trim)],

        # this doesn't do what we first thought
#        field_filters => {
#            percentage_discount_amount  => ['digit'],
#            discount_pounds             => ['digit'],
#            discount_euros              => ['digit'],
#            discount_dollars            => ['digit'],
#
#            trigger_pounds              => ['digit'],
#            trigger_euros               => ['digit'],
#            trigger_dollars             => ['digit'],
#
#            coupon_target_type          => ['digit'],
#            coupon_restrictions         => ['digit'],
#            price_group                 => ['digit'],
#
#            coupon_restriction_freelimit    => ['digit'],
#        },

        constraint_methods => {
            promotion_start     => dfv_is_ymd(),
            promotion_end       => [
                dfv_is_ymd(),
                dfv_end_in_future(),
                dfv_start_before_end(),
            ],

            percentage_discount_amount => [
                dfv_divisible_by_5(),
                dfv_5_to_90(),
            ],

            coupon_restriction_freelimit => dfv_not_more_than(9999999),
            title           => FV_max_length(30),
            subtitle              => FV_max_length(75),
            promotion_name               => FV_max_length(60),

            discount_type          => dfv_offer_data_valid(),
            discount_pounds     => dfv_divisible_by_5(),
            discount_euros      => dfv_divisible_by_5(),
            discount_dollars    => dfv_divisible_by_5(),

            coupon_prefix       => dfv_valid_coupon_prefix(),

            trigger_pounds      => dfv_divisible_by_5(),
            trigger_euros       => dfv_divisible_by_5(),
            trigger_dollars     => dfv_divisible_by_5(),
        },
    },
);


{

    my %promo_domain_of     :ATTR( get => 'promo_domain',       set => 'promo_domain'       );
    my %product_domain_of   :ATTR( get => 'product_domain',     set => 'product_domain'     );
    my %data_of             :ATTR( get => 'data',               set => 'data'               );



    sub START {
        my($self) = @_;
        my $schema = $self->get_schema;

        $self->set_promo_domain(
             XT::Domain::Promotion->new({ schema => $schema })
        );
        $self->set_product_domain(
             XT::Domain::Product->new({ schema => $schema })
        );
    }

    sub process {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $schema = $handler->{schema};

        # any form submisisons?
        if ( defined $handler->{request}->method
            and $handler->{request}->method eq 'POST'
        ) {
            my $redirect_url = $self->_process_request( $handler );
            return $redirect_url if (defined $redirect_url);
        }

        # populate drop-downs, etc
        $self->prepare_output( $handler );

        return;
    }

    sub prepare_output {
        my($self) = @_;
        my $handler = $self->get_handler();

        # create objects that provide access to the tiers we want
        my $product = $self->get_product_domain;
        my $promo   = $self->get_promo_domain;

        #
        # drop-down menu data (always required)
        #

        # Customer Groups
        $handler->{data}{groups}
            = $promo->customer_group_list();

        # Seasons - for "Product Groups" tab
        $handler->{data}{seasons}
            = $product->product_active_season();

        # Designers - for "Product Groups" tab
        $handler->{data}{designers}
            = $product->product_designer();

        # Product Types - for "Product Groups" tab
        $handler->{data}{product_types}
            = $product->product_type();

        # Coupons menu data - for Promotion Type tab
        $handler->{data}{coupon_targets}
            = $promo->promotion_coupon_targets();

        $handler->{data}{coupon_restrictions}
            = $promo->promotion_coupon_restriction();
        $handler->{data}{coupon_restriction_groups}
            = $promo->promotion_coupon_restriction_group();

        $handler->{data}{coupon_generation}
            = $promo->promotion_coupon_generation();

        # Price Group menu data - for Promotion Type tab
        $handler->{data}{price_groups}
            = $promo->promotion_price_group();

        # Target City menu data - for Promotion Type tab
        $handler->{data}{target_cities}
            = $promo->promotion_target_city();

        # Applicable Website(s)
        $handler->{data}{websites}
            = $promo->promotion_website();

        # Shipping Option menu data - for Promotion Type tab (details)
        $handler->{data}{shipping_options}
            = $promo->promotion_shippingoption();

        # Customer Group Joins (AND/OR)
        $handler->{data}{customer_group_joins}
            = $promo->customer_group_join_list();



        #
        # promotion data (only required if we're editing - i.e. have an id)
        #
        if ($handler->{param_of}{id}) {

            $handler->{data}{promotion} =
                $promo->retrieve_promotion( $handler->{param_of}{id} );


            # pre-fill/re-fill form data
            # less typing, and easier on the eyes
            my $promotion = $handler->{data}{promotion};

            # switch timezone for the time display ...
            if (defined $promotion->start_date) {
                $promotion->start_date->set_time_zone(
                    $promotion->target_city->timezone
                );
            }
            if (defined $promotion->end_date) {
                $promotion->end_date->set_time_zone(
                    $promotion->target_city->timezone
                );
            }

            # we use ||= so that we don't trash any frefilled form data
            $handler->session_stash()->{form_data} ||= {
                #
                # summary form data
                #
                promotion_name          => $promotion->internal_title(),
                target_city             => $promotion->target_city_id(),

                promotion_start         => $promotion->start_date->ymd(),
                # we require these to be zero-padded
                promotion_start_hour    => sprintf("%02d", $promotion->start_date->hour()),
                promotion_start_minute  => sprintf("%02d", $promotion->start_date->minute()),

                title          => $promotion->title(),
                subtitle             => $promotion->subtitle(),

                #
                # "Promotion Type" form data
                #
                discount_type                  => $promotion->discount_type(),
                percentage_discount_amount  => $promotion->discount_percentage(),
                discount_pounds             => $promotion->discount_pounds(),
                discount_euros              => $promotion->discount_euros(),
                discount_dollars            => $promotion->discount_dollars(),
                trigger_pounds              => $promotion->basket_trigger_pounds(),
                trigger_euros               => $promotion->basket_trigger_euros(),
                trigger_dollars             => $promotion->basket_trigger_dollars(),
                applicability_website       => $promotion->website_id_list(),
                coupon_restrictions         => $promotion->coupon_restriction_id(),
                coupon_generation           => $promotion->coupon_generation_id(),
                coupon_prefix               => $promotion->coupon_prefix(),
                coupon_target_type          => $promotion->coupon_target_id(),
                price_group                 => $promotion->price_group_id(),

                # free shipping selected checkboxes
                shipping_checkboxes         => $promotion->shipping_id_list(),

                #
                # "Product Groups" form data
                #
                season_checkboxes           => $promotion->season_id_list(),
                designer_checkboxes         => $promotion->designer_id_list(),
                producttype_checkboxes      => $promotion->producttype_id_list(),

                # the X-week rule
                restrict_by_weeks           => $promotion->restrict_by_weeks(),
                restrict_x_weeks            => $promotion->restrict_x_weeks(),

                coupon_restriction_freelimit    => $promotion->coupon_custom_limit(),
            };

            # if we're a GENERIC coupon we need to do something slightly hacky
            # with the "prefix"
            if ($PROMOTION_COUPON_TARGET__GENERIC == $promotion->coupon_target_id()) {
                # make the prefix the entire code ... I know, it's lovely!
                my $fd = $handler->session_stash()->{form_data};
                $fd->{coupon_prefix} = $promotion->generic_coupon()->code;
            }

            # there might not be an end_date to call DateTime methods on ...
            if (defined $promotion->end_date) {
                my $fd = $handler->session_stash()->{form_data};
                $fd->{promotion_end}        = $promotion->end_date->ymd();
                $fd->{promotion_end_hour}   = sprintf("%02d", $promotion->end_date->hour());
                $fd->{promotion_end_minute} = sprintf("%02d", $promotion->end_date->minute());
            }

            # make PID list into the correct string format for the textarea
            if (my $pid_list = $promotion->promotion_product_pid_list()) {
                my $fd = $handler->session_stash()->{form_data};
                $fd->{product_pid_list}     ||= join(q{, }, sort { $a <=> $b } @{$pid_list});
            }

            # the two lists of customer groups (include and exclude) need a
            # tiny bit of magic to make the correct values appear selected in
            # the correct list
            if (1) {
                my $fd = $handler->session_stash()->{form_data};
                $fd->{group_include_checkboxes} ||= $promotion->customergroup_included_id_list();
                $fd->{group_exclude_checkboxes} ||= $promotion->customergroup_excluded_id_list();

                # include and/or setting (name="include_join_type")
                $fd->{include_join_type}    ||= $promotion->include_group_join->id;
                # exclude and/or setting (name="exclude_join_type")
                $fd->{exclude_join_type}    ||= $promotion->exclude_group_join->id;
            }

        }

        # if we don't have any restriction form data ... set some defaults
        if (not exists $handler->session_stash()->{form_data}{restrict_by_weeks}) {
            # "Limit to products" default to "No"
            $handler->session_stash()->{form_data}{restrict_by_weeks} = 0;
            # the number of weeks in the menu defaults to 6
            $handler->session_stash()->{form_data}{restrict_x_weeks} = 6;
        }

        construct_left_nav($handler);

        return;
    }

    sub _process_request {
        my($self,$handler) = @_;
        my $schema = $handler->{schema};
        my $session = $handler->session;

        # are we saving the promotion?
        if ( defined $handler->{param_of}{action}
            and     $handler->{param_of}{action} eq 'Save Promotion'
        ) {

            return '/NAPEvents/Manage'
                if ($self->_request_store_promotion( $handler ));
        }

        # otherwise .. we have no idea what's going on!
        else {
            xt_warn('No idea what you are trying to do!');
        }

        return;
    }


    sub _request_store_promotion {
        my ($self, $handler) = @_;
        my $session = $handler->session;
        my ($results, $status);

        #xt_logger->debug(pp($handler->{param_of}));

        # attempt to validate input
        eval {
            $results = Data::FormValidator->check(
                $handler->{param_of},
                $DFV_PROFILE_FOR{store_promotion}
            );
        };
        if ($@) {
            xt_logger->fatal($@);
            xt_die($@); # die rather than warn, to prevent unfilled forms on page
        }


        # handle invalid form data
        if ($results->has_invalid or $results->has_missing) {
            # process missing elements
            if ($results->has_missing) {
                $handler->{data}{validation}{missing} = $results->missing;
            }
            # process invalid elements
            if ($results->has_invalid) {
                $handler->{data}{validation}{invalid} = scalar($results->invalid);
            }


            # repopulate the form
            $handler->session_stash()->{form_data}
                = $handler->{param_of};
            return;
        }

        # custom validation that doesn't fit well into DFV
        # TODO - try to find away to pass useful data into DFV
        else {
            # make sure the promotion name hasn't already been used
            if (not $self->_forumname_available($handler, $results)) {
                $handler->{data}{validation}{invalid}{promotion_title} = 'internal_title_not_unique';
            }

            # if we have a PID list, make sure it's not insane
            if ($handler->{param_of}{product_pid_list}) {
                if (not $self->_valid_pid_list($handler, $results)) {
                    $handler->{data}{validation}{invalid}{product_pid_list} = 'invalid_pid';
                }
            }

            # check the customer lists, make sure people haven't been putting
            # things into both lists
            if (
                $handler->{param_of}{group_include_checkboxes}
                    or
                $handler->{param_of}{group_exclude_checkboxes}
            ) {
                if (not $self->_valid_customergroup_list($handler, $results)) {
                    $handler->{data}{validation}{invalid}{customer_group_list}
                        = 'invalid_customer_groups';
                }
            }

            # if we're "doing a coupon", make sure it hasn't already been used
            # (if it's generic) - XTR-894
            if (defined $handler->{param_of}{coupon_prefix}) {
                $self->_coupon_available($handler, $results);
            }

            # make sure people aren't using "bad" combinations of options
            if (not $self->_check_stipulations($handler, $results)) {
                $handler->{data}{validation}{invalid}{promotion_stipulation}
                    = 'invalid_combination';
            }

            # if we have any of our own validation failures
            if (keys %{$handler->{data}{validation}{invalid}}) {
                # repopulate the form
                $handler->session_stash()->{form_data}
                    = $handler->{param_of};
                return;
            }
        };

        # mmm, shiny valid formy goodness!
        my $data = $self->_input_to_data($results);

        # let's store the tinker in the database
        eval {
            my ($promotion_summary);

            $promotion_summary = $handler->{schema}->txn_do(
                sub{
                    $self->_store_promotion($handler, $results);
                }
            );

            if ($results->valid('promotion_id')) {
                xt_info(
                    q{Promotion '}
                    . q{<a href="/NAPEvents/Manage/Edit?id=}
                    . $promotion_summary->id()
                    . q{">}
                    . $promotion_summary->internal_title()
                    . q{</a>}
                    . q{' updated.}
                );
            }
            else {
                xt_info(
                    q{New promotion '}
                    . q{<a href="/NAPEvents/Manage/Edit?id=}
                    . $promotion_summary->id()
                    . q{">}
                    . $promotion_summary->internal_title()
                    . q{</a>}
                    . q{' created with Promotion ID of: }
                    . $promotion_summary->visible_id()
                );
            }
        };

        # deal with any transaction errors
        if ($@) {                                   # Transaction failed
            die "something terrible has happened!"  #
                if ($@ =~ /Rollback failed/);       # Rollback failed

            xt_warn(qq{Database transaction failed: $@});
            xt_logger->warn( $@ );

            # repopulate the form
            $handler->session_stash()->{form_data}
                = $handler->{param_of};

            return;
        }

        return $OK;
    }

    sub _input_to_data {
        my($self, $results) = @_;
        my $handler = $self->get_handler();
        my $data = XT::Data::Promotion::CreateEdit->new;

        # ALWAYS BE CLASSIC! DCS-991
        $data->set_is_classic( 1 );

        $data->set_start_date(
            datetime_from_formdata(
                'promotion_start',
                scalar($results->valid),
                $handler,
            ));

        $data->set_end_date(
            datetime_from_formdata(
                'promotion_end',
                scalar($results->valid),
                $handler,
            ));

        $data->set_internal_title(
            $results->valid('promotion_name') );

        $data->set_target_city_id(
            $results->valid('target_city') );

        # order line data
        if (defined $results->valid('title')) {
            $data->set_title(
                $results->valid('title') );
        }
        if (defined $results->valid('subtitle')) {
            $data->set_subtitle(
                $results->valid('subtitle') );
        }

        if (defined $results->valid('percentage_discount_amount')) {
            $data->set_discount_percentage(
                $results->valid('percentage_discount_amount') );
        }

        if (defined $results->valid('discount_pounds')) {
            $data->set_discount_pounds($results->valid('discount_pounds'));
        }

        if (defined $results->valid('discount_euros')) {
            $data->set_discount_euros($results->valid('discount_euros'));
        }

        if (defined $results->valid('discount_dollars')) {
            $data->set_discount_dollars($results->valid('discount_dollars'));
        }

        if (defined $results->valid('coupon_target_type')) {
            $data->set_coupon_target_id($results->valid('coupon_target_type'));
        }

        # work some magic on the prefix
        if ($PROMOTION_COUPON_TARGET__GENERIC == $data->get_coupon_target_id) {
            # split the coupon_prefix value
            my $code = $results->valid('coupon_prefix');
            # split the code into two parts, making sure we have at least one
            # character in each
            my ($prefix, $suffix) = $code =~ m{
                \A
                (.{1,8})    # up to 8 characters - prefix
                (.{1,8})    # up to 8 characters - prefix
                \z
            }xms;
            # the prefix
            $data->set_coupon_prefix($prefix);
            # the suffix - this will trigger some coupon-magic at store/update time
            $data->set_coupon_suffix($suffix);
        }
        else {
            # just store the prefix as-is
            $data->set_coupon_prefix($results->valid('coupon_prefix'));
        }

        if (defined $results->valid('coupon_restrictions')) {
            $data->set_coupon_restriction_id($results->valid('coupon_restrictions'));
        }

        if (defined $results->valid('coupon_generation')) {
            $data->set_coupon_generation_id($results->valid('coupon_generation'));
        }

        if (defined $results->valid('price_group')) {
            $data->set_price_group_id($results->valid('price_group'));
        }

        if (defined $results->valid('trigger_pounds')) {
            $data->set_basket_trigger_pounds($results->valid('trigger_pounds'));
        }

        if (defined $results->valid('trigger_euros')) {
            $data->set_basket_trigger_euros($results->valid('trigger_euros'));
        }

        if (defined $results->valid('trigger_dollars')) {
            $data->set_basket_trigger_dollars($results->valid('trigger_dollars'));
        }

        if (defined $results->valid('discount_type')) {
            $data->set_discount_type($results->valid('discount_type'));
        }

        # product restriction (by age)
        if (defined $results->valid('restrict_by_weeks')) {
            $data->set_restrict_by_weeks($results->valid('restrict_by_weeks'));
        }
        if (defined $results->valid('restrict_x_weeks')) {
            $data->set_restrict_x_weeks($results->valid('restrict_x_weeks'));
        }

        if (defined $results->valid('coupon_restriction_freelimit')) {
            $data->set_coupon_custom_limit($results->valid('coupon_restriction_freelimit'));
        }

        # FIXME: factor this 'convert to array' functionality
        if (defined (my $app_website = $results->valid('applicability_website'))) {
            #my $app_website = $results->valid('applicability_website');

            if (ref($app_website) ne 'ARRAY') {
                $app_website = [ $app_website ];
            }

            $data->set_applicability_website( $app_website );
        }
        # FIXME: factor this 'convert to array' functionality
        if (defined (my $restriction = $results->valid('shipping_checkboxes'))) {
            if (ref($restriction) ne 'ARRAY') {
                $restriction = [ $restriction ];
            }

            $data->set_shipping_restriction( $restriction );
        }
        # FIXME: factor this 'convert to array' functionality
        if (defined (my $group_include = $results->valid('group_include_checkboxes'))) {
            if (ref($group_include) ne 'ARRAY') {
                $group_include = [ $group_include ];
            }

            $data->set_customer_group_include( $group_include );
        }
        # FIXME: factor this 'convert to array' functionality
        if (defined (my $group_exclude = $results->valid('group_exclude_checkboxes'))) {
            if (ref($group_exclude) ne 'ARRAY') {
                $group_exclude = [ $group_exclude ];
            }

            $data->set_customer_group_exclude( $group_exclude );
        }
        # store the include list AND/OR
        $data->set_include_join_type(
            $results->valid('include_join_type') || $PROMOTION_DETAIL_CUSTOMERGROUP_JOIN__AND
        );
        # store the exclude list AND/OR
        $data->set_exclude_join_type(
            $results->valid('exclude_join_type') || $PROMOTION_DETAIL_CUSTOMERGROUP_JOIN__AND
        );

        # store any individual products
        # XXX should this be product_pid_list not discount_type ??
        if (defined $results->valid('discount_type')) {
            $data->set_individual_pids($results->valid('product_pid_list'))
        }

#        # make sure our status has at least moved on from "unknown"
#        if (
#            (not defined $data->get_status_id)
#                or
#            ($data->get_status_id == $PROMOTION_STATUS__UNKNOWN)
#        ) {
#            xt_info(q{data->set_status_id( $PROMOTION_STATUS__IN_PROGRESS )});
#            $data->set_status_id( $PROMOTION_STATUS__IN_PROGRESS );
#        }

        $self->set_data( $data );
        return;
    }

    sub _store_promotion {
        my ($self, $handler, $results) = @_;
        my ($start_date, $end_date);
        my $promo_domain = $self->get_promo_domain;

        # pull out all the info we need from validation into a single entity
        my $data = $self->get_data;

        # set the operator
        if (not defined $data->get_creator) {
            $data->set_creator(
                $handler->{data}{operator_id}
            );
        }
        # and the last person to change it
        $data->set_last_modifier(
            $handler->{data}{operator_id}
        );

        # if we don't have any "applicability_website" items, then the list was
        # cleared, or never populated - nothing to do
        if (not defined $results->valid('applicability_website')) {
            return;
        }

        # create the summary details
        my $detail = $promo_domain->update_detail( $data );

        # update the detail-website link data
# FIXME: change to data
        $promo_domain->update_detail_websites( $detail->id, $data );

        # update the shipping restrictions
        $promo_domain->update_detail_shippingoptions( $detail->id, $data );

        # make sure we fetch the FULL db-record when we use it
        #$promotion->discard_changes;

        my $promo_id = $detail->id;

        # FIXME: change to data
        # update the summary-season link data
        $promo_domain->update_summary_seasons($results, $promo_id);
        # update the summary-designer link data
        $promo_domain->update_summary_designers($results, $promo_id);
        # update the summary-producttype link data
        $promo_domain->update_summary_producttypes($results, $promo_id);
        # update the summary-individual_product link data
        $promo_domain->update_summary_products($results, $promo_id);
        # update the customer group link data
        $promo_domain->update_customer_groups($results, $promo_id);

        RESTRICTION_CHECK: {
            my ($restricted_by_customer, $restricted_by_product);

            # have we applied any customer (group) restrictions?
            $restricted_by_customer =
                (0 < @{$detail->customergroup_included_id_list});
            # have we applied any product restrictions?
            $restricted_by_product =
                (0 < (
                    $detail->detail_seasons_rs->count
                    + $detail->detail_designers_rs->count
                    + $detail->detail_producttypes_rs->count
                    + $detail->detail_products->count
                ));

            # have we restricted to anything at all?
            if (not $restricted_by_customer and not $restricted_by_product) {
                xt_info(q{NOTICE: There are no customer or product restrictions applied to the promotion});
            }
            # WARNING if we haven't selected any customer group restrictions
            elsif (not $restricted_by_customer) {
                xt_info(q{NOTICE: No customer groups were selected. Promotion will not be restricted by customer.});
            }

            # WARNING if we haven't selected any product restrictions
            elsif (not $restricted_by_product) {
                xt_info(q{NOTICE: No product restrictions were selected. Promotion will not be restricted by product.});
            }
        }

        # if we've got a coupon suffix, create the (single) coupon
        if (defined $data->get_coupon_suffix) {
            $promo_domain->create_generic_coupon( $promo_id, $data );
        }

        # return our shiny new promotion
        # FIXME: return url??
        return $detail;
    }

    # for XTR-894
    sub _coupon_available {
        my($self,$handler,$dfv_results) = @_;

        my $count = 0;
        my $cond  = {};

        # if we're "generic" check for any existing coupons with a code that
        # match our prefix
        if ($PROMOTION_COUPON_TARGET__GENERIC == $dfv_results->valid('coupon_target_type')) {
            # build the WHERE clause
            $cond->{code} = $dfv_results->valid('coupon_prefix');
            # lookup coupon code
            my $coupon_rs = $handler->{schema}->resultset('Promotion::Coupon')
                ->search( $cond )
            ;
            $count = $coupon_rs->count;

            # any matches? that possibly isn't good ...
            if ($count) {
                # if it's tied back to us, we're fine ...
                if (
                    defined $dfv_results->valid('promotion_id')
                        and
                    ($coupon_rs->first->event_id == $dfv_results->valid('promotion_id'))
                ) {
                    # it's ok, it belongs to us
                    return 1;
                }

                # failed validation
                $handler->{data}{validation}{invalid}{coupon_code} = 'coupon_code_in_use';
                return 0;
            }
        }

        # otherwise, we're not fussed because the suffix will be randomly
        # generated (SPECIFIC/FRIENDS-FAMILY)
        else {
            return 1;
        }

        # default to "available for use"
        return 1;
    }

    sub _forumname_available {
        my($self,$handler,$dfv_results) = @_;

        my $count = 0;
        my $cond  = {};

        # we always want to search for a promotion name
        $cond->{internal_title} = $dfv_results->valid('promotion_name');

        # if we have an id, then we're saving the details for an existing
        # promotion
        # (if the id/internal_title belong to the same record)
        if ($dfv_results->valid('promotion_id')) {
            # add id to the search conditions
            $cond->{id} = $dfv_results->valid('promotion_id');
        }

        # FIXME: move to domain
        # look up the promotion name
        $count = $handler->{schema}->resultset('Promotion::Detail')
            ->count(
                $cond
            )
        ;

        # if we have an ID and a match - then things are OK; the name belongs to
        # the correct summary record
        if (defined $dfv_results->valid('promotion_id') and $count) {
            return 1;
        }


        # otherwise, we're trying to create a promotion with a name that's already
        # in use
        if ($count) {
            return 0;
        }

        return 1;
    }

    # this is the table in "A8" of the Create/Edit UI spec, which lists which
    # combinations aren't allowed
    sub _check_stipulations {
        my ($self,$handler,$dfv_results) = @_;

        my $is_basket_triggered = (
            defined $dfv_results->valid('trigger_pounds')
                or
            defined $dfv_results->valid('trigger_euros')
                or
            defined $dfv_results->valid('trigger_dollars')
        );

        my $wants_product_restrictions = (
            defined $dfv_results->valid('season_checkboxes')
                or
            defined $dfv_results->valid('designer_checkboxes')
                or
            defined $dfv_results->valid('producttype_checkboxes')
                or
            defined $dfv_results->valid('product_pid_list')
                or
            (1 == $dfv_results->valid('restrict_by_weeks'))
        );

        # It's a 4 column table, with 13 lovely rules for us to check against.
        # Thankfully 12 of them boil down to, "You can't combine Basket
        # Trigger with X" (spoken to Shirley to confirm this)

        # Row 1: Staff / Any / Coupons / Any
        # XXX can't do, because we don't deal in "special cases" [yet?]

        # Row 2-13
        # * / * / Basket / X
        if ($is_basket_triggered) {
            # we don't allow any of the following with the backet trigger:
            #  - % discount
            #  - lump sum
            #  - free shipping
            if (
                defined $dfv_results->valid('discount_type')
                    and
                (
                    q{percentage_discount} eq $dfv_results->valid('discount_type')
                        or
                    q{lump_sum_discount} eq $dfv_results->valid('discount_type')
                        or
                    q{free_shipping} eq $dfv_results->valid('discount_type')
                )
            ) {
                # make the offer type nicer to read for the user
                my $discount_type = $dfv_results->valid('discount_type');
                $discount_type =~ s{_}{ }g;            # replace underscores with spaces
                $discount_type =~ s{\b(\w)}{\u$1}g;    # capitalize the first letter of each word
                # send a warning/explanation to the user - thankfully they all
                # start with vowels
                xt_info(
                      q{You are not permitted to combine a Basket Trigger with a }
                    . $discount_type
                    . q{ promotion.}
                );
                return 0;
            }
        }

        # there's also another rule from the Permanent/Temporary Promotions
        # document
        #
        #  Permanent discounts can only be set up for Customer Groups and
        #  cannot be set up for Products
        #
        # this boils down to:
        #
        #   If the promotion doesn't have an end date, you must select
        #   customer groups but must not select product groups
        if (not defined $dfv_results->valid('promotion_end')) {
            # if we don't have selected customer groups - it's a fail
            if (not defined $dfv_results->valid('group_include_checkboxes')) {
                xt_info(
                    q{Permanent Promotions (no end-date) must be restricted to at least one customer group}
                );
                return 0;
            }
            # if we do have selected any product groups - it's a fail
            if ( $wants_product_restrictions) {
                xt_info(
                    q{Permanent Promotions (no end-date) may not have any product based restrictions.}
                );
                return 0;
            }
        }

        # we aren't allowed to select Price==ALL and have product restrictions
        if ($dfv_results->valid('price_group') == $PROMOTION_PRICE_GROUP__ALL_FULL_PRICE__AMP__MARKDOWN) {
            # if we do have selected any product groups - it's a fail
            if ( $wants_product_restrictions) {
                xt_info(
                    q{You may not use product restrictions with the "All" price group}
                );
                return 0;
            }
        }

        # it's all OK, we didn't fail anything
        return 1;
    }

    sub _valid_customergroup_list {
        my($self,$handler,$dfv_results) = @_;
        my (@include, @exclude, $lc, @intersection);
        my $error_count = 0;

        # simple check - do we have anything in both lists?
        @include = $dfv_results->valid('group_include_checkboxes');
        @exclude = $dfv_results->valid('group_exclude_checkboxes');
        # see if we've got anything in both lists
        $lc = List::Compare->new( { lists => [\@include, \@exclude] } );
        @intersection = $lc->get_intersection;

        if (scalar @intersection) {
            # get the group names, IDs are useless to the user
            my $results =
                $handler->{schema}->resultset('Promotion::CustomerGroup')
                    ->search(
                        {
                            id => { 'IN', \@intersection },
                        },
                        {
                            'order_by'  => \'name ASC',
                        }
                    );
            my @names;
            while (my $group = $results->next) {
                push @names, $group->name;
            }

            # give the user some feedback
            xt_info(
                  q{The following items are in both customer lists: }
                . join(q{, }, @names)
            );
            $error_count++;
        }

        return (not $error_count);
    }

    # make sure a list of comma-separated PIDs is sane
    sub _valid_pid_list {
        my($self,$handler,$dfv_results) = @_;
        my ($string_list, %pid_seen, %error, $count, $error_count);

        $string_list = $dfv_results->valid('product_pid_list');

        my @items = split(m{,\s*}, $string_list);

        foreach my $item (@items) {
            # does it look like a PID?
            if ($item !~ m{\A\d+\z}) {
                push @{ $error{not_pid} }, $item;
                $error_count++;
                next;
            }

            # have we seen the PID already in this submission?
            if ($pid_seen{$item}) {
                push @{ $error{duplicate} }, $item;
                $error_count++;
                next;
            }
            # flag the item as seen
            $pid_seen{$item}++;

            # can we find a product in the database with a matching PID?
            $count =
                $handler->{schema}->resultset('Public::Product')
                    ->count(
                        {
                            id => $item,
                        }
                    );
            if (not $count) {
                push @{ $error{not_found} }, $item;
                $error_count++;
                next;
            }
        }

        # now build some errors to return to the lovely user
        # invalid format items
        if (exists $error{not_pid}) {
            xt_info(
                  q{The following items do not appear to be valid product IDs: }
                . join(q{, }, sort @{ $error{not_pid} })
            );
        }
        # can't find in the database
        if (exists $error{not_found}) {
            xt_info(
                  q{The following products could not be found: }
                . join(q{, }, sort { $a <=> $b } @{ $error{not_found} })
            );
        }
        # duplicated in the submission
        if (exists $error{duplicate}) {
            xt_info(
                  q{The following items were duplicated in the submission: }
                . join(q{, }, sort { $a <=> $b } @{ $error{duplicate} })
            );
        }

        # FAIL!
        return not $error_count;
    }


    # this DFV constraint uses a method from this module, so hasn't been
    # factored out into XTracker::DFV
    sub dfv_start_before_end {
        return sub {
            my $dfv  = shift;
            my ($data, $start_date, $end_date, $cmp);

            $dfv->name_this('start_after_end');
            $data = $dfv->get_filtered_data();

            # get DateTime objects
            $start_date = datetime_from_formdata(
                'promotion_start',
                scalar($data)
            );
            $end_date = datetime_from_formdata(
                'promotion_end',
                scalar($data)
            );

            # perldoc DateTime; see compare()
            eval {
                $cmp = DateTime->compare( $start_date, $end_date );
            };
            if ($@) {
                xt_logger->fatal($@);
                return 0;
            }

            if ($cmp == 1) { # $a > $b
                return 0;
            }

            return 1;
        }
    }

    # XXX ok, a bit erk, we really should just pass the whole date to a
    # generic object somehow
    sub dfv_end_in_future {
        return sub {
            my $dfv  = shift;
            my ($data, $now, $end_date, $cmp);

            $dfv->name_this('end_in_future');
            $data = $dfv->get_filtered_data();

            # get DateTime objects
            $now = DateTime->now();
            $end_date = datetime_from_formdata(
                'promotion_end',
                scalar($data)
            );

            # perldoc DateTime; see compare()
            eval {
                $cmp = DateTime->compare( $now, $end_date );
            };
            if ($@) {
                xt_logger->fatal($@);
                return 0;
            }

            if ($cmp == 1) { # $a > $b
                return 0;
            }

            return 1;
        }
    }




    # this will return a DateTime object using
    # foo, foo_hour and foo_minutes
    sub datetime_from_formdata {
        my ($stub, $formdata, $handler) = @_;
        my ($date, $year, $month, $day, $hour, $minute, $tz, $dt);

        # get the YMD
        $date       = $formdata->{$stub}
                        || undef;

        # if we don't have a date, we can't do much
        if (not defined $date) {
            return;
        }
        # otherwise, split the date
        ($year, $month, $day) = split /-/, $date;

        # get/set the HMS
        $hour       = $formdata->{$stub . q{_hour}}
                        || '00';
        $minute     = $formdata->{$stub . q{_minute}}
                        || '00';

        # get/set the TZ
        if (defined $handler and defined $formdata->{target_city}) {
            my $city =
                $handler->{schema}->resultset('Promotion::TargetCity')->find(
                    $formdata->{target_city}
                )
            ;
            $tz = $city->timezone;
        }

        if (not defined $tz) {
            $tz = 'UTC';
        }

        # our shiny new date object - created in the relevant timezone
        $dt= DateTime->new(
            year        => $year,
            month       => $month,
            day         => $day,
            hour        => $hour,
            minute      => $minute,

            time_zone   => $tz,
        );


        # switch/convert to UTC
        $dt->set_time_zone( 'UTC' );

        return $dt;
    }


}

1;
