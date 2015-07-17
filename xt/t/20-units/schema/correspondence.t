#!/usr/bin/env perl
use NAP::policy "tt",     'test';

use feature "state";

=head2 Generic tests for the 'XTracker::Schmea::Result::Public::Correspondence*' classes

This will test various things to do with the 'Correspondence*' classes and it's appropriate associates, currently it tests:

    * Changing Customer/Order Correspondence Preference for a particular Subject
    * Checking that a Method 'can be used' for a Subject for a Customer, Order, Shipment or Return
    * Tests using the Exclusion Calendar
    * Checks the CSM Failure Notification is Sent
    * Checks the 'XT::Correspondence::Method::*' Classes


First done for CANDO-341.

=cut

use Test::XTracker::LoadTestConfig;

# these are used in the '_redefined_send_email' function
my %redef_email_args;
my $redef_send_email    = 0;
my $redef_fail_email    = 0;
my $redef_email_todie   = 0;

# Need to re-define the 'send_email' function here before anything
# loads the 'XT::Correspondence::Method' Class, such as Schema files.
REDEFINE: {
    no warnings "redefine";
    *XT::Correspondence::Method::send_email = \&_redefined_send_email;
    *XTracker::Schema::Result::Public::SmsCorrespondence::send_email = \&_redefined_send_email;
    use warnings "redefine";
};

use Test::XTracker::Data;
use Test::XT::Data;
use Test::XTracker::MessageQueue;

use DateTime;
use DateTime::Format::DateParse;

use XTracker::XTemplate;
use XTracker::Config::Local         qw( config_var config_section_slurp email_address_for_setting );
use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw(
                                        :branding
                                        :correspondence_method
                                        :customer_issue_type
                                        :order_status
                                        :shipment_status
                                        :shipment_type
                                        :shipment_item_status
                                        :shipment_class
                                        :sms_correspondence_status
                                    );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', "sanity check: got a schema" );

# get a new instance of 'XT::Domain::Return'
my $domain  = Test::XTracker::Data->returns_domain_using_dump_dir();

# make it easier to type the Constants for Correspondence Methods
my %method  = (
        SMS     => $CORRESPONDENCE_METHOD__SMS,
        Email   => $CORRESPONDENCE_METHOD__EMAIL,
        Phone   => $CORRESPONDENCE_METHOD__PHONE,
        Document=> $CORRESPONDENCE_METHOD__DOCUMENT,
        Label   => $CORRESPONDENCE_METHOD__LABEL,
    );
my %method_recs = map { $_->method => $_ } $schema->resultset('Public::CorrespondenceMethod')->all;
note "Correspondence Method Names to Ids used in Tests: ".p( %method );

#----------------------------------------------------------
_test_correspondence_preference( $schema, $domain, 1 );
_test_can_use_preference( $schema, $domain, 1 );
_test_csm_exclusion_calendar( $schema, $domain, 1 );
_test_csm_failure_notification( $schema, $domain, 1 );
_test_correspondence_classes( $schema, $domain, $domain->msg_factory, 1 );
#----------------------------------------------------------

done_testing();


# this tests changing the Correspondence Method preference such
# as allowing Email or SMS to be send for a Correspondence Subject
sub _test_correspondence_preference {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_schedule_list", 1               if ( !$oktodo );

        note "in '_test_schedule_list'";

        my $framework   = Test::XT::Data->new_with_traits(
                traits => [ 'Test::XT::Data::Order' ],
        );

        $schema->txn_do( sub {
            # create an order
            my ( $channel, $customer, $order, $shipment )   = _create_an_order( $framework );
            # get an Alternative Sales Channel
            my $alt_channel = $schema->resultset('Public::Channel')
                                        ->search( { id => { '!=' => $channel->id } } )->first;

            _check_required_params( $order );

            # make sure all Methods are Enabled
            foreach my $method ( values %method_recs ) {
                $method->update( { enabled => 1 } );
                $method->discard_changes;               # to make is_deeply tests work
            }

            # delete any Correspondence Subject Method (CSM) Preferences for the Customer/Order
            $customer->customer_csm_preferences->delete;
            $order->orders_csm_preferences->delete;
            # make sure there are no defaults overiding anything
            $customer->customer_correspondence_method_preferences->delete;
            $customer->update( { correspondence_default_preference => undef } );


            note "Testing 'Public::CorrespondenceSubject' methods";

            # create a Correspondence Subject to use in the test
            my $csm_subject = _create_subject( $channel );
            # store all of the above Subject's CSM records for later use
            my %csm = map { $_->correspondence_method->method => $_ } $csm_subject->correspondence_subject_methods->all;

            my $subj_methods    = $csm_subject->get_enabled_methods;
            isa_ok( $subj_methods, 'HASH', "'get_enabled_methods' returns as Expected" );
            is_deeply( $subj_methods, {
                                    $method{'SMS'}  => { method => $method_recs{'SMS'}, can_opt_out => 1, default_can_use => 1, csm_rec => $csm{SMS} },
                                    $method{'Email'} => { method => $method_recs{'Email'}, can_opt_out => 1, default_can_use => 1, csm_rec => $csm{Email} },
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_opt_out => 1, default_can_use => 0, csm_rec => $csm{Phone} },
                                    $method{'Document'} => { method => $method_recs{'Document'}, can_opt_out => 0, default_can_use => 0, csm_rec => $csm{Document} },
                                }, "'get_enabled_methods' Hash is as Expected" );
            $subj_methods   = $csm_subject->get_enabled_methods( { opt_outable_only => 1 } );
            is_deeply( $subj_methods, {
                                    $method{'SMS'}  => { method => $method_recs{'SMS'}, can_opt_out => 1, default_can_use => 1, csm_rec => $csm{SMS} },
                                    $method{'Email'} => { method => $method_recs{'Email'}, can_opt_out => 1, default_can_use => 1, csm_rec => $csm{Email} },
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_opt_out => 1, default_can_use => 0, csm_rec => $csm{Phone} },
                                }, "'get_enabled_methods' Hash is as Expected when called with 'opt_outable_only' flag" );
            $method_recs{'SMS'}->update( { enabled => 0 } );
            $subj_methods   = $csm_subject->get_enabled_methods( { opt_outable_only => 1 } );
            is_deeply( $subj_methods, {
                                    $method{'Email'} => { method => $method_recs{'Email'}, can_opt_out => 1, default_can_use => 1, csm_rec => $csm{Email} },
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_opt_out => 1, default_can_use => 0, csm_rec => $csm{Phone} },
                        }, "'get_enabled_methods' didn't return SMS when SMS is disabled on the 'correspondence_method' table" );
            $csm{'Email'}->update( { enabled => 0 } );
            $subj_methods   = $csm_subject->get_enabled_methods( { opt_outable_only => 1 } );
            is_deeply( $subj_methods, {
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_opt_out => 1, default_can_use => 0, csm_rec => $csm{Phone} },
                        }, "'get_enabled_methods' didn't return Email when Email is disabled on the 'correspondence_subject_method' table" );
            $subj_methods   = $csm_subject->get_enabled_methods;
            is_deeply( $subj_methods, {
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_opt_out => 1, default_can_use => 0, csm_rec => $csm{Phone} },
                                    $method{'Document'} => { method => $method_recs{'Document'}, can_opt_out => 0, default_can_use => 0, csm_rec => $csm{Document} },
                                }, "'get_enabled_methods' doesn't return any Disabled Methods when called without 'opt_outable_only' flag" );
            # Re-Enable Methods
            $method_recs{'SMS'}->update( { enabled => 1 } );
            $csm{'Email'}->update( { enabled => 1 } );
            $method_recs{'SMS'}->discard_changes;       # this makes future is_deeply tests work

            note "Test Changing Method Preferences";

            # set-up some tests to change settings and then test what is now
            # on the record, if no 'expected' assume the same as 'to_change'
            my @tests   = (
                    {
                        label => 'SMS On, Phone Off, Nothing else set',
                        to_change => {
                            $method{'SMS'} => 1,
                            $method{'Phone'} => 0,
                        },
                    },
                    {
                        label => 'SMS Off',
                        to_change => {
                            $method{'SMS'} => 0,
                        },
                        expected => {
                            $method{'SMS'} => 0,
                            $method{'Phone'} => 0,
                        },
                    },
                    {
                        label => 'SMS Off Again',
                        to_change => {
                            $method{'SMS'} => 0,
                        },
                        expected => {
                            $method{'SMS'} => 0,
                            $method{'Phone'} => 0,
                        },
                        no_changes  => 1,
                    },
                    {
                        label => 'Use Method not Associated with the Subject',
                        to_change => {
                            $method{'Label'} => 1,
                        },
                        expected => {           # no changes should happend
                            $method{'SMS'} => 0,
                            $method{'Phone'} => 0,
                        },
                        no_changes  => 1,
                    },
                    {
                        label => 'Use Method not Allowed to be Changed with the Subject',
                        to_change => {
                            $method{'Document'} => 1,
                        },
                        expected => {           # no changes should happend
                            $method{'SMS'} => 0,
                            $method{'Phone'} => 0,
                        },
                        no_changes  => 1,
                    },
                    {
                        label => 'Email Off',
                        to_change => {
                            $method{'Email'} => 0,
                        },
                        expected => {
                            $method{'SMS'} => 0,
                            $method{'Phone'} => 0,
                            $method{'Email'} => 0,
                        },
                    },
                    {
                        label => 'All On',
                        to_change => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 1,
                            $method{'Phone'} => 1,
                        },
                    },
                    {
                        label => 'All Off',
                        to_change => {
                            $method{'SMS'} => 0,
                            $method{'Email'} => 0,
                            $method{'Phone'} => 0,
                        },
                    },
                );

            foreach my $test ( @tests ) {
                note $test->{label};
                cmp_ok( $order->change_csm_preference( $csm_subject->id, $test->{to_change} ), '==', ( $test->{no_changes} ? 0 : 1 ),
                                                                (
                                                                    $test->{no_changes}
                                                                    ? "NO Changes made method returned FALSE"
                                                                    : "Changes made method returned TRUE"
                                                                ) );
                $test->{expected}   //= $test->{to_change};
                my $got = _get_csm_preferences( $order->orders_csm_preferences_rs, $csm_subject->id );
                is_deeply( $got, $test->{expected}, "Changed as Expected" );
            }


            note "Testing Cascading Customer Preference Changes to Un-Dispatched Orders";
            $order->orders_csm_preferences->delete;     # delete from Order all Preferences

            # set-up some tests to change settings and then test what is now
            # on the record, if no 'cust_expected' assume the same as 'to_change'
            # if no 'ord_expected' assume the same as 'cust_expected'
            @tests  = (
                    {
                        label => 'SMS Off, Email Off',
                        to_change => {
                            $method{'SMS'} => 0,
                            $method{'Email'} => 0,
                        },
                    },
                    {
                        label => 'SMS On',
                        to_change => {
                            $method{'SMS'} => 1,
                        },
                        cust_expected => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 0,
                        }
                    },
                    {
                        label => 'Email On with a Dispatched Order, no Cascade',
                        to_change => {
                            $method{'Email'} => 1,
                        },
                        cust_expected => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 1,
                        },
                        ord_expected => {       # no change expected with Order's Preferences
                            $method{'SMS'} => 1,
                            $method{'Email'} => 0,
                        },
                        shipment_status => $SHIPMENT_STATUS__DISPATCHED,
                    },
                    {
                        label => 'Email On with an Un-Dispatched Order, still no Cascade',
                        to_change => {
                            $method{'Email'} => 1,
                        },
                        cust_expected => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 1,
                        },
                        # no change expected because Customer's Preferences
                        # haven't changed so NO Cascade should happen
                        ord_expected => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 0,
                        },
                        shipment_status => $SHIPMENT_STATUS__PROCESSING,
                    },
                    {
                        label => 'Phone On which should Cascade all Preferences',
                        to_change => {
                            $method{'Phone'} => 1,
                        },
                        # this should be the same for the Order as at least one
                        # change happened so all Customer's Prefs should Cascade
                        cust_expected => {
                            $method{'SMS'} => 1,
                            $method{'Email'} => 1,
                            $method{'Phone'} => 1,
                        },
                    },
                );

            foreach my $test ( @tests ) {
                note $test->{label};
                if ( $test->{shipment_status} ) {
                    $shipment->shipment_status_logs->delete;        # clear out previous statuses
                    $shipment->update_status( $test->{shipment_status}, $APPLICATION_OPERATOR_ID );
                }
                $customer->change_csm_preference( $csm_subject->id, $test->{to_change} );
                $test->{cust_expected}  //= $test->{to_change};
                $test->{ord_expected}   //= $test->{cust_expected};
                my $got = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id );
                is_deeply( $got, $test->{cust_expected}, "Customer Changes Changed as Expected" );
                $got    = _get_csm_preferences( $order->orders_csm_preferences_rs, $csm_subject->id );
                is_deeply( $got, $test->{ord_expected}, "Order Changes Changed as Expected" );
            }


            note "Testing 'get_csm_preferences' method";

            $customer->discard_changes->customer_csm_preferences->delete;
            $order->discard_changes->orders_csm_preferences->delete;

            my $prefs   = $customer->get_csm_preferences( $csm_subject->id );
            ok( !defined $prefs, "method returns 'undef' when NO Preferences Found" );

            $customer->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 1,
                                                        $method{'Email'}=> 0,
                                                        $method{'Phone'}=> 1,
                                                    } );
            $prefs          = $customer->get_csm_preferences( $csm_subject->id );
            my $pref_recs   = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id, { want_records => 1 } );
            isa_ok( $prefs, 'HASH', "method returns as Expected when there ARE Preferences" );
            $prefs->{ $_ }{pref_rec}->discard_changes       foreach ( keys %{ $prefs } );       # is_deeply won't work otherwise
            is_deeply( $prefs, {
                                $method{'SMS'} => { method => $method_recs{'SMS'}, can_use => 1, pref_rec => $pref_recs->{ $method{'SMS'} }  },
                                $method{'Email'} => { method => $method_recs{'Email'}, can_use => 0, pref_rec => $pref_recs->{ $method{'Email'} } },
                                $method{'Phone'} => { method => $method_recs{'Phone'}, can_use => 1, pref_rec => $pref_recs->{ $method{'Phone'} } },
                            }, "method returned with the Expected Preferences" );


            note "Testing 'get_csm_available_to_change' method";

            # create a new subject on the same Sales Channel as before
            my $new_subject = $channel->create_related( 'correspondence_subjects', { subject => 'New Subject '.$$, description => 'Description' } );
            # create a new subject on an Alternative Channel
            my $alt_subject = $alt_channel->create_related( 'correspondence_subjects', { subject => 'New Alt Subject '.$$, description => 'Description' } );

            $customer->discard_changes->customer_csm_preferences->delete;
            $order->discard_changes->orders_csm_preferences->delete;

            ok( !defined $order->get_csm_available_to_change( $new_subject->id ), "method returns 'undef' when NO Methods Available" );
            $prefs  = $order->get_csm_available_to_change( $csm_subject->id );
            isa_ok( $prefs, 'HASH', "method returns as Expected when there ARE Methods available" );
            is_deeply( $prefs, {
                            $method{'SMS'}  => { method => $method_recs{'SMS'}, can_use => 1, default_can_use => 1 },
                            $method{'Email'}  => { method => $method_recs{'Email'}, can_use => 1, default_can_use => 1 },
                            $method{'Phone'}  => { method => $method_recs{'Phone'}, can_use => 0, default_can_use => 0 },
                        }, "method returned with Expected Available Methods when NO Preferences have been set with 'can_use' set with Defaults" );

            # disable the Subject
            $csm_subject->update( { enabled => 0 } );
            $prefs  = $order->get_csm_available_to_change( $csm_subject->id );
            ok( !defined $order->get_csm_available_to_change( $csm_subject->id ), "method returns 'undef' when Subject is Disabled" );
            $csm_subject->update( { enabled => 1 } );       # Re-enable subject

            # set some Preferences
            $customer->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 0,
                                                        $method{'Email'}=> 1,
                                                        $method{'Phone'}=> 0,
                                                    } );
            $prefs  = $order->get_csm_available_to_change( $csm_subject->id );
            is_deeply( $prefs, {
                            $method{'SMS'} => { method => $method_recs{'SMS'}, can_use => 0, default_can_use => 1 },
                            $method{'Email'} => { method => $method_recs{'Email'}, can_use => 1, default_can_use => 1 },
                            $method{'Phone'} => { method => $method_recs{'Phone'}, can_use => 0, default_can_use => 0 },
                        }, "method returned with Expected Available Methods when Preferences HAVE been set" );

            # now test by not passing a Subject Id and getting back all Subjects but only the ones for the correct Sales Channel
            _add_csm_method( $new_subject, { method_id => $method{'SMS'}, can_opt_out => 1, default_can_use => 1 } );
            _add_csm_method( $alt_subject, { method_id => $method{'SMS'}, can_opt_out => 1, default_can_use => 1 } );
            $prefs  = $order->get_csm_available_to_change();
            isa_ok( $prefs, 'HASH', "method returns as Expected when NO Subject Id is passed" );

            foreach my $subject_id ( keys %{ $prefs } ) {
                # get rid of any Subjects that the Test hasn't created so 'is_deeply' will work
                if ( $subject_id != $csm_subject->id
                     && $subject_id != $new_subject->id
                     && $subject_id != $alt_subject->id ) {
                    delete $prefs->{ $subject_id };
                    next;
                }
                # seem to need to do this in order for 'is_deeply' to match
                # as the DBIC record low-level data will differ otherwise
                $prefs->{ $subject_id }{subject}->discard_changes;
            }

            is_deeply( $prefs, {
                            $csm_subject->id => {
                                subject => $csm_subject->discard_changes,
                                methods => {
                                    $method{'SMS'} => { method => $method_recs{'SMS'}, can_use => 0, default_can_use => 1 },
                                    $method{'Email'} => { method => $method_recs{'Email'}, can_use => 1, default_can_use => 1 },
                                    $method{'Phone'} => { method => $method_recs{'Phone'}, can_use => 0, default_can_use => 0 },
                                },
                            },
                            $new_subject->id => {
                                subject => $new_subject->discard_changes,
                                methods => {
                                    $method{'SMS'} => { method => $method_recs{'SMS'}, can_use => 1, default_can_use => 1 },
                                },
                            },
                        }, "method returned with Expected Available Subjects & Methods when NO Subject Id passed to it" );


            note "Testing 'ui_change_csm_available_by_subject' method";

            $customer->discard_changes->customer_csm_preferences->delete;
            $order->discard_changes->orders_csm_preferences->delete;

            # only specifying 1 method should end up creating all opt-outable
            # methods with the others set to Off.
            my $result  = $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                            $method{'Phone'}  => 1,
                                                                        } );
            cmp_ok( $result, '==', 1, "changes made so method returned TRUE" );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 0,
                                $method{'Email'}    => 0,
                                $method{'Phone'}    => 1,
                            }, "One Method Preference specified all Other Methods created as well set to OFF" );
            $result = $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                            $method{'Phone'}  => 1,
                                                                        } );
            cmp_ok( $result, '==', 0, "same changes made again so method returned FALSE" );

            # Disable Subject
            $csm_subject->update( { enabled => 0 } );
            $result = $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                            $method{'Phone'}  => 0,
                                                                        } );
            cmp_ok( $result, '==', 0, "method called when Subject is Disabled no changes made" );
            $csm_subject->update( { enabled => 1 } );

            # Disable a Method
            $method_recs{'Phone'}->update( { enabled => 0 } );
            $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                    $method{'SMS'}  => 1,
                                                                } );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 1,
                                $method{'Email'}    => 0,
                                $method{'Phone'}    => 1,
                            }, "When a Method is Disabled it's Preference is left alone when method called" );
            $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                    $method{'Phone'}  => 0,
                                                                } );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 0,
                                $method{'Email'}    => 0,
                                $method{'Phone'}    => 1,
                            }, "Even when Disabled Method used Explicitly its Preference is left alone" );
            $method_recs{'Phone'}->update( { enabled => 1 } );

            # setting a different method's preference should end up only
            # changing that method and the others should be all turned Off
            $customer->ui_change_csm_available_by_subject( $csm_subject->id, {
                                                                    $method{'SMS'}  => 1,
                                                                } );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $csm_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 1,
                                $method{'Email'}    => 0,
                                $method{'Phone'}    => 0,
                            }, "One Method Preference specfied to be changed, all other methods set to OFF" );

            # just passing in the Subject Id will set preferences for
            # all opt-outable methods associated with it to be Off
            $customer->ui_change_csm_available_by_subject( $new_subject->id );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $new_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 0,
                            }, "Only pass Subject Id in & All Method Preference should be OFF" );

            # assign a new Method for the Subject and call again updating only the
            # previous Method and the new Method should be created and set to Off
            _add_csm_method( $new_subject, { method_id => $method{'Email'}, can_opt_out => 1, default_can_use => 1 } );
            $customer->ui_change_csm_available_by_subject( $new_subject->id, {
                                                                    $method{'SMS'} => 1,
                                                                } );
            $prefs  = _get_csm_preferences( $customer->customer_csm_preferences_rs, $new_subject->id );
            is_deeply( $prefs,{
                                $method{'SMS'}      => 1,
                                $method{'Email'}    => 0,
                            }, "Having associated a new Method, Updating only the Old Method results in the New one being set as well and turned Off" );

            # use an unknown Subject Id and it shouldn't die
            lives_ok { $customer->ui_change_csm_available_by_subject( -1 ) } "With an Unknown Subject Id method doesn't die";


            # rollback changes
            $schema->txn_rollback;
        } );
        _reload_methods();
    };

    return;
}

# test that a preference 'can be used'
# for a method and subject
sub _test_can_use_preference {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_can_use_preference", 1              if ( !$oktodo );

        note "in '_test_can_use_preference'";

        my $framework   = Test::XT::Data->new_with_traits(
                traits => [ 'Test::XT::Data::Order' ],
        );

        $schema->txn_do( sub {
            # create an order
            my ( $channel, $customer, $order, $shipment )   = _create_an_order( $framework, { dispatched => 1 } );
            # get an Alternative Sales Channel
            my $alt_channel = $schema->resultset('Public::Channel')
                                        ->search( { id => { '!=' => $channel->id } } )->first;

            my $return  = _create_return( $domain, $shipment );
            note "Return RMA/Id: ".$return->rma_number."/".$return->id;

            # make sure all Methods are Enabled
            foreach my $method ( values %method_recs ) {
                $method->update( { enabled => 1 } );
                $method->discard_changes;               # to make is_deeply tests work
            }

            # delete any Correspondence Subject Method (CSM) Preferences for the Customer/Order
            $customer->customer_csm_preferences->delete;
            $customer->customer_correspondence_method_preferences->delete;
            $customer->update( { correspondence_default_preference => undef } );
            $order->orders_csm_preferences->delete;

            my @recs    = (
                    $customer,
                    $order,
                    $shipment,
                    $return
                );

            # create a Correspondence Subject to use in the test
            my $csm_subject = _create_subject( $channel );
            # create an alternative Subject will have the same
            # name as above and shouldn't interfere with anything
            my $alt_subject = _create_subject( $alt_channel );

            # get all the CSM recs for the main Subject
            my %csm_recs    = map { $_->correspondence_method->method => $_ } $csm_subject->correspondence_subject_methods->all;

            $channel->discard_changes;
            $alt_channel->discard_changes;

            _check_required_params( $customer, $csm_subject );


            note "Testing 'get_correspondence_subject' method on Channel Class";

            my $got = $channel->get_correspondence_subject( $csm_subject->subject );
            isa_ok( $got, 'XTracker::Schema::Result::Public::CorrespondenceSubject', "Found a Subject Record" );
            cmp_ok( $got->id, '==', $csm_subject->id, "Subject Record is the Correct Record" );
            $got    = $channel->get_correspondence_subject( "Subject Shouldn't Exist klsjdfkjlsa;lf" );
            ok( !defined $got, "Got 'undef' back when looking for a Non-Existing Subject" );
            $alt_subject->update( { subject => 'Another Subject Name'.$$ } );
            $got    = $channel->get_correspondence_subject( $alt_subject->subject );
            ok( !defined $got, "Got 'undef' back when looking for an Existing Subject but for a Different Channel" );
            $alt_subject->update( { subject => $csm_subject->subject } );       # update the name back again


            note "Testing 'csm_prefs_allow_method' method";

            note "when there are NO Preferences at all set";
            _test_do_prefs_allow( $_, $csm_subject, 'SMS', undef, 0 )   foreach ( @recs );

            note "when there are Preferences on the Customer only: SMS - Y, Email - N, Phone - Y";
            $customer->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 1,
                                                        $method{'Email'}=> 0,
                                                        $method{'Phone'}=> 1,
                                                    } );
            _test_do_prefs_allow( $_, $csm_subject, 'SMS', 1 )          foreach ( @recs );
            _test_do_prefs_allow( $_, $csm_subject, 'Email', 0 )        foreach ( @recs );
            _test_do_prefs_allow( $_, $csm_subject, 'Phone', 1 )        foreach ( @recs );

            note "when there are some Preferences for the Order as well: SMS - N, Email - Y";
            $order->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 0,
                                                        $method{'Email'}=> 1,
                                                    } );
            _test_do_prefs_allow( $customer, $csm_subject, 'SMS', 1 );
            _test_do_prefs_allow( $customer, $csm_subject, 'Email', 0 );
            _test_do_prefs_allow( $_, $csm_subject, 'SMS', 0 )         foreach ( $order, $shipment, $return );
            _test_do_prefs_allow( $_, $csm_subject, 'Email', 1 )       foreach ( $order, $shipment, $return );
            _test_do_prefs_allow( $_, $csm_subject, 'Phone', 1 )       foreach ( @recs );


            note "Testing 'csm_default_prefs_allow_method' method on the Customer class";

            $customer->discard_changes;
            $customer->create_related( 'customer_correspondence_method_preferences', { correspondence_method_id => $method{'SMS'}, can_use => 0 } );
            $customer->create_related( 'customer_correspondence_method_preferences', { correspondence_method_id => $method{'Email'}, can_use => 1 } );

            cmp_ok( $customer->csm_default_prefs_allow_method( $method_recs{'SMS'} ), '==', 0,
                                                "Customer Default for 'SMS' is can NOT be sent" );
            cmp_ok( $customer->csm_default_prefs_allow_method( $method_recs{'Email'} ), '==', 1,
                                                "Customer Default for 'Email' is CAN be sent" );
            ok( !defined $customer->csm_default_prefs_allow_method( $method_recs{'Phone'} ),
                                                "Customer Default for Un-specified Method 'Phone' is 'undef'" );

            note "update 'correspondence_default_preference' field on Customer table";
            # the 'correspondence_default_preference' field acts as a general Default
            # Preference for Correspondence Method's not specified any where else
            $customer->update( { correspondence_default_preference => 1 } );
            cmp_ok( $customer->csm_default_prefs_allow_method( $method_recs{'Phone'} ), '==', 1,
                                                "Customer Overall Default for Un-specified Method 'Phone' is CAN be sent" );
            $customer->update( { correspondence_default_preference => 0 } );
            cmp_ok( $customer->csm_default_prefs_allow_method( $method_recs{'Phone'} ), '==', 0,
                                                "Customer Overall Default for Un-specified Method 'Phone' is can NOT be sent" );

            note "test '_test_do_prefs_allow' with Defaults Set and Not Set for the Customer for a new Method assigned to a Subject";

            # assign a new Method for the Subject
            my $label_csm_rec   = _add_csm_method( $csm_subject, { method_id => $method{'Label'}, can_opt_out => 1, default_can_use => 0 } );
            $customer->update( { correspondence_default_preference => undef } );
            _test_do_prefs_allow( $_, $csm_subject, 'Label', undef )    foreach ( @recs );  # no defaults set
            $customer->update( { correspondence_default_preference => 0 } );
            _test_do_prefs_allow( $_, $csm_subject, 'Label', 0 )        foreach ( @recs );  # default being CANT use
            $customer->update( { correspondence_default_preference => 1 } );
            _test_do_prefs_allow( $_, $csm_subject, 'Label', 1 )        foreach ( @recs );  # default being CAN use

            note "test '_test_do_prefs_allow' with 'customer_correspondence_method_preferences' overiding 'correspondence_default_preference'";
            $customer->create_related( 'customer_correspondence_method_preferences', { correspondence_method_id => $method{'Label'}, can_use => 0 } );
            _test_do_prefs_allow( $_, $csm_subject, 'Label', 0 )        foreach ( @recs );  # should now be CANT use

            # test Email again should still be the same as before because there are existing Preferences in place
            _test_do_prefs_allow( $customer, $csm_subject, 'Email', 0 );
            $customer->customer_correspondence_method_preferences->update( { can_use => 0 } );  # settings should
            $customer->update( { correspondence_default_preference => 0 } );                    # be ignored
            _test_do_prefs_allow( $_, $csm_subject, 'Email', 1 )        foreach ( $order, $shipment, $return );


            note "Testing 'can_use_csm' method";

            # delete any Correspondence Subject Method (CSM) Preferences for the Customer/Order
            $customer->customer_csm_preferences->delete;
            $customer->customer_correspondence_method_preferences->delete;
            $customer->update( { correspondence_default_preference => undef } );
            $order->orders_csm_preferences->delete;
            $label_csm_rec->delete;     # delete the 'Label' method assigned to the Subject

            note "when there are NO Preferences at all set use 'default_can_use' values";
            _test_can_use_csm( $_, $csm_subject, 'SMS', 1 )         foreach ( @recs );
            _test_can_use_csm( $_, $csm_subject, 'Phone', 0 )       foreach ( @recs );

            note "when there are Preferences on the Customer only: SMS - Y, Email - N";
            $customer->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 1,
                                                        $method{'Email'}=> 0,
                                                    } );
            _test_can_use_csm( $_, $csm_subject, 'SMS', 1 )         foreach ( @recs );
            _test_can_use_csm( $_, $csm_subject, 'Email', 0 )       foreach ( @recs );
            _test_can_use_csm( $_, $csm_subject, 'Phone', 0 )       foreach ( @recs );      # still using Default

            note "Disable Subject then CAN'T use SMS";
            $csm_subject->update( { enabled => 0 } );
            _test_can_use_csm( $_, $csm_subject, 'SMS', 0 )         foreach ( @recs );
            $csm_subject->update( { enabled => 1 } );

            note "Disable SMS Method then CAN'T use it";
            $method_recs{'SMS'}->update( { enabled => 0 } );
            _test_can_use_csm( $_, $csm_subject, 'SMS', 0 )         foreach ( @recs );
            $method_recs{'SMS'}->update( { enabled => 1 } );

            note "when passed a Method which you CAN'T Opt Out of using for a Subject";
            _test_can_use_csm( $_, $csm_subject, 'Document', 1 )    foreach ( @recs );
            note "when passed a Method which is NOT assigned to the Subject";
            _test_can_use_csm( $_, $csm_subject, 'Label', 0 )       foreach ( @recs );

            note "when there are some Preferences for the Order: SMS - N, Email - Y and the Customer has: SMS - Y, Email - N, Phone - Y";
            $customer->change_csm_preference( $csm_subject->id, { $method{'Phone'} => 1 } );
            $order->change_csm_preference( $csm_subject->id, {
                                                        $method{'SMS'}  => 0,
                                                        $method{'Email'}=> 1,
                                                    } );
            _test_can_use_csm( $customer, $csm_subject, 'SMS', 1 );
            _test_can_use_csm( $customer, $csm_subject, 'Email', 0 );
            _test_can_use_csm( $_, $csm_subject, 'SMS', 0 )         foreach ( $order, $shipment, $return );
            _test_can_use_csm( $_, $csm_subject, 'Email', 1 )       foreach ( $order, $shipment, $return );
            _test_can_use_csm( $_, $csm_subject, 'Phone', 1 )       foreach ( @recs );

            note "Disable CSM Records for Methods even if you can't opt out of them so they Can't be Used";
            $csm_recs{'Document'}->discard_changes->update( { enabled => 0 } );
            $csm_recs{'Phone'}->discard_changes->update( { enabled => 0 } );
            _test_can_use_csm( $_, $csm_subject, 'Document', 0 )    foreach ( @recs );
            _test_can_use_csm( $_, $csm_subject, 'Phone', 0 )       foreach ( @recs );


            # rollback changes
            $schema->txn_rollback;
        } );
        _reload_methods();
    };

    return;
}

# tests the CSM Exclusion Calendar, to make sure
# a Subject for a Method can't be sent at certain times
sub _test_csm_exclusion_calendar {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_csm_exclusion_calendar", 1              if ( !$oktodo );

        note "in '_test_csm_exclusion_calendar'";

        my $channel = Test::XTracker::Data->channel_for_nap;
        my $now     = DateTime->now( time_zone => 'local' );

        $schema->txn_do( sub {
            # create a Correspondence Subject to use in the test
            my $csm_subject = _create_subject( $channel );
            # get a couple of these recs, doesn't matter which
            my ( $csm_rec, $alt_csm )   = $csm_subject->correspondence_subject_methods->all;

            throws_ok { $csm_rec->window_open_to_send() } qr/No DateTime parameter/,
                                                    "'window_open_to_send' dies when NO DateTime parameter is passed to it";
            throws_ok { $csm_rec->window_open_to_send( [ 1 ] ) } qr/NOT a DateTime object/,
                                                    "'window_open_to_send' dies when a NON DateTime parameter is passed to it";

            my $result  = $csm_rec->window_open_to_send( $now );
            ok( $result, "'window_open_to_send' with No Exclusion Calendar Recs returned a Defined Value" );
            cmp_ok( $result, '==', 1, "'window_open_to_send' with No Exclusion Calendar Recs returned TRUE" );

            # add a Exclusion Calendar for the Whole Year to another
            # Method that should have NO effect on the rest of the tests
            _add_cal_exclusion( $alt_csm, { start_date => '01/01', end_date => '31/12' } );
            $result = $csm_rec->window_open_to_send( $now );
            ok( $result, "Other Method has Year Excluded, 'window_open_to_send' with No Exclusion Calendar Recs returned a Defined Value" );
            cmp_ok( $result, '==', 1, "Other Method has Year Excluded, 'window_open_to_send' with No Exclusion Calendar Recs returned TRUE" );

            # create test data
            my %tests   = (
                    #
                    # Test Single Calendar Field Group, Time, Date or Day of Week on One Record
                    #
                    "Single Field: Start Time Only '21:00:00' and go till Midnight"   => {
                            calendar    => {
                                    start_time  => '21:00:00',
                                },
                            test_time   => [
                                    { time => '21:00:00', expected => 0 },
                                    { time => '23:59:59', expected => 0 },
                                    { time => '20:59:59', expected => 1 },
                                    { time => '00:00:00', expected => 1 },
                                ],
                        },
                    "Single Field: End Time Only '21:00:00' and start from Midnight"  => {
                            calendar    => {
                                    end_time  => '21:00:00',
                                },
                            test_time   => [
                                    { time => '21:00:00', expected => 0 },
                                    { time => '23:59:59', expected => 1 },
                                    { time => '21:00:01', expected => 1 },
                                    { time => '00:00:00', expected => 0 },
                                ],
                        },
                    "Single Field: Start & End Time within same day '21:00:00' to '22:00:04'" => {
                            calendar    => {
                                    start_time  => '21:00:00',
                                    end_time  => '22:00:04',
                                },
                            test_time   => [
                                    { time => '21:00:00', expected => 0 },
                                    { time => '23:59:59', expected => 1 },
                                    { time => '21:45:14', expected => 0 },
                                    { time => '22:00:04', expected => 0 },
                                    { time => '22:00:05', expected => 1 },
                                    { time => '00:00:00', expected => 1 },
                                ],
                        },
                    "Single Field: Start & End Time are the same '21:00:00'" => {
                            calendar    => {
                                    start_time  => '21:00:00',
                                    end_time    => '21:00:00',
                                },
                            test_time   => [
                                    { time => '20:59:59', expected => 1 },
                                    { time => '21:00:00', expected => 0 },
                                    { time => '21:00:01', expected => 1 },
                                ],
                        },
                    "Single Field: Start & End Time are both Midnight, check doesn't Block the Whole Day Out" => {
                            calendar    => {
                                    start_time  => '00:00:00',
                                    end_time    => '00:00:00',
                                },
                            test_time   => [
                                    { time => '00:00:00', expected => 0 },
                                    { time => '21:00:00', expected => 1 },
                                    { time => '00:00:01', expected => 1 },
                                    { time => '23:59:59', expected => 1 },
                                    { time => '12:00:00', expected => 1 },
                                ],
                        },
                    "Single Field: Start & End Time crosses a day '21:01:07' to '05:32:01'" => {
                            calendar    => {
                                    start_time  => '21:01:07',
                                    end_time  => '05:32:01',
                                },
                            test_time   => [
                                    { time => '21:01:06', expected => 1 },
                                    { time => '21:01:07', expected => 0 },
                                    { time => '23:59:59', expected => 0 },
                                    { time => '00:00:00', expected => 0 },
                                    { time => '05:32:01', expected => 0 },
                                    { time => '05:32:02', expected => 1 },
                                    { time => '12:56:02', expected => 1 },
                                ],
                        },
                    "Single Field: Exact Start Date Only '23/03/2014'"  => {
                            calendar    => {
                                    start_date => '23/03/2014',
                                },
                            test_time   => [
                                    { date => '22/03/2014', expected => 1 },
                                    { date => '23/03/2014', expected => 0 },
                                    { date => '24/03/2014', expected => 1 },
                                    { date => '23/03/2013', expected => 1 },
                                    { date => '23/02/2014', expected => 1 },
                                ],
                        },
                    "Single Field: Exact End Date Only '23/03/2014'"  => {
                            calendar    => {
                                    end_date => '23/03/2014',
                                },
                            same_as => "Single Field: Exact Start Date Only '23/03/2014'",
                        },
                    "Single Field: Exact Start & End Date Only that are the Same 23/03/2014'"  => {
                            calendar    => {
                                    start_date  => '23/03/2014',
                                    end_date    => '23/03/2014',
                                },
                            same_as => "Single Field: Exact Start Date Only '23/03/2014'",
                        },
                    "Single Field: Exact Start & End Date '23/03/2014' to '22/04/2014'" => {
                            calendar    => {
                                    start_date => '23/03/2014',
                                    end_date => '22/04/2014',
                                },
                            test_time   => [
                                    { date => '22/03/2014', expected => 1 },
                                    { date => '23/03/2014', expected => 0 },
                                    { date => '14/04/2014', expected => 0 },
                                    { date => '22/04/2014', expected => 0 },
                                    { date => '23/04/2014', expected => 1 },
                                    { date => '14/04/2015', expected => 1 },
                                ],
                        },
                    "Single Field: Exact Start & End Date Crosses a Year '23/12/2014' to '22/01/2015'" => {
                            calendar    => {
                                    start_date => '23/12/2014',
                                    end_date => '22/01/2015',
                                },
                            test_time   => [
                                    { date => '22/12/2014', expected => 1 },
                                    { date => '23/12/2014', expected => 0 },
                                    { date => '27/12/2014', expected => 0 },
                                    { date => '14/01/2015', expected => 0 },
                                    { date => '22/01/2015', expected => 0 },
                                    { date => '23/01/2015', expected => 1 },
                                ],
                        },
                    "Single Field: Day/Month Start Date Only '23/03'"  => {
                            calendar    => {
                                    start_date => '23/03',
                                },
                            test_time   => [
                                    { date => '22/03', expected => 1 }, # will use today's year
                                    { date => '23/03', expected => 0 },
                                    { date => '24/03', expected => 1 },
                                    { date => '23/03/2013', expected => 0 },
                                    { date => '23/03/2014', expected => 0 },
                                    { date => '23/02/2013', expected => 1 },
                                ],
                        },
                    "Single Field: Day/Month End Date Only '23/03'"  => {
                            calendar    => {
                                    end_date => '23/03',
                                },
                            same_as => "Single Field: Day/Month Start Date Only '23/03'",
                        },
                    "Single Field: Day/Month Start & End Date '23/03' to '24/04'"   => {
                            calendar    => {
                                    start_date => '23/03',
                                    end_date => '24/04',
                                },
                            test_time   => [
                                    { date => '22/03', expected => 1 },
                                    { date => '23/03', expected => 0 },
                                    { date => '03/04', expected => 0 },
                                    { date => '24/04', expected => 0 },
                                    { date => '25/04', expected => 1 },
                                    { date => '27/03/2014', expected => 0 },
                                    { date => '17/04/2013', expected => 0 },
                                    { date => '01/02/2014', expected => 1 },
                                    { date => '25/04/2014', expected => 1 },
                                ],
                        },
                    "Single Field: Day/Month Start & End Date Crosses a Year '23/12' to '22/01'" => {
                            calendar    => {
                                    start_date => '23/12',
                                    end_date => '22/01',
                                },
                            same_as     => "Single Field: Exact Start & End Date Crosses a Year '23/12/2014' to '22/01/2015'",
                        },
                    "Single Field: Day of the Week Only 'Monday'"  => {
                            calendar    => {
                                    day_of_week => '1',
                                },
                            test_time   => [
                                    { date => '02/06/2014', expected => 0 },
                                    { date => '03/06/2014', expected => 1 },
                                    { date => '01/06/2014', expected => 1 },
                                ],
                        },
                    "Single Field: Day of the Week Only 'Sunday'"  => {
                            calendar    => {
                                    day_of_week => '7',
                                },
                            test_time   => [
                                    { date => '08/06/2014', expected => 0 },
                                    { date => '09/06/2014', expected => 1 },
                                    { date => '07/06/2014', expected => 1 },
                                ],
                        },
                    "Single Field: Day of the Week Only 'Thursday'"  => {
                            calendar    => {
                                    day_of_week => '4',
                                },
                            test_time   => [
                                    { date => '05/06/2014', expected => 0 },
                                    { date => '06/06/2014', expected => 1 },
                                    { date => '04/06/2014', expected => 1 },
                                ],
                        },
                    "Single Field: Days of the Week Only 'Tuesday, Thursday, Sunday'"  => {
                            calendar    => {
                                    day_of_week => '2,4,7',
                                },
                            test_time   => [
                                    { date => '01/06/2014', expected => 0 },    # Sun
                                    { date => '02/06/2014', expected => 1 },    # Mon
                                    { date => '03/06/2014', expected => 0 },    # Tue
                                    { date => '04/06/2014', expected => 1 },    # Wed
                                    { date => '05/06/2014', expected => 0 },    # Thu
                                    { date => '06/06/2014', expected => 1 },    # Fri
                                    { date => '07/06/2014', expected => 1 },    # Sat
                                    { date => '08/06/2014', expected => 0 },    # Sun
                                    { date => '09/06/2014', expected => 1 },    # Mon
                                ],
                        },
                    "Single Field: Days of the Week Only, Odd Order 'Sunday, Thursday, Tuesday'"  => {
                            calendar    => {
                                    day_of_week => '7,4,2',
                                },
                            same_as     => "Single Field: Days of the Week Only 'Tuesday, Thursday, Sunday'",
                        },
                    #
                    # Test Multiple Fields on One Calendar Record
                    #
                    "Multiple Fields: Start & End Time '13:00:00' to '15:30:00' every 'Wednesday'" => {
                            calendar    => {
                                    start_time  => '13:00:00',
                                    end_time    => '15:30:00',
                                    day_of_week => '3',
                                },
                            test_time   => [ # 05/03/2014 is a Wednesday
                                    { date => '05/03/2014', time => '13:00:00', expected => 0 },
                                    { date => '05/03/2014', time => '14:45:59', expected => 0 },
                                    { date => '05/03/2014', time => '15:30:00', expected => 0 },
                                    { date => '05/03/2014', time => '15:30:01', expected => 1 },
                                    { date => '05/03/2014', time => '16:30:00', expected => 1 },
                                    { date => '04/03/2014', time => '14:45:59', expected => 1 },
                                ],
                        },
                    "Multiple Fields: Start & End Time '13:00:00' to '15:30:00' between '04/05' to '07/06'" => {
                            calendar    => {
                                    start_time  => '13:00:00',
                                    end_time    => '15:30:00',
                                    start_date  => '04/05',
                                    end_date    => '07/06',
                                },
                            test_time   => [
                                    { date => '04/05', time => '03:00:00', expected => 1 },
                                    { date => '04/05', time => '13:00:00', expected => 0 },
                                    { date => '23/05', time => '14:45:00', expected => 0 },
                                    { date => '23/05', time => '01:45:00', expected => 1 },
                                    { date => '23/05', time => '17:45:00', expected => 1 },
                                    { date => '07/06', time => '15:30:00', expected => 0 },
                                    { date => '08/06', time => '14:45:00', expected => 1 },
                                    { date => '04/05/2014', time => '13:04:00', expected => 0 },
                                ],
                        },
                    "Multiple Fields: Start Time '13:00:00' between '04/05' to '07/06'" => {
                            calendar    => {
                                    start_time  => '13:00:00',
                                    start_date  => '04/05',
                                    end_date    => '07/06',
                                },
                            test_time   => [
                                    { date => '04/05', time => '03:00:00', expected => 1 },
                                    { date => '04/05', time => '13:00:00', expected => 0 },
                                    { date => '23/05', time => '14:45:00', expected => 0 },
                                    { date => '23/05', time => '01:45:00', expected => 1 },
                                    { date => '23/05', time => '17:45:00', expected => 0 },
                                    { date => '07/06', time => '15:30:00', expected => 0 },
                                    { date => '08/06', time => '14:45:00', expected => 1 },
                                    { date => '04/05/2014', time => '18:04:00', expected => 0 },
                                ],
                        },
                    "Multiple Fields: End Time '13:00:00' between '04/05' to '07/06'" => {
                            calendar    => {
                                    end_time  => '13:00:00',
                                    start_date  => '04/05',
                                    end_date    => '07/06',
                                },
                            test_time   => [
                                    { date => '04/05', time => '03:00:00', expected => 0 },
                                    { date => '04/05', time => '13:00:00', expected => 0 },
                                    { date => '23/05', time => '14:45:00', expected => 1 },
                                    { date => '23/05', time => '01:45:00', expected => 0 },
                                    { date => '23/05', time => '17:45:00', expected => 1 },
                                    { date => '07/06', time => '15:30:00', expected => 1 },
                                    { date => '08/06', time => '14:45:00', expected => 1 },
                                    { date => '04/05/2014', time => '08:04:00', expected => 0 },
                                ],
                        },
                    "Multiple Fields: Start Time '13:00:00' every 'Wednesday & Friday'" => {
                            calendar    => {
                                    start_time  => '13:00:00',
                                    day_of_week => '3,5',
                                },
                            test_time   => [
                                    { date => '07/05/2014', time => '08:04:00', expected => 1 },
                                    { date => '07/05/2014', time => '13:00:00', expected => 0 },
                                    { date => '07/05/2014', time => '17:00:00', expected => 0 },
                                    { date => '08/05/2014', time => '13:00:00', expected => 1 },
                                    { date => '08/05/2014', time => '17:00:00', expected => 1 },
                                    { date => '09/05/2014', time => '08:04:00', expected => 1 },
                                    { date => '09/05/2014', time => '13:00:00', expected => 0 },
                                    { date => '09/05/2014', time => '17:00:00', expected => 0 },
                                ],
                        },
                    "Multiple Fields: End Time '13:00:00' every 'Wednesday & Friday'"  => {
                            calendar    => {
                                    end_time  => '13:00:00',
                                    day_of_week => '3,5',
                                },
                            test_time   => [
                                    { date => '07/05/2014', time => '08:04:00', expected => 0 },
                                    { date => '07/05/2014', time => '13:00:00', expected => 0 },
                                    { date => '07/05/2014', time => '17:00:00', expected => 1 },
                                    { date => '08/05/2014', time => '13:00:00', expected => 1 },
                                    { date => '08/05/2014', time => '17:00:00', expected => 1 },
                                    { date => '09/05/2014', time => '08:04:00', expected => 0 },
                                    { date => '09/05/2014', time => '13:00:00', expected => 0 },
                                    { date => '09/05/2014', time => '17:00:00', expected => 1 },
                                ],
                        },
                    "Multiple Fields: End Time '13:00:00' between '04/05' to '07/06' only on 'Monday & Wednesday'" => {
                            calendar    => {
                                    end_time    => '13:00:00',
                                    start_date  => '04/05',
                                    end_date    => '07/06',
                                    day_of_week => '1,3',
                                },
                            test_time   => [
                                    { date => '04/05/2014', time => '03:00:00', expected => 1 },    # Sunday
                                    { date => '05/05/2014', time => '03:00:00', expected => 0 },    # Monday
                                    { date => '05/05/2014', time => '23:00:00', expected => 1 },
                                    { date => '20/05/2014', time => '03:00:00', expected => 1 },    # Tuesday
                                    { date => '21/05/2014', time => '03:00:00', expected => 0 },    # Wednesday
                                    { date => '04/06/2014', time => '03:00:00', expected => 0 },    # Wednesday
                                    { date => '04/06/2014', time => '23:00:00', expected => 1 },
                                    { date => '07/06/2014', time => '08:04:00', expected => 1 },    # Saturday
                                ],
                        },
                    "Multiple Fields: End Time '13:00:00' on '02/06' only if it's a 'Monday'" => {
                            calendar    => {
                                    end_time    => '13:00:00',
                                    start_date  => '02/06',
                                    day_of_week => '1',
                                },
                            test_time   => [
                                    { date => '02/06/2014', time => '03:00:00', expected => 0 },    # Monday
                                    { date => '02/06/2014', time => '23:00:00', expected => 1 },
                                    { date => '02/06/2015', time => '03:00:00', expected => 1 },    # Tuesday
                                ],
                        },
                    "Multiple Fields: Start Date '02/06' Day of Week 'Monday'" => {
                            calendar    => {
                                    start_date  => '02/06',
                                    day_of_week => '1',
                                },
                            test_time   => [
                                    { date => '02/06/2014', time => '03:00:00', expected => 0 },    # Monday
                                    { date => '02/06/2014', time => '23:00:00', expected => 0 },
                                    { date => '02/06/2015', time => '03:00:00', expected => 1 },    # Tuesday
                                ],
                        },
                    "Multiple Fields: Start & End Time '21:30:00' & '03:00:00' and Start Date '02/06'" => {
                            calendar    => {
                                    start_time  => '21:30:00',
                                    end_time    => '03:00:00',
                                    start_date  => '02/06',
                                },
                            test_time   => [
                                    { date => '02/06/2014', time => '03:00:00', expected => 0 },
                                    { date => '02/06/2014', time => '21:30:00', expected => 0 },
                                    { date => '02/06/2014', time => '22:30:00', expected => 0 },
                                    { date => '02/06/2014', time => '01:30:00', expected => 0 },
                                    { date => '01/06/2014', time => '01:30:00', expected => 1 },
                                    { date => '01/06/2014', time => '09:30:00', expected => 1 },
                                    { date => '03/06/2014', time => '01:30:00', expected => 1 },
                                    { date => '03/06/2014', time => '09:30:00', expected => 1 },
                                ],
                        },
                    #
                    # Test Multiple Calendar Records
                    #
                    "Multiple Recs: Rec 1: '05:00:00' to '09:30:00', Rec 2: '01/12' to '02/01', Rec 3: 'Monday & Saturday'" => {
                            calendar    => [
                                    { start_time => '05:00:00', end_time => '09:30:00' },
                                    { start_date => '01/12', end_date => '02/01' },
                                    { day_of_week => '1,6' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 0 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '13:45:59', expected => 0 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 0 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 0 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 0 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    "Multiple Recs: Rec 1: '05:00:00' to '09:30:00', Rec 2: 'Monday & Saturday'" => {
                            calendar    => [
                                    { start_time => '05:00:00', end_time => '09:30:00' },
                                    { day_of_week => '1,6' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 0 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '13:45:59', expected => 0 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 0 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 1 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 1 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    "Multiple Recs: Rec 1: '05:00:00' to '09:30:00', Rec 2: '01/12' to '02/01'" => {
                            calendar    => [
                                    { start_time => '05:00:00', end_time => '09:30:00' },
                                    { start_date => '01/12', end_date => '02/01' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 0 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '13:45:59', expected => 1 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 1 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 0 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 0 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    "Multiple Recs: Rec 1: '01/12' to '02/01', Rec 2: 'Monday & Saturday'" => {
                            calendar    => [
                                    { start_date => '01/12', end_date => '02/01' },
                                    { day_of_week => '1,6' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 1 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '13:45:59', expected => 0 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 0 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 0 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 0 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    "Multiple Recs: Rec 1: '05:00:00' to '09:30:00' and '01/12' to '02/01', Rec 2: 'Monday & Saturday'" => {
                            calendar    => [
                                    { start_time => '05:00:00', end_time => '09:30:00', start_date => '01/12', end_date => '02/01' },
                                    { day_of_week => '1,6' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 1 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '13:45:59', expected => 0 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 0 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 1 },
                                    { date => '30/12/2014', time => '07:00:00', expected => 0 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 1 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    "Multiple Recs: Rec 1: '05:00:00' to '09:30:00' and 'Monday & Saturday', Rec 2: '01/12' to '02/01'" => {
                            calendar    => [
                                    { start_time => '05:00:00', end_time => '09:30:00', day_of_week => '1,6' },
                                    { start_date => '01/12', end_date => '02/01' },
                                ],
                            test_time   => [
                                    { date => '20/11/2014', time => '01:00:00', expected => 1 },
                                    { date => '20/11/2014', time => '05:45:59', expected => 1 },
                                    { date => '20/11/2014', time => '13:45:59', expected => 1 },
                                    { date => '17/11/2014', time => '08:45:59', expected => 0 },    # Monday
                                    { date => '22/11/2014', time => '13:45:59', expected => 1 },    # Saturday
                                    { date => '21/12/2014', time => '01:00:00', expected => 0 },
                                    { date => '30/12/2014', time => '07:00:00', expected => 0 },
                                    { date => '01/01/2015', time => '11:00:00', expected => 0 },
                                    { date => '20/12/2014', time => '06:00:00', expected => 0 },    # also Saturday
                                ],
                        },
                    #
                    # Test Complete Blackout, NOTHING Should be OK
                    #
                    "Blackout: Start & End Time '00:00:00' to '23:59:59'"   => {
                            calendar    => {
                                    start_time  => '00:00:00',
                                    end_time    => '23:59:59',
                                },
                            test_time   => [
                                    { time => '00:00:00', expected => 0 },
                                    { time => '12:00:00', expected => 0 },
                                    { time => '23:59:59', expected => 0 },
                                    { date => '01/12/2014', expected => 0 },    # Monday to Sunday
                                    { date => '02/12/2014', expected => 0 },
                                    { date => '03/12/2014', expected => 0 },
                                    { date => '04/12/2014', expected => 0 },
                                    { date => '05/12/2014', expected => 0 },
                                    { date => '06/12/2014', expected => 0 },
                                    { date => '07/12/2014', expected => 0 },
                                    { expected => 0 },                          # will use whatever NOW is
                                ],
                        },
                    "Blackout: Start & End Date '01/01' to '31/12'"   => {
                            calendar    => {
                                    start_date  => '01/01',
                                    end_date    => '31/12',
                                },
                            same_as     => "Blackout: Start & End Time '00:00:00' to '23:59:59'",
                        },
                    "Blackout: All Days of the Week 'Monday to Sunday'" => {
                            calendar    => {
                                    day_of_week => '1,2,3,4,5,6,7',
                                },
                            same_as     => "Blackout: Start & End Time '00:00:00' to '23:59:59'",
                        },
                    #
                    # Test When Garbage is put in the Table, it should be ignored
                    #
                    "Garbage: Back to Front Exact Dates '21/01/2014' to '05/01/2014' should be Ignored and NOT Swapped Over" => {
                            calendar    => {
                                    start_date  => '21/01/2014',
                                    end_date    => '05/01/2014',
                                },
                            test_time   => [
                                    { date => '17/01/2014', expected => 1 },
                                    { date => '21/01/2014', expected => 1 },
                                    { date => '05/01/2014', expected => 1 },
                                    { date => '04/01/2014', expected => 1 },
                                    { date => '22/01/2014', expected => 1 },
                                ],
                        },
                    "Garbage: Mix of Part Date and Exact Date '21/01' to '23/02/2014', Both Should be Ignored" => {
                            calendar    => {
                                    start_date  => '21/01',
                                    end_date    => '23/02/2014',
                                },
                            test_time   => [
                                    { date => '21/01', expected => 1 },
                                    { date => '21/01/2014', expected => 1 },
                                    { date => '03/02', expected => 1 },
                                    { date => '03/02/2014', expected => 1 },
                                    { date => '23/02', expected => 1 },
                                    { date => '23/02/2014', expected => 1 },
                                ],
                        },
                    "Garbage: Invalid Day of Week '0,8,9,10,12', Should be Ignored" => {
                            calendar    => {
                                    day_of_week => ',0,8,9,10,12,',
                                },
                            test_time   => [
                                    { date => '14/12/2014', expected => 1 },    # Sunday
                                    { date => '15/12/2014', expected => 1 },    # Monday
                                    { date => '16/12/2014', expected => 1 },    # Tuesday
                                    { date => '17/12/2014', expected => 1 },    # Wednesday
                                ],
                        },
                    "Garbage: Date & Day of Week Given don't Match '02/06/2014' is not on a 'Tuesday', Should be Ignored" => {
                            calendar    => {
                                    start_date  => '02/06/2014',
                                    day_of_week => '2',
                                },
                            test_time   => [
                                    { date => '02/06/2014', expected => 1 },
                                    { date => '02/06/2015', expected => 1 },     # is on a Tuesday but wrong Year
                                ],
                        },
                    "Garbage: Mixture of Invalid Dates and Days of Week, Should be Ignored" => {
                            calendar    => [
                                    {
                                        start_date  => '45/04',
                                        end_date  => '32/32',
                                        day_of_week => 'Monday',
                                    },
                                    {
                                        start_date  => '04/25',
                                        end_date  => '25/04',
                                    },
                                    {
                                        start_date  => '04/25/2015',
                                        end_date  => '25/04/2015',
                                    },
                                ],
                            test_time   => [
                                    { date => '25/04', expected => 1 },
                                    { date => '01/06/2015', expected => 1 },     # Monday
                                ],
                        },
                    #
                    # Real World Example
                    #
                    "REAL WORLD EXAMPLE: Rec 1: Start & End Time '21:00:00' to '09:00:00', Rec 2: '25/12'" => {
                            calendar    => [
                                    { start_time => '21:00:00', end_time => '07:59:59' },
                                    { start_date => '25/12' },
                                ],
                            test_time   => [
                                    { time => '21:00:00', expected => 0 },
                                    { time => '23:59:59', expected => 0 },
                                    { time => '07:59:59', expected => 0 },
                                    { time => '20:59:59', expected => 1 },
                                    { time => '08:00:00', expected => 1 },
                                    { time => '13:00:00', expected => 1 },      # this will fail when run on Christmas Day
                                    { date => '25/12', time => '13:00:00', expected => 0 },
                                    # leap year test
                                    { date => '29/02/2012', time => '13:00:00', expected => 1 },
                                    { date => '29/02/2012', time => '01:00:00', expected => 0 },
                                    { date => '29/02/2012', time => '23:00:00', expected => 0 },
                                ],
                        },
                );

            foreach my $label ( keys %tests ) {
                note "TESTING: $label";
                my $test        = $tests{ $label };
                my $test_times  = (
                                    exists( $test->{same_as} )
                                    ? $tests{ $test->{same_as} }{test_time}
                                    : $test->{test_time}
                                  );
                ok( $test_times, "sanity check, have something to test with" ) or diag p( $tests{ $label } );

                # clear out any existing records
                $csm_rec->csm_exclusion_calendars->delete;

                # populate the 'csm_exclusion_calendar' for the $csm_rec
                _add_cal_exclusion( $csm_rec, $test->{calendar} );

                # now loop round all of the test times
                foreach my $test_time ( @{ $test_times } ) {
                    # make up the date to use
                    my $date_str = ( exists( $test_time->{date} ) ? _format_date( $now, $test_time->{date} ) : $now->ymd('-') );
                    $date_str   .= 'T' . ( exists( $test_time->{time} ) ? $test_time->{time} : $now->hms(':') );
                    my $date    = DateTime::Format::DateParse->parse_datetime( $date_str, 'local' );
                    note "using: " . $date->format_cldr("eee, MMM d y, HH':'mm':'ss'");

                    my $got = $csm_rec->window_open_to_send( $date );
                    ok( defined $got, "'window_open_to_send' returned a Defined Value" );
                    cmp_ok( $got, '==', $test_time->{expected}, "Result Returned as Expected: $$test_time{expected}" );
                }
            }


            # rollback changes
            $schema->txn_rollback();
        } );
        _reload_methods();
    };

    return;
}

# tests sending Failure Alerts when a Method has been used
# to send Correspondence and has failed, currently for SMS only
# also test other methods connected with the 'sms_correspondence' table
sub _test_csm_failure_notification {
    my ( $schema, $domain, $oktodo )    = @_;

    SKIP: {
        skip "_test_csm_failure_notification", 1       if ( !$oktodo );

        note "in '_test_csm_failure_notification'";

        my $framework   = Test::XT::Data->new_with_traits(
                traits => [ 'Test::XT::Data::Order' ],
        );

        $schema->txn_do( sub {
            # create an order
            my ( $channel, $customer, $order, $shipment )   = _create_an_order( $framework, { dispatched => 1 } );
            my $return                                      = _create_return( $domain, $shipment );

            my $subject = _create_subject( $channel );

            my $conf_section    = $channel->business->config_section;

            # get a copy of the config
            my $config  = \%XTracker::Config::Local::config;

            # set an Email Address for the Sales Channel and a General Email Address
            my $channel_email_config    = 'channel_failure_alert';
            my $channel_email_address   = 'channel_failure_alert@this.com';
            my $nonchan_email_config    = 'nonchan_failure_alert';
            my $nonchan_email_address   = 'nonchan_failure_alert@this.com';

            $config->{ "Email_${conf_section}" }{ $channel_email_config }   = $channel_email_address;
            $config->{ "Email" }{ $nonchan_email_config }                   = $nonchan_email_address;

            # make a General Email version of the Sales Channel Email
            # Address to make sure that the correct version is returned
            $config->{Email}{ $channel_email_config }   = 'SHOULD.NOT@BE.RETURNED';

            note "Testing 'email_for_failure_notification' method on 'Public::CorrespondenceSubjectMethod'";

            note "using Channel Email Address    : $channel_email_config - $channel_email_address";
            note "using Non-Channel Email Address: $nonchan_email_config - $nonchan_email_address";

            # get all of the CSM records for the Subject
            my @csm_recs    = $subject->correspondence_subject_methods->all;

            # set-up a CSM record to have a failure Email Address, all the others should be 'undef'
            $csm_recs[0]->update( { notify_on_failure => $channel_email_config } );
            $csm_recs[1]->update( { notify_on_failure => 'sdjfsf' } );      # use a non-existent setting

            is( $csm_recs[2]->email_for_failure_notification, "", "returns an Empty String when 'notify_on_failure' is blank" );
            is( $csm_recs[1]->email_for_failure_notification, "", "returns an Empty String when field contains a non-existent setting" );
            is( $csm_recs[0]->email_for_failure_notification, $channel_email_address, "for a Channel Email Address returns as Expected" );
            $csm_recs[0]->update( { notify_on_failure => $nonchan_email_config } );
            is( $csm_recs[0]->email_for_failure_notification, $nonchan_email_address, "for a Non-Channel Email Address returns as Expected" );


            note "Testing methods on 'Public::SmsCorrespondence'";

            # find the SMS CSM Record
            my ( $sms_csm_rec ) = grep { $_->correspondence_method_id == $method{SMS} } @csm_recs;

            # create an SMS Correspondence record
            my $sms_rec = $sms_csm_rec->sms_correspondences->create( {
                                                mobile_number   => '+445566778899',
                                                message         => 'SMS Message Text',
                                                failure_code    => 'FAIL CODE',
                                                sms_correspondence_status_id => $SMS_CORRESPONDENCE_STATUS__PENDING,
                                            } );

            note "testing 'get_linked_record' method";
            ok( !defined $sms_rec->get_linked_record, "'get_linked_record' When nothing linked returns 'undef'" );
            $sms_rec->create_related( 'link_sms_correspondence__shipments', { shipment_id => $shipment->id } );
            isa_ok( $sms_rec->get_linked_record, "XTracker::Schema::Result::Public::Shipment", "'get_linked_record' when linked to a 'Shipment' returns" );
            $sms_rec->link_sms_correspondence__shipments->delete;
            $sms_rec->create_related( 'link_sms_correspondence__returns', { return_id => $return->id } );
            isa_ok( $sms_rec->get_linked_record, "XTracker::Schema::Result::Public::Return", "'get_linked_record' when linked to a 'Return' returns" );

            note "testing 'is_*' status methods and 'update_status' method";
            throws_ok { $sms_rec->update_status() } qr/No Status Id passed/i, "'update_status' method fail when no Status Id passed to it";

            my %statuses    = (
                            $SMS_CORRESPONDENCE_STATUS__PENDING             => 'is_pending',
                            $SMS_CORRESPONDENCE_STATUS__SUCCESS             => 'is_success',
                            $SMS_CORRESPONDENCE_STATUS__FAIL                => 'is_fail',
                            $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY   => 'is_not_sent',
                        );

            foreach my $status_id ( keys %statuses ) {
                my $true_method = $statuses{ $status_id };
                note "testing for '$true_method'";
                ok( !defined $sms_rec->update_status( $status_id ), "'update_status' method returns 'undef;" );
                cmp_ok( $sms_rec->discard_changes->sms_correspondence_status_id, '==', $status_id, "and status is updated correctly" );
                foreach my $method_to_use ( values %statuses ) {
                    my $got = $sms_rec->$method_to_use;
                    ok( defined $got, "'$true_method' returned a defined value" );
                    cmp_ok( $got, '==', ( $true_method eq $method_to_use ? 1 : 0 ), "value is as Expected: $got" );
                }
                # test 'is_failed' method which covers multiple Statuses
                my $got = $sms_rec->is_failed;
                ok( defined $got, "'is_failed' returned a defined value" );
                cmp_ok( $got, '==', ( $true_method ne 'is_pending' && $true_method ne 'is_success' ? 1 : 0 ), "value is as Expected: $got" );
            }

            note "testing 'send_failure_alert' method";

            # specify a failure Email Config so that something can be sent
            $sms_csm_rec->update( { notify_on_failure => $channel_email_config } );
            $sms_rec->discard_changes;

            # get all of the Statuses and split them between those allowed to send an Email and those that aren't
            %statuses       = map { $_->id => $_ } $schema->resultset('Public::SmsCorrespondenceStatus')->all;
            my @allow       = map { delete $statuses{ $_ } } (
                                                                $SMS_CORRESPONDENCE_STATUS__FAIL,
                                                                $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY,
                                                            );
            my @not_allow   = values %statuses;

            note "check Statuses that Shouldn't send a Notification";
            foreach my $status ( @not_allow ) {
                $sms_rec->update_status( $status->id );
                my $result  = $sms_rec->send_failure_alert;
                ok( defined $result && $result == 0, "'send_failure_alert' returned a defined value and ZERO for Status: ".$status->status );
            }

            note "check Statuses that Should send a Notification";

            # build up what is expected
            my $from_address    = config_var( 'Email', 'xtracker_email' );
            my $email_subject   = "SMS Failed for " . $subject->description;
            my %message_data    = (
                            failure_code        => $sms_rec->failure_code,
                            order_nr            => $order->order_nr,
                            first_name          => $customer->first_name,
                            last_name           => $customer->last_name,
                            mobile_number       => $sms_rec->mobile_number,
                            message             => $sms_rec->message,
                        );
            my $email_message   =<<MESSAGE
$email_subject

Failure Reason: $message_data{failure_code}

Order Number: $message_data{order_nr}
Customer    : $message_data{first_name} $message_data{last_name}

Telephone Used: $message_data{mobile_number}
Message Sent:
$message_data{message}
MESSAGE
;

            foreach my $status ( @allow ) {
                # reset the vars used in the redefined 'send_email' function
                %redef_email_args   = ();
                $redef_send_email   = 0;
                $redef_fail_email   = 0;
                $redef_email_todie  = 0;

                $sms_rec->update_status( $status->id );
                my $result  = $sms_rec->send_failure_alert;
                ok( defined $result && $result == 1, "'send_failure_alert' returned a defined value and ONE for Status: ".$status->status );
                note "check what was sent to 'send_email'";
                is( $redef_email_args{fail}{from}, $from_address, "'From' address as Expected: $redef_email_args{fail}{from}" );
                is( $redef_email_args{fail}{reply}, $from_address, "'Reply' address as Expected: $redef_email_args{fail}{reply}" );
                is( $redef_email_args{fail}{to}, $channel_email_address, "'To' address as Expected: $redef_email_args{fail}{to}" );
                is( $redef_email_args{fail}{subject}, $email_subject, "'Subject' as Expected: $redef_email_args{fail}{subject}" );
                is( $redef_email_args{fail}{message}, $email_message, "'Message' as Expected" );
                ok( !exists $redef_email_args{fail}{args}{no_bcc}, "'no_bcc' argument NOT passed to 'send_email' function" );
                if ( $ENV{HARNESS_VERBOSE} ) {
                    diag "--------------------------------------------------------";
                    diag "Status : " . $status->status;
                    diag "Subject: " . $redef_email_args{fail}{subject};
                    diag "Message:\n" . $redef_email_args{fail}{message};
                }
            }

            # clear the failure Email Config so that a notification shouldn't be sent
            $sms_csm_rec->update( { notify_on_failure => undef } );
            my $result  = $sms_rec->discard_changes->send_failure_alert;
            ok( defined $result && $result == 0, "'send_failure_alert' returned a defined value and ZERO when there is NO Failure Email to Send to" );


            # rollback changes
            $schema->txn_rollback();
        } );
        _reload_methods();
    };

    return;
}

# tests the 'XT::Correspondence::*' classes
# currently for 'SMS' & 'Email'
sub _test_correspondence_classes {
    my ( $schema, $domain, $amq, $oktodo )  = @_;

    SKIP: {
        skip "_test_correspondence_classes", 1      if ( !$oktodo );

        note "in '_test_correspondence_classes'";

        my $framework   = Test::XT::Data->new_with_traits(
                traits => [ 'Test::XT::Data::Order' ],
        );

        $schema->txn_do( sub {
            # create an order
            my ( $channel, $customer, $order, $shipment )   = _create_an_order( $framework, { dispatched => 1 } );
            my $return                                      = _create_return( $domain, $shipment );

            # make sure it's a Premier Shipment
            $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER } );

            # get a copy of the config to use later
            my $config      = \%XTracker::Config::Local::config;
            my $email_config= $config->{ 'Email_' . $channel->business->config_section };

            my $queue   = config_var('Producer::Correspondence::SMS','destination');
            my $class_name_prefix   = 'XT::Correspondence::Method::';

            # create a new method to test for methods without
            # a 'XT::Correspondence::Method::*' class
            my $new_method  = $schema->resultset('Public::CorrespondenceMethod')->create( {
                                                                                    method      => 'TestMethodClass',
                                                                                    description => 'TestMethodClass Description',
                                                                                    can_opt_out => 1,
                                                                                } );
            my $subject     = _create_subject( $channel );
            _add_csm_method( $subject, { method_id => $new_method->id, can_opt_out => 1, default_can_use => 1 } );

            my %csm_recs    = map { $_->correspondence_method->method => $_ }
                                $subject->correspondence_subject_methods->all;

            # common argumnets for 'XT::Correspondence::Method'
            my $obj_args    = {
                        record  => $shipment,
                        use_to_send => 'Shipment',
                        body => 'correspondence message',
                        subject => 'correspondence subject',
                    };

            note "check Correspondence Method will throw an error when trying to be used with incorrect Arguments";
            my %tests   = (
                    "No Arguments at all"           => {
                                                args    => undef,
                                                errmsg  => qr/No Arguments or Arguments not a Hash Ref/,
                                            },
                    "A NON Hash Ref as Arguments"   => {
                                                args    => [ 1 ],
                                                errmsg  => qr/No Arguments or Arguments not a Hash Ref/,
                                            },
                    "With an Invalid 'record' argument" => {
                                                to_undef=> 'record',
                                                args    => { %{ $obj_args }, record => 'string' },
                                                errmsg  => qr/Argument 'record' must be an object/,
                                            },
                    "With an undefined 'use_to_send' argument" => {
                                                args    => { %{ $obj_args }, use_to_send => undef },
                                                errmsg  => qr/Argument 'use_to_send' has been passed but not defined/,
                                            },
                    "With 'use_to_send' but with a Non Object for 'record'" => {
                                                args    => { %{ $obj_args }, record => { a => 1 } },
                                                errmsg  => qr/Argument 'base_record' or 'record' - 'HASH', must have 'Schema::Role::Hierarchy'/,
                                            },
                    "With 'use_to_send' but with a DBIC Class without 'Schema::Role::Hierarchy' for 'record'" => {
                                                args    => { %{ $obj_args }, record => $csm_recs{'SMS'} },
                                                errmsg  => qr/Argument 'base_record' or 'record' - '.*', must have 'Schema::Role::Hierarchy'/,
                                            },
                    "With a Class in 'use_to_send' that can't be found in the Customer Hierarchy" => {
                                                args    => { %{ $obj_args }, use_to_send => 'Channel' },
                                                errmsg  => qr/Couldn't find a record for Class 'Channel' passed in/,
                                            },
                    "With a Correspondence Method which doesn't have a Class" => {
                                                args    => { %{ $obj_args }, csm_rec => $csm_recs{TestMethodClass} },
                                                errmsg  => qr/Couldn't Find a Method Class '.*::TestMethodClass'/,
                                            },
                    "With a Correspondence Method 'Email' without a 'subject' Argument" => {
                                                args    => { %{ $obj_args }, csm_rec => $csm_recs{Email}, subject => undef },
                                                errmsg  => qr/Attribute \(subject\)/,
                                            },
                    "Using a 'use_to_send' record that doesn't support the 'get_phone_number' method, for SMS" => {
                                                args    => { %{ $obj_args }, csm_rec => $csm_recs{SMS}, use_to_send => 'Customer' },
                                                errmsg  => qr{'send_record/use_to_send' passed in '.*' can't call method 'get_phone_number'},
                                            },
                    "Using a 'use_to_send' record that doesn't support the 'email' method, for Email" => {
                                                args    => { %{ $obj_args }, csm_rec => $csm_recs{Email}, record => $return, use_to_send => 'Return' },
                                                errmsg  => qr{'send_record/use_to_send' passed in '.*' can't call method 'email'},
                                            },
                );
            foreach my $label ( keys %tests ) {
                my $test    = $tests{ $label };
                my $args    = $test->{args};
                my $errmsg  = $test->{errmsg};
                my $to_undef= $test->{to_undef};
                throws_ok { my $tmp = XT::Correspondence::Method->new( $args ); } qr/$errmsg/i, "$label: Couldn't instantiate an object";
                if ( $to_undef ) {
                    $args->{ $to_undef }    = undef;
                    throws_ok { my $tmp = XT::Correspondence::Method->new( $args ); } qr/$errmsg/si,
                                                "$label: Couldn't instantiate an object, with '$to_undef' undefined";
                }
            }

            note "check Correspondence Methods will instantiate an 'XT::Correspondence::Method::*' class";
            foreach my $method_type ( qw(
                                            SMS
                                            Email
                                    ) ) {
                $obj_args->{csm_rec}    = $csm_recs{ $method_type };
                my $corr_method = XT::Correspondence::Method->new( $obj_args );
                isa_ok( $corr_method, "${class_name_prefix}${method_type}", "Got back Expected Object" );
            }


            # now check more thoroughly each Correspondence Method

            # make sure the CRM is sent a message and an Alert is sent if any failures
            $csm_recs{SMS}->update( { copy_to_crm => 1, notify_on_failure => 'premier_email' } );
            $csm_recs{Email}->update( { send_from => 'premier_email' } );       # set what email from should be used
            my $expect_email_from   = config_var( 'Email_' . $channel->business->config_section, 'premier_email' );
            my $sms_rec_rs          = $csm_recs{SMS}->sms_correspondences;

            note "check for expected Failures when sending";
            $obj_args->{csm_rec}    = $csm_recs{SMS};
            my $sms_obj = XT::Correspondence::Method->new( { %{ $obj_args }, record => $order, use_to_send => 'Orders' } );
            is( $sms_obj->mobile_number, $order->mobile_telephone, "Using 'Order' returns the Order Mobile Number" );
            throws_ok { $sms_obj->send_correspondence() } qr/Can't find a Relationship to the 'sms_correspondence'/i,
                                    "Can't Send an SMS if the 'base_record' doesn't have a relationship with 'sms_correspondence'";

            note "check using a Non-Premier Shipment Type doesn't use 'premier_mobile_number_for_SMS' method to get the Mobile Number";
            $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__DOMESTIC, mobile_telephone => '07100123321' } );
            $sms_obj    = XT::Correspondence::Method->new( { %{ $obj_args }, record => $shipment } );
            is( $sms_obj->mobile_number, $shipment->mobile_telephone, "With a Non-Premier Type, the Mobile Number is without a Country Prefix" );
            # clear both telephones and should get an empty string back from '->mobile_number' with NO leading '+'
            $shipment->update( { telephone => "", mobile_telephone => "" } );
            $sms_obj    = XT::Correspondence::Method->new( { %{ $obj_args }, record => $shipment } );
            is( $sms_obj->mobile_number, "", "With NO Phone Numbers at all '\$sms_obj->mobile_number' returned an Empty String" );
            $shipment->update( { shipment_type_id => $SHIPMENT_TYPE__PREMIER, mobile_telephone => '+447100321123' } );

            note "check the general '_ok_to_send' method when Various fields are Disabled for the Method";
            foreach my $method ( 'SMS', 'Email' ) {
                note "checking with: $method";
                my $obj = XT::Correspondence::Method->new( { %{ $obj_args }, csm_rec => $csm_recs{ $method } } );

                $method_recs{ $method }->update( { enabled => 0 } );
                $obj->csm_rec->discard_changes;
                cmp_ok( $obj->_ok_to_send(), '==', 0, "Failed when 'enabled' field on Correspondence Method record is FALSE" );
                is( $obj->_failure_code, 'METHOD_RECORD_DISABLED', "and Failure Code is as Expected" );
                $method_recs{ $method }->update( { enabled => 1 } );

                $csm_recs{ $method }->update( { enabled => 0 } );
                $obj->csm_rec->discard_changes;
                cmp_ok( $obj->_ok_to_send(), '==', 0, "Failed when 'enabled' field on CSM record is FALSE" );
                is( $obj->_failure_code, 'METHOD_DISABLED_ON_CSM_RECORD', "and Failure Code is as Expected" );
                $csm_recs{ $method }->update( { enabled => 1 } );

                $csm_recs{ $method }->correspondence_subject->update( { enabled => 0 } );
                $obj->csm_rec->discard_changes;
                cmp_ok( $obj->_ok_to_send(), '==', 0, "Failed when 'enabled' field on Correspondent Subject record is FALSE" );
                is( $obj->_failure_code, 'SUBJECT_RECORD_DISABLED', "and Failure Code is as Expected" );
                $csm_recs{ $method }->correspondence_subject->update( { enabled => 1 } );

                my $setting = $channel->config_group->search( { name => 'Customer_Communication' } )->first
                                        ->config_group_settings->search( { setting => $method } )->first;
                $setting->update( { value => 'Off' } );
                $obj->csm_rec->discard_changes;
                cmp_ok( $obj->_ok_to_send(), '==', 0, "Failed when 'Customer Communication' System Setting for Channel is 'Off'" );
                is( $obj->_failure_code, 'METHOD_DISABLED_FOR_CHANNEL', "and Failure Code is as Expected" );
                $setting->update( { value => 'On' } );

                $obj->csm_rec->discard_changes;
            }

            # loop round using both a Shipment & a Return object
            foreach my $base_record ( $shipment, $return ) {
                note "using Base Record: " . ref( $base_record );
                $obj_args->{record} = $base_record;

                %redef_email_args   = ();
                $redef_fail_email   = 0;
                $redef_send_email   = 0;
                $redef_email_todie  = 0;

                # make sure the Send window is open
                $csm_recs{SMS}->csm_exclusion_calendars->delete;
                $csm_recs{Email}->csm_exclusion_calendars->delete;

                note "Check 'XT::Correspondence::Method::SMS'";
                $obj_args->{csm_rec}    = $csm_recs{SMS};

                note "check sending an SMS";
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                is( $sms_obj->mobile_number, $shipment->mobile_telephone, "got the expected Mobile Number from Shipment record" );
                is( $sms_obj->sender_id, $channel->branding( $BRANDING__SMS_SENDER_ID ), "got expected Sender Id from Channel Branding" );
                cmp_ok( $sms_obj->send_correspondence(), '==', 1, "Sent SMS Ok" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                cmp_ok( $sms_rec_rs->first->csm_id, '==', $csm_recs{SMS}->id, "'csm_id' as expected on record" );
                cmp_ok( $sms_rec_rs->first->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__PENDING, "Status is 'Pending'" );
                is( $sms_rec_rs->first->mobile_number, $shipment->premier_mobile_number_for_SMS, "Mobile Number used is the One for Premier: '" . $sms_rec_rs->first->mobile_number ."'" );
                is( $sms_rec_rs->first->message, $obj_args->{body}, "and Message used is as Expected: '" . $sms_rec_rs->first->message . "'" );
                _test_amq_sms_message( $amq, $queue, $sms_rec_rs->reset->first );
                cmp_ok( $redef_fail_email, '==', 0, "No Failure Alert was Sent" );
                cmp_ok( $redef_send_email, '==', 1, "Email to CRM was Sent" );
                _test_crm_sent_ok( $sms_rec_rs->reset->first, $redef_email_args{send} );

                {
                note "check sending an SMS when the Producer DIEs, check correct Failure Code is used";
                no warnings 'redefine';
                local *XT::DC::Messaging::Producer::Correspondence::SMS::transform=sub{die}; # this will cause the Producer to fail
                $redef_send_email     = 0;
                $redef_fail_email     = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $sms_obj->send_correspondence(), '==', 0, "Sent SMS NOT  Ok" );
                is( $sms_obj->_failure_code, 'COULD_NOT_SEND_TO_AMQ', "Internal Failure Code set Correctly" );
                $amq->assert_messages({
                    destination => $queue,
                    assert_count => 0,
                }, "and NO AMQ Messages Sent" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                cmp_ok( $sms_rec_rs->first->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY, "Status is 'Not Sent To Proxy'" );
                is( $sms_rec_rs->first->failure_code, "COULD_NOT_SEND_TO_AMQ", "Got 'Could Not Sent To AMQ' Failure Code" );
                cmp_ok( $redef_fail_email, '==', 1, "A Failure Alert was Sent" );
                like( $redef_email_args{fail}{message}, qr/COULD_NOT_SEND_TO_AMQ/si, "and Expected Failure reason is in the Alert Message" );
                ok( !exists $redef_email_args{fail}{args}{no_bcc}, "'no_bcc' argument NOT passed to 'send_email' function" );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                }

                note "check 'copy_to_crm' returns FALSE if 'send_email' DIEs but deosn't cause anything else to";
                $redef_send_email   = 0;
                $redef_email_todie  = 1;
                cmp_ok( $sms_obj->copy_to_crm(), '==', 0, "'copy_to_crm' returned FALSE" );
                cmp_ok( $redef_send_email, '==', 0, "and no Email was Sent" );
                $redef_email_todie  = 0;

                note "check CRM is NOT notified when there is NO CRM Email Address for the Channel";
                my $tmp_store  = delete $email_config->{crm_email};
                $redef_send_email = 0;
                $redef_fail_email = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $sms_obj->send_correspondence(), '==', 1, "Sent SMS Ok" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                _test_amq_sms_message( $amq, $queue, $sms_rec_rs->reset->first );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                cmp_ok( $redef_fail_email, '==', 0, "No Failure Alert was Sent" );
                $email_config->{crm_email}  = $tmp_store;

                note "check CRM is NOT notified when the 'copy_to_crm' Flag is FALSE on the CSM Rec";
                $redef_send_email     = 0;
                $redef_fail_email     = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $csm_recs{SMS}->update( { copy_to_crm => 0 } );     # make sure the CRM is NOT sent a message
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $sms_obj->send_correspondence(), '==', 1, "Sent SMS Ok" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                _test_amq_sms_message( $amq, $queue, $sms_rec_rs->reset->first );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                cmp_ok( $redef_fail_email, '==', 0, "No Failure Alert was Sent" );

                note "check with various empty contact details, that '_ok_to_send' method returns FALSE";
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                my %chk_not_ok  = ( mobile_number => 'NO_MOBILE_NUMBER', body => 'NO_MESSAGE_BODY' );
                while ( my ( $field, $fail_code ) = each %chk_not_ok ) {
                    my $tmp = $sms_obj->$field;
                    $sms_obj->$field("");
                    cmp_ok( $sms_obj->_ok_to_send(), '==', 0, "With Empty: $field, returns FALSE" );
                    is( $sms_obj->_failure_code, $fail_code, "Internal Failure Code set Correctly: $fail_code" );
                    $sms_obj->$field( $tmp );
                }

                note "check shutting the Send Window for the Subject & SMS sends a Fail Alert Email";
                $csm_recs{SMS}->csm_exclusion_calendars->create( { day_of_week => '1,2,3,4,5,6,7' } );
                $csm_recs{SMS}->update( { copy_to_crm => 1 } );
                $redef_send_email = 0;
                $redef_fail_email = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $sms_obj->send_correspondence(), '==', 0, "Sent SMS NOT Ok" );
                is( $sms_obj->_failure_code, 'WINDOW_CLOSED', "Internal Failure Code set Correctly" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                cmp_ok( $sms_rec_rs->first->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY, "Status is 'Not Sent To Proxy'" );
                is( $sms_rec_rs->first->failure_code, "WINDOW_CLOSED", "Got 'Window Closed' Failure Code" );
                $amq->assert_messages({
                    destination => $queue,
                    assert_count => 0,
                }, "and NO AMQ Messages Sent" );
                cmp_ok( $redef_fail_email, '==', 1, "A Failure Alert was Sent" );
                like( $redef_email_args{fail}{message}, qr/WINDOW_CLOSED/si, "and Expected Failure reason is in the Alert Message" );
                ok( !exists $redef_email_args{fail}{args}{no_bcc}, "'no_bcc' argument NOT passed to 'send_email' function" );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                $csm_recs{SMS}->csm_exclusion_calendars->delete;

                note "check With an Empty Message Body SMS is not sent, but this time the Fail Alert will DIE but not cause anything else to";
                $redef_email_todie  = 1;
                $redef_send_email   = 0;
                $redef_fail_email   = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( $obj_args );
                $sms_obj->body("");
                cmp_ok( $sms_obj->send_correspondence(), '==', 0, "Sent SMS NOT Ok" );
                is( $sms_obj->_failure_code, 'NO_MESSAGE_BODY', "Internal Failure Code set Correctly" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                cmp_ok( $sms_rec_rs->first->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__NOT_SENT_TO_PROXY, "Status is 'Not Sent To Proxy'" );
                is( $sms_rec_rs->first->failure_code, "NO_MESSAGE_BODY", "Got 'No Message Body' Failure Code" );
                $amq->assert_messages({
                    destination => $queue,
                    assert_count => 0,
                }, "and NO AMQ Messages Sent" );
                cmp_ok( $redef_fail_email, '==', 0, "A Failure Alert was NOT Sent" );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                $redef_email_todie  = 0;


                # call explictly setting various attributes
                # rather than rely on their build methods
                note "check by manually passing in attributes, so build methods won't be used";
                $redef_send_email    = 0;
                $redef_fail_email    = 0;
                _delete_sms_rec( $sms_rec_rs );
                $amq->clear_destination( $queue );
                $sms_obj    = XT::Correspondence::Method->new( {
                                                    csm_rec         => $csm_recs{SMS},
                                                    base_record     => $base_record,
                                                    send_record     => $shipment,
                                                    body            => 'sms message',
                                                    copy_to_crm     => 0,
                                                    msg_factory     => $amq,
                                                    mobile_number   => '+44123456789',
                                                    sender_id       => 'MANUAL',
                                            } );
                cmp_ok( $sms_obj->send_correspondence(), '==', 1, "Sent SMS Ok" );
                is( $sms_obj->mobile_number, '+44123456789', "got the manual Mobile Number" );
                is( $sms_obj->sender_id, 'MANUAL', "got the manual Sender Id" );
                cmp_ok( $sms_rec_rs->reset->count(), '==', 1, "'sms_correspondence' record created" );
                cmp_ok( $sms_rec_rs->first->csm_id, '==', $csm_recs{SMS}->id, "'csm_id' as expected on record" );
                cmp_ok( $sms_rec_rs->first->sms_correspondence_status_id, '==', $SMS_CORRESPONDENCE_STATUS__PENDING, "Status is 'Pending'" );
                is( $sms_rec_rs->first->mobile_number, '+44123456789', "Mobile Number used is the Manual One" );
                _test_amq_sms_message( $amq, $queue, $sms_rec_rs->reset->first, 'MANUAL' );
                cmp_ok( $redef_send_email, '==', 0, "No CRM Email was Sent" );
                cmp_ok( $redef_fail_email, '==', 0, "No Failure Alert was Sent" );


                note "Check 'XT::Correspondence::Method::Email'";

                %redef_email_args   = ();
                $redef_send_email   = 0;
                $redef_fail_email   = 0;
                $obj_args->{csm_rec}= $csm_recs{Email};

                my $email_obj   = XT::Correspondence::Method->new( $obj_args );
                is( $email_obj->email_to, $shipment->email, "got the expected To Email Address from Shipment record" );
                is( $email_obj->email_from, $expect_email_from, "got the expected From Email Address: $expect_email_from" );
                is( $email_obj->subject, $obj_args->{subject}, "got the expected Subject: $obj_args->{subject}" );
                cmp_ok( $email_obj->send_correspondence(), '==', 1, "Sent Email Ok" );
                cmp_ok( $redef_send_email, '==', 1, "and Email Was Sent" );
                is( $redef_email_args{send}{from}, $expect_email_from, "Email From Address as Expected: $expect_email_from" );
                is( $redef_email_args{send}{to}, $shipment->email, "Email to Address as Expected: " . $shipment->email );
                is( $redef_email_args{send}{subject}, $obj_args->{subject}, "Email Subject as Expected: $obj_args->{subject}" );
                is( $redef_email_args{send}{message}, $obj_args->{body}, "Email Body as Expected: $obj_args->{body}" );
                ok( !exists $redef_email_args{send}{args}{no_bcc}, "'no_bcc' argument NOT passed to 'send_email' function" );

                note "check with various empty contact details, that '_ok_to_send' method returns FALSE";
                $email_obj  = XT::Correspondence::Method->new( $obj_args );
                foreach my $field ( qw( email_to email_from subject body ) ) {
                    my $tmp = $email_obj->$field;
                    $email_obj->$field("");
                    cmp_ok( $email_obj->_ok_to_send(), '==', 0, "With Empty: $field, returns FALSE" );
                    $email_obj->$field( $tmp );
                }

                note "check shutting the Send Window for the Subject & Email";
                $csm_recs{Email}->csm_exclusion_calendars->create( { day_of_week => '1,2,3,4,5,6,7' } );
                %redef_email_args   = ();
                $redef_send_email   = 0;
                $email_obj  = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $email_obj->send_correspondence(), '==', 0, "Sent Email NOT Ok" );
                is( $email_obj->_failure_code, 'WINDOW_CLOSED', "Internal Failure Code set Correctly" );
                cmp_ok( $redef_send_email, '==', 0, "and an Email wasn't Sent" );

                # call explictly setting various attributes
                # rather than rely on their build methods
                note "check by manually passing in attributes, so build methods won't be used";
                %redef_email_args   = ();
                $redef_send_email   = 0;
                $csm_recs{Email}->csm_exclusion_calendars->delete;
                $email_obj    = XT::Correspondence::Method->new( {
                                                    csm_rec         => $csm_recs{Email},
                                                    base_record     => $base_record,
                                                    send_record     => $shipment,
                                                    body            => 'email message',
                                                    msg_factory     => $amq,
                                                    subject         => 'email subject',
                                                    email_to        => 'custom@email.to',
                                                    email_from      => 'custom@email.from',
                                            } );
                cmp_ok( $email_obj->send_correspondence(), '==', 1, "Sent Email Ok" );
                is( $email_obj->email_to, 'custom@email.to', "got the manual Email To Address" );
                is( $email_obj->email_from, 'custom@email.from', "got the manual Email From Address" );
                cmp_ok( $redef_send_email, '==', 1, "and Email Was Sent" );
                is( $redef_email_args{send}{from}, 'custom@email.from', "Email From Address used is the Manual one" );
                is( $redef_email_args{send}{to}, 'custom@email.to', "Email to Address used is the Manual one" );
                ok( !exists $redef_email_args{send}{args}{no_bcc}, "'no_bcc' argument NOT passed to 'send_email' function" );

                note "check when 'send_email' dies, 'send' returns FALSE";
                $redef_email_todie  = 1;
                $email_obj  = XT::Correspondence::Method->new( $obj_args );
                cmp_ok( $email_obj->send_correspondence(), '==', 0, "Sent Email NOT Ok" );
            }

            # rollback changes
            $schema->txn_rollback();
        } );
        _reload_methods();
    };

    return;
}

#-------------------------------------------------------------------------------------

# helper to test 'can_use_csm'
sub _test_can_use_csm {
    my ( $rec, $subject, $method, $can_use )  = @_;

    # cycle through different ways to call the 'can_use_csm' method
    state $idx  = 0;
    my @params  = (
                [ 'Subject Id, Method Id', $subject->id, $method{ $method } ],
                [ 'Subject Rec, Method Id', $subject, $method{ $method } ],
                [ 'Subject Name, Method Id, Channel Id', $subject->subject, $method{ $method }, $subject->channel_id ],
            );

    my $param_desc  = shift @{ $params[ $idx ] };
    my $obj         = ref( $rec );
    $obj            =~ s/.*Public:://;
    cmp_ok( $rec->discard_changes->can_use_csm( @{ $params[ $idx ] } ), '==', $can_use,
                                                "'$obj' " . ( $can_use ? 'CAN' : 'can NOT' ) . " use '$method', calling with Params: $param_desc" );

    # if it's an Order then test 'can_order_use_csm' DB function
    if ( $obj eq 'Orders' ) {
        my $schema  = $rec->result_source->schema;
        my $dbh     = $schema->storage->dbh;
        my $csm_rec = $subject->correspondence_subject_methods->find( { correspondence_method_id => $method{ $method } } );
        if ( $csm_rec ) {
            # only relevant to test if there is a CSM rec for the Method & Subject
            cmp_ok( _call_can_order_use_csm( $dbh, $rec->id, $rec->customer_id, $csm_rec->id ), '==', $can_use,
                            "'$obj' using 'can_order_use_csm' " . ( $can_use ? 'CAN' : 'can NOT' ) . " use '$method', calling with a Customer Id" );
            cmp_ok( _call_can_order_use_csm( $dbh, $rec->id, 0, $csm_rec->id ), '==', $can_use,
                            "'$obj' using 'can_order_use_csm' " . ( $can_use ? 'CAN' : 'can NOT' ) . " use '$method', calling without a Customer Id" );
        }
    }

    # get the next way of calling 'can_use_csm'
    $idx    = ( $idx >= $#params ? 0 : $idx + 1 );

    return;
}

# helper to test 'csm_prefs_allow_method'
sub _test_do_prefs_allow {
    my ( $rec, $subject, $method, $preference, $test_db_func )  = @_;

    $test_db_func   //= 1;

    my $obj = ref( $rec );
    $obj    =~ s/.*Public:://;
    my $got = $rec->discard_changes->csm_prefs_allow_method( $subject, $method_recs{ $method } );
    if ( defined $preference ) {
        ok( defined $got, "'$obj' Preference Defined for '$method'" );
        cmp_ok( $got, '==', $preference, "'$obj' Preference '" . ( $preference ? 'TRUE' : 'FALSE' ) . "' for '$method'" );
    }
    else {
        ok( !defined $got, "'$obj' Undefined Preference for '$method'" ) || note "FAIL - Preference Got: '$got'";
    }

    # if it's an Order then test 'can_order_use_csm' DB function
    if ( $obj eq 'Orders' && $test_db_func ) {
        my $schema  = $rec->result_source->schema;
        my $dbh     = $schema->storage->dbh;
        my $csm_rec = $subject->correspondence_subject_methods->find( { correspondence_method_id => $method{ $method } } );
        if ( $csm_rec ) {
            $preference //= 0;      # if $preference is 'undef' then check for FALSE
            # only relevant to test if there is a CSM rec for the Method & Subject
            cmp_ok( _call_can_order_use_csm( $dbh, $rec->id, $rec->customer_id, $csm_rec->id ), '==', $preference,
                            "'$obj' using 'can_order_use_csm' " . ( $preference ? 'CAN' : 'can NOT' ) . " use '$method', calling with a Customer Id" );
            cmp_ok( _call_can_order_use_csm( $dbh, $rec->id, 0, $csm_rec->id ), '==', $preference,
                            "'$obj' using 'can_order_use_csm' " . ( $preference ? 'CAN' : 'can NOT' ) . " use '$method', calling without a Customer Id" );
        }
    }

    return;
}

# create a new Correspondence Subject record
# and assign Correspondence Methods to it
sub _create_subject {
    my $channel = shift;

    my $csm_subject = $channel->create_related( 'correspondence_subjects', { subject => 'Test Subject '.$$, description => 'Description' } );
    ok( !defined $csm_subject->get_enabled_methods, "With no associated 'correspondence_subject_method' records 'get_enabled_methods' returns 'undef'" );

    # assign Correspondence Methods to the Subject
    _add_csm_method( $csm_subject, { method_id => $method{'SMS'}, can_opt_out => 1, default_can_use => 1 } );
    _add_csm_method( $csm_subject, { method_id => $method{'Email'}, can_opt_out => 1, default_can_use => 1 } );
    _add_csm_method( $csm_subject, { method_id => $method{'Phone'}, can_opt_out => 1, default_can_use => 0 } );
    _add_csm_method( $csm_subject, { method_id => $method{'Document'}, can_opt_out => 0, default_can_use => 0 } );

    return $csm_subject->discard_changes;
}

# returns back the current CSM preferences for testing
sub _get_csm_preferences {
    my ( $csm_link, $subject_id, $args )    = @_;

    my %prefs   = map { $_->csm->correspondence_method_id => ( $args->{want_records} ? $_->discard_changes : $_->can_use ) }
                            $csm_link->search( { 'csm.correspondence_subject_id' => $subject_id }, { join => 'csm' } )
                                        ->all;

    return \%prefs;
}

# check required params for methods
sub _check_required_params {
    my ( $rec, $subject )   = @_;

    note "Testing Required Parameters";

    throws_ok( sub {
            $rec->change_csm_preference( 0, { } );
        }, qr/No Subject Id passed/, "No Subject Id passed to 'change_csm_preference' fails" );
    throws_ok( sub {
            $rec->change_csm_preference( -1, { } );
        }, qr/Couldn't find any 'correspondence_subject_method' records/, "Pass a Non-Existent Subject Id to 'change_csm_preference' fails" );
    throws_ok( sub {
            $rec->change_csm_preference( 1 );
        }, qr/No Arguments as a Hash Ref passed/, "No Arguments passed to 'change_csm_preference' fails" );
    throws_ok( sub {
            $rec->change_csm_preference( 1, 'not a hash ref' );
        }, qr/No Arguments as a Hash Ref passed/, "Invalid Arguments passed to 'change_csm_preference' fails" );

    throws_ok( sub {
            $rec->can_use_csm( undef, 1 );
        }, qr/No Subject passed/, "No Subject passed to 'can_use_csm' fails" );
    throws_ok( sub {
            $rec->can_use_csm( 1, undef );
        }, qr/No Method Id passed/, "No Method Id passed to 'can_use_csm' fails" );

    throws_ok( sub {
            $rec->get_csm_preferences( 0 );
        }, qr/No Subject Id passed/, "No Subject Id passed to 'get_csm_preferences' fails" );

    throws_ok( sub {
            $rec->ui_change_csm_available_by_subject( 0 );
        }, qr/No Subject Id passed/, "No Subject Id passed to 'ui_change_csm_available_by_subject' fails" );
    throws_ok( sub {
            $rec->ui_change_csm_available_by_subject( 1, [ ] );
        }, qr/If Method Arguments passed in then they should be a Hash Ref/, "Invalid Arguments passed to 'ui_change_csm_available_by_subject' fails" );


    if ( $subject && ref( $rec ) =~ m/::Customer/ ) {

        throws_ok( sub {
                $rec->can_use_csm( 99999, 1 );
            }, qr/Couldn't find a Subject/, "Invalid Subject Id to 'can_use_csm' fails" );
        throws_ok( sub {
                $rec->can_use_csm( {}, 1 );
            }, qr/Subject was passed in but of an Incorrect Type/, "Invalid Subject Object to 'can_use_csm' fails" );
        throws_ok( sub {
                $rec->can_use_csm( $subject->subject, 1 );
            }, qr/No Channel Id passed in with Subject Name/, "Subject Passed in but with No Channel Id to 'can_use_csm' fails" );
        throws_ok( sub {
                $rec->can_use_csm( 'made up name of subject', 1, $subject->channel_id );
            }, qr/Couldn't find a Subject under Name/, "Couldn't find a Subject with Invalid Name to 'can_use_csm' fails" );

        throws_ok( sub {
            $rec->csm_prefs_allow_method( undef, $method_recs{'SMS'} );
        }, qr/No Subject DBIC Object passed/, "No Subject Rec passed to 'csm_prefs_allow_method' fails" );
        throws_ok( sub {
            $rec->csm_prefs_allow_method( {}, $method_recs{'SMS'} );
        }, qr/No Subject DBIC Object passed/, "Non Subject Rec passed to 'csm_prefs_allow_method' fails" );
        throws_ok( sub {
            $rec->csm_prefs_allow_method( $subject, undef );
        }, qr/No Method DBIC Object passed/, "No Method Rec passed to 'csm_prefs_allow_method' fails" );
        throws_ok( sub {
            $rec->csm_prefs_allow_method( $subject, {} );
        }, qr/No Method DBIC Object passed/, "Non Method Rec passed to 'csm_prefs_allow_method' fails" );

        throws_ok( sub {
            $rec->csm_default_prefs_allow_method( undef );
        }, qr/No Method DBIC Object passed/, "No Method Rec passed to 'csm_default_prefs_allow_method' fails" );
        throws_ok( sub {
            $rec->csm_default_prefs_allow_method( {} );
        }, qr/No Method DBIC Object passed/, "Non Method Rec passed to 'csm_default_prefs_allow_method' fails" );

    }

    note "Finished Testing Required Parameters";
    return;
}

# create an Order
sub _create_an_order {
    my ( $framework, $args )    = @_;

    my $data    = $framework->new_order;
    my ( $channel, $customer, $order, $shipment ) = map { $data->{ $_ } }
                                                        qw( channel_object customer_object order_object shipment_object );

    if ( $args->{dispatched} ) {
        $shipment->update( { shipment_status_id => $SHIPMENT_STATUS__DISPATCHED } );
        $shipment->shipment_items->update( { shipment_item_status_id => $SHIPMENT_ITEM_STATUS__DISPATCHED } );
    }

    # set-up some contact details for later tests
    $customer->update( { email => 'customer@email.address' } );
    $shipment->update( { email => 'shipment@email.address', mobile_telephone => '+447100321123' } );
    $order->update( { email => 'order@email.address', mobile_telephone => '+447100123321' } );

    note "Cust. Nr/Id: ".$customer->discard_changes->is_customer_number."/".$customer->id;
    note "Order Nr/Id: ".$order->discard_changes->order_nr."/".$order->id;
    note "Shipment Id: ".$shipment->discard_changes->id;
    note "Shipment Type: " . $shipment->shipment_type->type;

    return ( $channel, $customer, $order, $shipment );
}

# create a Return for a Shipment
sub _create_return {
    my ( $domain, $shipment )   = @_;

    my $return      = $domain->create( {
                        operator_id => $APPLICATION_OPERATOR_ID,
                        shipment_id => $shipment->id,
                        pickup => 0,
                        refund_type_id => 0,
                        return_items => {
                                map {
                                        $_->id => {
                                            type        => 'Return',
                                            reason_id   => $CUSTOMER_ISSUE_TYPE__7__TOO_SMALL,
                                        }
                                    } $shipment->shipment_items->all
                            }
                    } );

    return $return->discard_changes;
}

# associate a Correspondence Method to a Subject
sub _add_csm_method {
    my ( $subject, $args )  = @_;

    return $subject->create_related( 'correspondence_subject_methods', {
                                            correspondence_method_id => $args->{method_id},
                                            can_opt_out => $args->{can_opt_out},
                                            default_can_use => $args->{default_can_use},
                                            notify_on_failure => undef,
                                        } );
}

# create a 'csm_exclusion_calendar' records
sub _add_cal_exclusion {
    my ( $csm_rec, $args )  = @_;

    # make sure it's an ArrayRef
    $args   = ( ref( $args ) eq 'ARRAY' ? $args : [ $args ] );

    foreach my $arg ( @{ $args } ) {
        $csm_rec->create_related( 'csm_exclusion_calendars', $arg );
    }

    return $csm_rec->discard_changes;
}

# used to format a date, takes DD/MM/YYYY and converts
# it to YYYY-MM-DD for parsing, pass $now so that the
# year can be used when only DD/MM is passed in
sub _format_date {
    my ( $now, $date )  = @_;

    $date   =~ m{(?<day>\d\d)/(?<month>\d\d)(/(?<year>\d{4}))?};

    return ( $+{year} ? $+{year} : $now->year ) . "-$+{month}-$+{day}";
}

# test the AMQ message sent for SMS Correspondence
sub _test_amq_sms_message {
    my ( $amq, $queue, $sms_rec, $sender_id )   = @_;

    my $channel = $sms_rec->csm->correspondence_subject->channel;

    $channel->web_name  =~ m/(?<channel>.*)-(?<instance>.*)/;
    my $msg_channel     = $+{channel} . '_' . $+{instance};

    my $expected    = {
            '@type'         => 'SMSMessage',
            id              => 'CSM-' . $sms_rec->id,
            salesChannel    =>  $msg_channel,
            message     => {
                    body        => $sms_rec->message,
                    from        => $sender_id || $channel->branding( $BRANDING__SMS_SENDER_ID ),
                    phoneNumber => $sms_rec->mobile_number,
                },
        };

    $amq->assert_messages({
        destination => $queue,
        assert_header => superhashof({
            type => 'SMSMessage',
        }),
        assert_body => $expected,
    }, "SMS Message Sent as Expected on Queue '$queue'" );

    return;
}

# helper to delete 'sms_correspondence' records and any link records
sub _delete_sms_rec {
    my $rs  = shift;

    my $rec     = $rs->reset->first;
    return      if ( !$rec );

    $rec->link_sms_correspondence__returns->delete;
    $rec->link_sms_correspondence__shipments->delete;
    $rec->delete;

    return;
}

# helper to make sure the CRM was sent the expected email
sub _test_crm_sent_ok {
    my ( $sms_rec, $email_args )    = @_;

    # Email From should be mobile number less
    # leading '+' at the CRM suffix
    my $email_from  = $sms_rec->mobile_number;
    $email_from     =~ s/\+//g;
    $email_from     .= '@' . config_var( 'DistributionCentre', 'crm_sms_suffix' );

    # make up the Expected Subject & Message
    my $channel = $sms_rec->csm->correspondence_subject->channel;
    my $subject = $sms_rec->csm->correspondence_subject->description . " " .
                  $sms_rec->csm->correspondence_method->description . " for " .
                  $channel->name . ", " . config_var( 'XTracker', 'instance' ) . " order";
    my $message = $sms_rec->message;

    is( $email_args->{from}, $email_from, "CRM Email From as Expected: $email_args->{from}" );
    is( $email_args->{to}, email_address_for_setting( 'crm_email', $channel ), "CRM Email To as Expected: $email_args->{to}" );
    is( $email_args->{subject}, $subject, "CRM Email Subject as Expected: $email_args->{subject}" );
    like( $email_args->{message}, qr/$message/si, "CRM Email Message as Expected" );
    ok( exists( $email_args->{args}{no_bcc} ), "CRM Email asked NOT to 'Bcc'" );

    return;
}

# use this to Redefine the 'XTracker::EmailFunctions::send_email' function
sub _redefined_send_email {
    note "============= IN REDEFINED 'send_email' =============";

    if ( $redef_email_todie ) {
        die "TEST TOLD ME TO DIE";
    }

    my $type;
    if ( caller =~ m/XT::Correspondence::Method/ ) {
        $type               = 'send';
        $redef_send_email   = 1;
    }
    else {
        $type               = 'fail';
        $redef_fail_email   = 1;
    }

    $redef_email_args{ $type }{from}    = $_[0];
    $redef_email_args{ $type }{reply}   = $_[1];
    $redef_email_args{ $type }{to}      = $_[2];
    $redef_email_args{ $type }{subject} = $_[3];
    $redef_email_args{ $type }{message} = $_[4];
    $redef_email_args{ $type }{type}    = $_[5];
    $redef_email_args{ $type }{attach}  = $_[6];
    $redef_email_args{ $type }{args}    = $_[7];

    if ( $ENV{HARNESS_VERBOSE} ) {
        diag "----------------------- " . caller . " -----------------------";
        diag "Subject: " . $redef_email_args{ $type }{subject};
        diag "Message:\n" . $redef_email_args{ $type }{message};
    }

    return 1;
}

# reload the SMS Methods after Rollbacks
sub _reload_methods {
    foreach my $method ( values %method_recs ) {
        $method->discard_changes;
    }
    return;
}

# helper to call the 'can_order_use_csm'
# database function
sub _call_can_order_use_csm {
    my ( $dbh, $order_id, $cust_id, $csm_id )   = @_;

    my $sql = "SELECT can_order_use_csm( $order_id, $cust_id, $csm_id );";
    my ( $result )  = $dbh->selectrow_array( $sql );
    return $result;
}
