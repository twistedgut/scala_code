#!/usr/bin/env perl

use NAP::policy "tt",         'test';

=head1 NAME

reservation_view_waiting_lists.t - Checks the Reservation Overview Waiting Lists page

=head1 DESCRIPTION

Checks the 'Waiting Lists' page found on the Left Hand Menu underneath 'View' on the
'Stock Control->Reservations' menu option.

It creates Reservations for Customers that should be in the Next Upload section of the
page and the Other Upload section of the page by different Operators. Then checks the
page by looking at it in 'Personal' & 'All' modes that they are in the correct sections
on the page.

When in 'Personal' mode only the Reservations for the Logged in Operator should be shown.
When in 'All' mode Reservations from All Operators should be shown.

Tests:

    * All Reservations in the Next Upload section
    * All Reservations in the Other Upload section
    * One Customer has one Reservation in Next Upload & Other Upload sections
    * Reservations for different Operators and Customers in both Next Upload & Other Upload sections
    * A Mixture of Reservations for Customers in both of the Next Upload & Other Upload sections
    * Another Mixture of Reservations for Customers in both of the Next Upload & Other Upload sections

#TAGS inventory reservation loops inline cando

=cut

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw(
                                            :authorisation_level
                                            :reservation_status
                                        );
use XTracker::Database::Reservation     qw( get_reservation_list );

use DateTime;


my $framework = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
    ],
);
my $mech    = $framework->mech;

# set the Sales Channel for NaP
$mech->channel( Test::XTracker::Data->get_local_channel_or_nap );
my $channel = $mech->channel;

# get a next upload date
my $next_upload_date    = DateTime->now( time_zone => 'local' )
                                    ->truncate( to => 'day' )
                                        ->add( days => 1 );
my $other_upload_date   = $next_upload_date->clone
                                    ->add( days => 1 );

# clear out existing Reservations & Upload Dates for Products
_clear_existing_data( $framework->schema, $channel );


$framework->login_with_permissions( {
    perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'Stock Control/Reservation',
            ]
        }
    } );
$framework->mech__reservation__summary;


# get the Test Data together required to create Reservations
my $operator            = Test::XTracker::Data->set_department( 'it.god', 'Personal Shopping' );
my $other_operator      = _get_other_operator( $framework->schema, $operator );
my $next_upload_pids    = _get_products( 2, $channel, $next_upload_date );
my $other_upload_pids   = _get_products( 2, $channel, $other_upload_date );
my @customers           = _create_customers( 4, $channel );

# set-up options passed when creating reservations
my %reservation_options = (
    next_upload_date    => $next_upload_date,
    other_upload_date   => $other_upload_date,
    personal_operator   => $operator,
    other_operator      => $other_operator,
);


# specify what Reservations should be Created
my %tests   = (
    'All Reservations in the Next Upload section'   => {
        reservation_data    => [
            { customer => $customers[0], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[1], pid => $next_upload_pids->[1], operator => $other_operator },
            { customer => $customers[2], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[3], pid => $next_upload_pids->[1], operator => $other_operator },
        ],
        send_notification => $customers[0],
    },
    'All Reservations in the Other Upload section'   => {
        reservation_data    => [
            { customer => $customers[0], pid => $other_upload_pids->[0], operator => $operator },
            { customer => $customers[1], pid => $other_upload_pids->[1], operator => $other_operator },
            { customer => $customers[2], pid => $other_upload_pids->[0], operator => $operator },
            { customer => $customers[3], pid => $other_upload_pids->[1], operator => $other_operator },
        ],
    },
    'One Customer has one Reservation in Next Upload & Other Upload sections'    => {
        reservation_data    => [
            { customer => $customers[0], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[0], pid => $other_upload_pids->[0], operator => $other_operator },
        ],
        send_notification => $customers[0],
    },
    'Reservations for different Operators and Customers in both Next Upload & Other Upload sections' => {
        reservation_data    => [
            { customer => $customers[0], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[1], pid => $next_upload_pids->[1], operator => $other_operator },
            { customer => $customers[2], pid => $other_upload_pids->[0], operator => $operator },
            { customer => $customers[3], pid => $other_upload_pids->[1], operator => $other_operator },
        ],
    },
    'A Mixture of Reservations for Customers in both of the Next Upload & Other Upload sections'    => {
        reservation_data    => [
            { customer => $customers[0], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[1], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[2], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[3], pid => $next_upload_pids->[0], operator => $operator },

            { customer => $customers[0], pid => $next_upload_pids->[1], operator => $operator },
            { customer => $customers[1], pid => $next_upload_pids->[1], operator => $operator },
            { customer => $customers[0], pid => $other_upload_pids->[0], operator => $operator },

            { customer => $customers[2], pid => $next_upload_pids->[1], operator => $other_operator },
            { customer => $customers[3], pid => $other_upload_pids->[0], operator => $other_operator },
        ],
    },
    'Another Mixture of Reservations for Customers in both of the Next Upload & Other Upload sections'    => {
        reservation_data    => [
            { customer => $customers[0], pid => $next_upload_pids->[0], operator => $operator },
            { customer => $customers[0], pid => $next_upload_pids->[1], operator => $operator },
            { customer => $customers[0], pid => $next_upload_pids->[1], operator => $other_operator },
            { customer => $customers[0], pid => $other_upload_pids->[0], operator => $operator },

            { customer => $customers[1], pid => $next_upload_pids->[0], operator => $other_operator },
            { customer => $customers[1], pid => $next_upload_pids->[1], operator => $other_operator },
            { customer => $customers[1], pid => $next_upload_pids->[1], operator => $operator },
            { customer => $customers[1], pid => $other_upload_pids->[0], operator => $other_operator },

            { customer => $customers[2], pid => $other_upload_pids->[0], operator => $operator },
            { customer => $customers[2], pid => $other_upload_pids->[1], operator => $operator },
            { customer => $customers[2], pid => $other_upload_pids->[0], operator => $other_operator },
            { customer => $customers[2], pid => $other_upload_pids->[1], operator => $other_operator },

            { customer => $customers[3], pid => $other_upload_pids->[0], operator => $other_operator },
        ],
        send_notification => $customers[0],
    },
);

$framework->mech__reservation__summary_click_waiting;

foreach my $label ( keys %tests ) {
    note "TESTING: ${label}";
    my $test    = $tests{ $label };

    # create the Reservations
    my @reservations= _create_reservations( $test->{reservation_data }, \%reservation_options );
    my $to_expect   = delete $reservation_options{to_expect};

    # check the Personal view - only Reservations by 'it.god' are displayed
    $framework->mech__reservation__apply_filter( 'personal' );
    my $got = _parse_page_data( $mech, $channel );
    is_deeply( $got, $to_expect->{personal}, "With 'Personal' Filter - Reservations shown as expected" );

    # check the All view, where Reservations from all Operators are displayed
    $framework->mech__reservation__apply_filter( 'all' );
    $got    = _parse_page_data( $mech, $channel );
    is_deeply( $got, $to_expect->{all}, "With 'All' Filter - Reservations shown as expected" );

    if ( my $customer = $test->{send_notification} ) {
        # if asked then test the Email can be sent
        $framework->mech__reservation__summary_click_waiting__notification_email( $customer->id )
                    ->mech__reservation__summary_click_waiting__notification_email__send;
    }

    # get rid of the Reservations ready for the next test
    foreach my $reservation ( @reservations ) {
        Test::XTracker::Data->delete_reservations( { customer => $reservation->customer } );
    }
}

done_testing();

#---------------------------------------------------------------------------

=head1 METHODS

=head2 _discard_changes

    _discard_changes( @array_of_dbic_records );

Helper to re-load various DBIC records

=cut

sub _discard_changes {
    my @records = @_;
    foreach my $record ( @records ) {
        $record->discard_changes;
    }
    return;
}

=head2 _parse_page_data

    $hash_ref = _parse_page_data( $mech_object, $dbic_channel );

Parses page data into something that can be tested

=cut

sub _parse_page_data {
    my ( $mech, $channel )  = @_;

    my $pg_data = $mech->as_data()->{page_data}{ $channel->name };

    my %got = (
        next_upload => {
            reservation_count   => 0,
            reservations        => {},
            operators           => {},
        },
        other_upload => {
            reservation_count   => 0,
            reservations        => {},
            operators           => {},
        },
    );

    foreach my $key ( qw( next_upload other_upload ) ) {
        my $operators   = $pg_data->{ $key };
        foreach my $op_id ( keys %{ $operators } ) {
            my $op_heading  = delete $operators->{ $op_id }{heading};
            if ( $op_heading ) {
                $got{ $key }{operators}{ $op_heading->{id} }    = $op_heading->{name};
            }

            my $customers   = $operators->{ $op_id };
            foreach my $cust_id ( keys %{ $customers } ) {
                my $reservations    = $customers->{ $cust_id };
                foreach my $reservation ( @{ $reservations } ) {
                    # see if there is an image in the first column
                    # this will be an 'a' tag with an image in it
                    my @nodes   = $reservation->{raw}->content_list();
                    my ( $img_node ) = $nodes[0]->content_list();

                    $got{ $key }{reservations}{ $op_id }{ $cust_id }{ $reservation->{SKU}{value} }  = {
                        on_page => 1,
                        ( ref( $img_node ) && $img_node->tag eq 'a' ? ( img_id => $img_node->attr('id') ) : () ),
                    };
                    $got{ $key }{reservation_count}++;
                }
            }
        }
    }

    return \%got;
}

=head2 _get_products

    $array_ref_of_pids = _get_products(
        $how_many_to_get,
        $dbic_channel,
        $upload_date_to_set,
    );

Sets up the Products making sure their NOT Live

=cut

sub _get_products {
    my ( $how_many, $channel, $upload_date )    = @_;

    my ( undef, $pids )  = Test::XTracker::Data->grab_products( {
        how_many            => $how_many,
        how_many_variants   => 3,
        channel             => $channel,
        force_create        => 1,
        ensure_stock_all_variants => 1,
    } );

    foreach my $pid ( @{ $pids } ) {
        $pid->{product_channel}->update( { live => 0, visible => 0, upload_date => $upload_date } );

        # delete any existing reservations for the PIDs
        Test::XTracker::Data->delete_reservations( { product => $pid->{product} } );
    }

    return $pids;
}

=head2 _create_customers

    @dbic_customers = _create_customers( $how_many_to_get, $dbic_channel );

Helper to create customers

=cut

sub _create_customers {
    my ( $how_many, $channel )    = @_;

    my @customers;

    foreach my $counter ( 1..$how_many ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::Channel',
                            'Test::XT::Data::Customer',
                        ],
                    );
        $data->channel( $channel );

        # make sure the Customer has a different Email
        # Address than every other Reservation's Customer
        my $customer    = $data->customer;
        $customer->update( { email => $customer->is_customer_number . '.test@net-a-porter.com' } );

        push @customers, $customer;
    }

    return @customers;
}

=head2 _create_reservations

    @dbic_reservations = _create_reservations( $args_hash_ref, $opts_hash_ref );

Helper to create X number of reservations

=cut

sub _create_reservations {
    my ( $args, $opts ) = @_;

    my @reservations;

    my $next_upload_date    = $opts->{next_upload_date};
    my $other_upload_date   = $opts->{other_upload_date};
    my $personal_operator   = $opts->{personal_operator};
    my $other_operator      = $opts->{other_operator};
    my $to_expect;

    # build up what to expect to see on the page
    # for both Personal & All filtered view
    $to_expect  = {
        personal    => {
            next_upload => {
                reservation_count   => 0,
                reservations        => {},
                operators           => {},
            },
            other_upload => {
                reservation_count   => 0,
                reservations        => {},
                operators           => {},
            },
        },
        all         => {
            next_upload => {
                reservation_count   => 0,
                reservations        => {},
                operators           => {},
            },
            other_upload => {
                reservation_count   => 0,
                reservations        => {},
                operators           => {},
            },
        },
    };

    foreach my $arg ( @{ $args } ) {
        my $data = Test::XT::Data->new_with_traits(
                        traits => [
                            'Test::XT::Data::ReservationSimple',
                        ],
                    );

        my $variant = $arg->{pid}{variant};
        my $customer= $arg->{customer};
        my $operator= $arg->{operator};
        my $channel = $customer->channel;

        # get the Current Max Ordering Id for this Variant's Reservations
        my $current_max_ordering    = $variant->reservations->get_column('ordering_id')->max() || 0;

        $data->customer( $customer );
        $data->operator( $operator );
        $data->channel( $channel );
        $data->variant( $variant );

        my $reservation = $data->reservation;
        $reservation->update( { ordering_id => $current_max_ordering + 1 } );   # prioritise each reservation

        note "Customer Id/Nr: " . $reservation->customer->id . "/" . $reservation->customer->is_customer_number
             . ", Reservation Id: " . $reservation->id
             . ", SKU: " . $variant->sku
             . ", Upload Date: " . $variant->product->product_channel
                                            ->first->upload_date
                                                ->truncate( to => 'day' )
             . ", Operator: " . $reservation->operator->name;

        push @reservations, $reservation;

        # update what to expect on the page
        # for tests used later on
        my $upload_date = $variant->product->product_channel->first->upload_date;
        my $expect_key  = (
            DateTime->compare( $upload_date, $next_upload_date ) == 0
            ? 'next_upload'
            : 'other_upload'
        );

        # expect to find this when the page has been parsed
        my $expect_on_page  = {
            on_page => 1,
            # should only see images for 'next_upload'
            ( $expect_key eq 'next_upload' ? ( img_id => 'img_reservation_' . $reservation->id ) : () ),
        };

        $to_expect->{all}{ $expect_key }{reservation_count}++;
        $to_expect->{all}{ $expect_key }{reservations}{ $operator->id }{ $customer->id }{ $variant->sku }   = $expect_on_page;
        $to_expect->{all}{ $expect_key }{operators}{ $operator->id }    = $operator->name;

        if ( $operator->id == $personal_operator->id ) {
            $to_expect->{personal}{ $expect_key }{reservation_count}++;
            $to_expect->{personal}{ $expect_key }{reservations}{ $operator->id }{ $customer->id }{ $variant->sku }  = $expect_on_page;
        }
    }

    $opts->{to_expect}  = $to_expect;

    return @reservations;
}

=head2 _get_other_operator

    $dbic_operator = _get_other_operator( $schema, $operator_id_to_exclude );

This returns an Operator DBIC record that isn't the Operator Id passed in
and also isn't the Application Operator.

=cut

sub _get_other_operator {
    my ( $schema, $exclude )    = @_;

    return $schema->resultset('Public::Operator')
                    ->search(
                        {
                            id  => { 'NOT IN' => [ $APPLICATION_OPERATOR_ID, $exclude->id ] }
                        }
                    )->first;
}

=head2 _clear_existing_data

    _clear_existing_data( $schema, $dbic_channel );

Clears out existing Reservations & Upload dates on the Product Channel record so as
to give the tests predicatable results.

=cut

sub _clear_existing_data {
    my ( $schema, $channel )    = @_;

    note "Clearing out Existing Data";

    # get the list of Reservations that the Waiting Lists
    # page would have shown, and then Cancel them
    my $list    = get_reservation_list( $schema->storage->dbh, {
        type        => 'waiting',
        channel_id  => $channel->id,
    } );

    my %pids    = map { $_->{product_id} => 1 }
                        values %{ $list->{ $channel->name } };

    foreach my $pid ( keys %pids ) {
        Test::XTracker::Data->delete_reservations( { product => $pid } );
    }

    # clear out any existing Upload Dates on the Product Channel table
    my $yesterday   = DateTime->now( time_zone => 'local' )
                                ->subtract( days => 1 )
                                    ->truncate( to => 'day' );

    my $rs  = $channel->product_channels->search(
        {
            upload_date => { '>=' => $yesterday },
        }
    );
    $rs->update( { upload_date => undef } );

    note "DONE - Clearing out Existing Data";

    return;
}
