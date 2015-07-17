#!/usr/bin/env perl

use NAP::policy "tt",     'test';

=head1 NAME

confirmation_email_preorder.t - Test Confirmation Pre-Order Email

=head1 DESCRIPTION

This tests the sending of the Pre-Order Confirmation Email that happens after
a Pre-Order has been Completed.

#TAGS inventory preorder completepreorder cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Mock::PSP;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :branding
                                            :correspondence_templates
                                        );
use XTracker::Database::Reservation     qw( :email );


my $schema  = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

my $framework   = Test::XT::Flow->new_with_traits(
    traits => [
        'Test::XT::Flow::Reservations',
        'Test::XT::Data::Channel',      # required for PreOrder
        'Test::XT::Data::Customer',     # required for PreOrder
        'Test::XT::Data::PreOrder',
    ],
);

#---------- run tests ----------
_test_completed_pre_order_page( $framework, 1 );
#-------------------------------

done_testing();


=head1 METHODS

=head2 _test_completed_pre_order_page

    _test_completed_pre_order_page( $framework, $ok_to_do_flag );

Tests sending the Pre-Order Confirmation Email. Also tests that without any email body content
the Email does not get sent.

=cut

sub _test_completed_pre_order_page {
    my ( $framework, $oktodo )  = @_;

    SKIP: {
        skip "_test_completed_pre_order_page", 1   if ( !$oktodo );

        note "TESTING 'PreOrder Confirmation' page";

        # 'set_department' should return the Operator Record of the user it's updating
        my $itgod_op    = Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );
        $framework->login_with_permissions( {
            perms => {
                $AUTHORISATION_LEVEL__OPERATOR => [
                    'Customer Care/Customer Search',
                    'Customer Care/Order Search',
                    'Stock Control/Reservation',
                ]
            }
        } );

        # Step 1: Create pre-order
        my $pre_order   = $framework->pre_order;
        my $pre_order_id = $pre_order->id;
        my $reservations = $framework->reservations;

        my @pre_order_items = $pre_order->pre_order_items
                                            ->search( undef, { order_by => 'id' } )
                                                ->all;
        my $confirmation_email_log_rs = $pre_order->pre_order_email_logs
                                                ->search(
                                                        {
                                                            correspondence_templates_id => $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__COMPLETE,
                                                            operator_id                 => $itgod_op->id,
                                                        },
                                                        {
                                                            order_by => 'id DESC',
                                                        }
                                                    );

        # set the Customer's Language to be 'French' which should
        # mean the Email From address should be localised
        $pre_order->customer->set_language_preference('fr');

        my $mech        = $framework->mech;


        note "Check Sending an Email with NO Content DOESN'T get Sent";
        $mech->errors_are_fatal(0);
        $framework->mech__reservation__pre_order_confirmation_email_page( $pre_order_id )
                   ->mech__reservation__send_pre_order_confirmation_email( { email_content => "" } ); ;
        $mech->errors_are_fatal(1);
        like( $mech->app_error_message, qr/Can't send Email: Missing or empty 'Email Text'/i, "Found 'without Text' warning message" );
        _check_email_form( $mech, $pre_order, $itgod_op);
        cmp_ok( $confirmation_email_log_rs->reset->count, '==', 0, "No Cancel Emails Logged" );

        note "Check the Email can be Sent when done properly";
        $framework->mech__reservation__pre_order_confirmation_email_page( $pre_order_id )
                   ->mech__reservation__send_pre_order_confirmation_email( ); ;
        $mech->errors_are_fatal(1);
        like( $mech->app_status_message, qr/Email has been Sent/i, "Found 'Email Sent' Status Message" );
        cmp_ok( $confirmation_email_log_rs->reset->count, '==', 1, "One Cancel Email Logged" );
    };

    return $framework;
}

#-----------------------------------------------------------------

=head2 _check_email_form

    _check_email_form( $mech_object, $dbic_pre_order, $dbic_operator, $args );

Test Helper to check the Send Email page for the correct To, From, Reply-To etc.

=cut

sub _check_email_form {
    my ( $mech, $pre_order, $operator, $args )  = @_;

    my $form_data   = $mech->as_data()->{email_form};

    my $channel = $pre_order->customer->channel;
    my $from    = get_from_email_address( {
                                    channel_config  => $channel->business->config_section,
                                    department_id   => $operator->department_id,
                                    schema          => $channel->result_source->schema,
                                    locale          => $pre_order->customer->locale,
                                } );

    # get rid of stuff don't want to compare
    my $hidden  = delete $form_data->{hidden_fields};

    my $expected    = {
            'Send Email'=> 1,
            To              => $pre_order->customer->email,
            From            => $from,
            'Reply-To'      => $from,
            Subject         => re( qr/\w+.{5,}/ ),
            'Email Text'    => re( qr/\w+.{25,}/ ),
        };
    cmp_deeply( $form_data, $expected, "Email To, From, Reply-To, Subject, Body as expected" );
    like( $hidden->{email_content_type}, qr/\w{3,}/, "Hidden Field: 'email_content_type' has a value: '" . $hidden->{email_content_type} . "'" );
    cmp_ok( $hidden->{pre_order_id}, '==', $pre_order->id, "Hidden Field: 'pre_order_id' as expected: " . $pre_order->id );
    is( $hidden->{on_fail_url}, "/Completed", "Hidden Field: 'on_fail_url' as expected: /Completed" );
    like( $hidden->{redirect_url}, qr{/StockControl/Reservation/Customer},
                                        "Hidden Field: 'redirect_url' as expected: /StockControl/Reservation/Customer" );
    cmp_ok( $hidden->{template_id}, '==', $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__COMPLETE,
                                            "Hidden Field: 'template_id' as expected: " . $CORRESPONDENCE_TEMPLATES__PRE_ORDER__DASH__COMPLETE );


    return;
}

