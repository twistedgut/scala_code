package XT::Service::Events::CreateEdit;
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

use XTracker::Constants::FromDB qw(
    :promotion_coupon_target
    :promotion_jointype
    :promotion_status
    :promotion_price_group
    :event_type
    :promotion_shipping_option
);
use XTracker::Events::Common qw( construct_left_nav );
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
    store_event => {
        required => [qw(
            event_name
            discount_type
            event_start
            event_start_hour
            event_start_minute
            target_city
            applicability_website
        )],

        optional => [qw(
            event_id
            event_end
            event_end_hour
            event_end_minute
            percentage_discount_amount
            product_pid_list
        )],

        dependencies => {
            discount_type => {
                percentage_discount => [ qw( percentage_discount_amount title subtitle ) ],
                free_shipping       => [ qw(title subtitle) ],
            },
        },

        filters => [qw(trim)],

        constraint_methods => {
            event_start     => dfv_is_ymd(),
            event_end       => [
                dfv_is_ymd(),
                dfv_end_in_future(),
                dfv_start_before_end(),
            ],

            percentage_discount_amount => [
                dfv_divisible_by_5(),
                dfv_5_to_90(),
            ],

            coupon_restriction_freelimit => dfv_not_more_than(9999999),
            title               => FV_max_length(30),
            subtitle            => FV_max_length(75),
            event_name          => FV_max_length(60),

            discount_type       => dfv_offer_data_valid(),
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
        # anything returned is assumed to be a redirect-url
        # "undefined" means carry on as normal
        my $retval = $self->prepare_output( $handler );

        return $retval;
    }

    sub prepare_output {
        my($self) = @_;
        my $handler = $self->get_handler();
        my $session = $handler->session;

        # create objects that provide access to the tiers we want
        my $product = $self->get_product_domain;
        my $promo   = $self->get_promo_domain;

        #
        # DROP DOWN MENU DATA
        #
        $handler->{data}{target_cities}
            = $promo->promotion_target_city();
        $handler->{data}{websites}
            = $promo->event_website();

        #
        # promotion data (only required if we're editing - i.e. have an id)
        #
        if ($handler->{param_of}{id}) {
            # fetch the event
            $handler->{data}{event} =
                $promo->retrieve_event( $handler->{param_of}{id} );
            # if we didn't get anything, no point in doing anything
            if (not defined $handler->{data}{event}) {
                xt_warn("Outnet Event #$handler->{param_of}{id} does not exist");
                return "/OutnetEvents/Manage";
            }

            # pre-fill/re-fill form data
            # less typing, and easier on the eyes
            my $event = $handler->{data}{event};

            # switch timezone for the time display ...
            if (defined $event->start_date) {
                $event->start_date->set_time_zone(
                    $event->target_city->timezone
                );
            }
            if (defined $event->end_date) {
                $event->end_date->set_time_zone(
                    $event->target_city->timezone
                );
            }

            # we use ||= so that we don't trash any frefilled form data
            $handler->session_stash()->{form_data} ||= {
                event_name                  => $event->internal_title(),
                target_city                 => $event->target_city_id(),

                event_start                 => $event->start_date->ymd(),
                # we require these to be zero-padded
                event_start_hour            => sprintf("%02d", $event->start_date->hour()),
                event_start_minute          => sprintf("%02d", $event->start_date->minute()),

                title                       => $event->title(),
                subtitle                    => $event->subtitle(),

                discount_type               => $event->discount_type(),
                percentage_discount_amount  => $event->discount_percentage(),

                applicability_website       => $event->website_id_list(),
            };

            # there might not be an end_date to call DateTime methods on ...
            if (defined $event->end_date) {
                my $fd = $handler->session_stash()->{form_data};
                $fd->{event_end}        = $event->end_date->ymd();
                $fd->{event_end_hour}   = sprintf("%02d", $event->end_date->hour());
                $fd->{event_end_minute} = sprintf("%02d", $event->end_date->minute());
            }

            # make PID list into the correct string format for the textarea
            if (my $pid_list = $event->promotion_product_pid_list()) {
                my $fd = $handler->session_stash()->{form_data};
                $fd->{product_pid_list}     ||= join(q{, }, sort { $a <=> $b } @{$pid_list});
            }

            # TODO: this will need extra logic when GGG is added properly
            $handler->{data}{content} = 'events/create_edit_promo.tt';
        }

        #
        # if we know what we're creating ...
        #
        #elsif (defined (my $event_type = delete($session->{event_type}))) {
        elsif (defined $handler->{param_of}{event_type}) {
            # the template will have been set in _process_request()
        }

        #
        # otherwise show the type-chooser screen
        #
        else {
            $handler->{data}{content} = 'events/type_picker.tt';
        }

        construct_left_nav($handler);

        return;
    }

    sub _process_request {
        my($self,$handler) = @_;
        my $schema = $handler->{schema};
        my $session = $handler->session;

        xt_logger->debug( pp $handler->{param_of} );

        # are we deciding what type of promotion to create/edit?
        if (
            not defined $handler->{param_of}{event_type}
                or
            q{} eq $handler->{param_of}{event_type}
        ) {
            xt_warn('You need to select an event type to continue');
            return '/OutnetEvents/Manage/Create';
        }

        elsif ('ggg' eq $handler->{param_of}{event_type}) {
            $handler->{data}{content} = 'events/create_edit_ggg.tt';
        }

        elsif ('promotion' eq $handler->{param_of}{event_type}) {
            $handler->{data}{content} = 'events/create_edit_promo.tt';
        }

        else {
            xt_warn(q{I don't recognise that event type});
            return '/OutnetEvents/Manage/Create';
        }


        if ( defined $handler->{param_of}{action}
             and     $handler->{param_of}{action} eq 'Continue'
        ) {
            # populate form field data for the next screen
            $handler->session_stash->{form_data} = {
                event_name              => ($handler->{param_of}{event_name} || q{}),
                applicability_website   => ($handler->{param_of}{applicability_website} || []),
                event_start             => ($handler->{param_of}{due_date} || q{}),
            }
        }

        # are we saving the promotion?
        elsif ( defined $handler->{param_of}{action}
                and     $handler->{param_of}{action} eq 'Save Event'
        ) {
            if ($handler->{param_of}{event_type} eq 'promotion') {
                return '/OutnetEvents/Manage'
                    if ($self->_request_store_event( $handler ));
            }
            else {
                xt_warn('No idea how to save this type of event');
            }
        }

        # otherwise .. we have no idea what's going on!
        else {
            xt_warn('No idea what you are trying to do!');
        }

        return;
    }

    # DCS-615
    sub _request_store_event {
        my ($self, $handler) = @_;
        my $session = $handler->session;
        my ($results, $status);

        VALIDATION_CHECKS: {
            eval {
                $results = Data::FormValidator->check(
                    $handler->{param_of},
                    $DFV_PROFILE_FOR{store_event}
                );
            };
            if ($@) {
                xt_logger->fatal($@);
                xt_die($@); # die rather than warn, to prevent unfilled forms on page
            }

            # TODO this could be replaced with Catalyst::Controller::Validation::DFV
            # TODO when we port events code to Fulcrum
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
                if (not $self->_eventname_available($handler, $results)) {
                    $handler->{data}{validation}{invalid}{event_title} = 'internal_title_not_unique';
                }

                # if we have a PID list, make sure it's not insane
                if ($handler->{param_of}{product_pid_list}) {
                    if (not $self->_valid_pid_list($handler, $results)) {
                        $handler->{data}{validation}{invalid}{product_pid_list} = 'invalid_pid';
                    }
                }
            }

            # if we have any of our own validation failures
            if (keys %{$handler->{data}{validation}{invalid}}) {
                # repopulate the form
                $handler->session_stash()->{form_data}
                    = $handler->{param_of};
                return;
            }
        }

        STORE_DATA: {
            my $data = $self->_input_to_data($results);

            # store the promotion in the database
            eval {
                my ($event_summary);

                $event_summary = $handler->{schema}->txn_do(
                    sub{
                        $self->_store_event($handler, $results);
                    }
                );

                if ($results->valid('event_id')) {
                    xt_info(
                        q{Event '}
                        . q{<a href="/OutnetEvents/Manage/Edit?id=}
                        . $event_summary->id()
                        . q{">}
                        . $event_summary->internal_title()
                        . q{</a>}
                        . q{' updated.}
                    );
                }
                else {
                    xt_info(
                        q{New event '}
                        . q{<a href="/OutnetEvents/Manage/Edit?id=}
                        . $event_summary->id()
                        . q{">}
                        . $event_summary->internal_title()
                        . q{</a>}
                        . q{' created with Promotion ID of: }
                        . $event_summary->visible_id()
                    );
                }
            };
        }

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
        my ($self, $results) = @_;
        my $handler = $self->get_handler();
        my $data = XT::Data::Promotion::CreateEdit->new;

        # ALWAYS BE NON-CLASSIC! DCS-991
        $data->set_is_classic( 0 );

        STORE_FORMDATA_IN_OBJECT: {
            $data->set_start_date(
                datetime_from_formdata(
                    'event_start',
                    scalar($results->valid),
                    $handler,
                )
            );

            $data->set_end_date(
                datetime_from_formdata(
                    'event_end',
                    scalar($results->valid),
                    $handler,
                )
            );

            # set the event type and product_page_visible to 1
            $data->set_event_type_id( $EVENT_TYPE__PROMOTION );
            # 1 => "Non-Classic" when combined with $EVENT_TYPE__PROMOTION
            $data->set_product_page_visible( 1 );

            $data->set_internal_title(
                $results->valid('event_name') );

            $data->set_target_city_id(
                $results->valid('target_city') );

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

            if (defined $results->valid('discount_type')) {
                $data->set_discount_type($results->valid('discount_type'));
            }

            if (defined (my $app_website = $results->valid('applicability_website'))) {
                if (ref($app_website) ne 'ARRAY') {
                    $app_website = [ $app_website ];
                }

                $data->set_applicability_website( $app_website );
            }

            # store any individual products
            if (defined $results->valid('product_pid_list')) {
                $data->set_individual_pids($results->valid('product_pid_list'))
            }
        }

        $self->set_data( $data );
        return;
    }

    sub _store_event {
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
        if (not defined $detail) {
            die "couldn't update_detail()";
        }

        # update the detail-website link data
        $promo_domain->update_detail_websites( $detail->id, $data );

        # update the shipping restrictions
        $promo_domain->update_detail_shippingoptions( $detail->id, $data );

        # less typing below (XXX in the restriction checks we aren't yet
        # doing)
        my $promo_id = $detail->id;

        # update the summary-individual_product link data
        $promo_domain->update_summary_products($results, $promo_id);

        return $detail;
    }

    sub _eventname_available {
        my($self,$handler,$dfv_results) = @_;

        my $count = 0;
        my $cond  = {};

        # we always want to search for a promotion name
        $cond->{internal_title} = $dfv_results->valid('event_name');

        # if we have an id, then we're saving the details for an existing
        # promotion
        # (if the id/internal_title belong to the same record)
        if ($dfv_results->valid('event_id')) {
            # add id to the search conditions
            $cond->{id} = $dfv_results->valid('event_id');
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
        if (defined $dfv_results->valid('event_id') and $count) {
            return 1;
        }


        # otherwise, we're trying to create a promotion with a name that's already
        # in use
        if ($count) {
            return 0;
        }

        return 1;
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
                'event_start',
                scalar($data)
            );
            $end_date = datetime_from_formdata(
                'event_end',
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
                'event_end',
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

            if (not defined $cmp) {
                xt_logger->warn('looks like the docs lied');
                xt_logger->debug(pp $now);
                xt_logger->debug(pp $end_date);
                return;
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
