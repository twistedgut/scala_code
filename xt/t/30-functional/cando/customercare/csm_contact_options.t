#!/usr/bin/env perl

use NAP::policy "tt", 'test';

=head1 NAME

csm_contact_options.t - Tests the Showing and Updating of CSM Contact Options

=head1 DESCRIPTION

This tests the Displaying and Editing of the CSM Contact Options which are
currently shown on both the Order and Customer View Pages.

Also tests that users with the correct Permissions are only allowed to edit the
options.

#TAGS orderview customerview csm checkruncondition cando

=cut



use Data::Dump qw( pp );

use Test::XTracker::Data;
use Test::XTracker::RunCondition
  export   => [qw( $distribution_centre )];
use Test::XT::Flow;

use XTracker::Config::Local qw( config_var sys_config_var );
use XTracker::Constants::FromDB qw(
  :authorisation_level
  :department
  :order_status
);

use XTracker::Utilities qw(
  unpack_csm_changes_params
);

my $schema = Test::XTracker::Data->get_schema;
isa_ok( $schema, "XTracker::Schema" );

# get a list of all the Correspondence Methods that you
# can Opt Out of which are used by the tests below
my %methods =
  map { $_->method => $_ }
  $schema->resultset('Public::CorrespondenceMethod')->all;

# store their current enabled state
my %enabled_states = map { $_->method => $_->enabled } values %methods;

# then make sure they are all enabled
$_->update( { enabled => 1 } ) foreach ( values %methods );

#--------- Tests ----------------------------------------------
_test_order_contact_options( $schema, 1 );
_test_permissions( $schema, 1 );
_test_misc( $schema, 1 );

#--------------------------------------------------------------

# restore Method Enabled states
while ( my ( $method, $state ) = each %enabled_states ) {
    $methods{$method}->update( { enabled => $state } );
}

done_testing;

#-----------------------------------------------------------------

=head1 METHODS

=head2 _test_order_contact_options

    _test_order_contact_options( $schema, $ok_to_do_flag );

This tests the ability to show and edit the 'Order Contact Options' that appear on
the Customer View page and the Order View page. These are the list of Correspondence
Subjects and Methods.

=cut

sub _test_order_contact_options {
    my ( $schema, $oktodo ) = @_;

  SKIP: {
        skip "_test_order_contact_options", 1 if ( !$oktodo );

        note "TESTING 'Order Contact Options'";

        my $framework = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment', 'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Customer',   'Test::XT::Data::Channel',
            ],
        );
        my $channel =
          $framework->channel( Test::XTracker::Data->channel_for_nap );
        my $customer = $framework->customer;

        my $orddetails = $framework->flow_db__fulfilment__create_order(
            channel  => $channel,
            products => 1,
        );
        my $order = $orddetails->{order_object};

        # update the Order to use the new Customer
        $order->update( { customer_id => $customer->id } );
        $customer->discard_changes;

        # get rid of any Orders for the Customer except the one just created
        $customer->orders->search(
            {
                'me.id'         => { '!=' => $order->id },
                order_status_id => { '!=' => $ORDER_STATUS__CANCELLED }
            }
        )->update( { order_status_id => $ORDER_STATUS__CANCELLED } );

        # create 2 subjects to use in tests
        my ( $subject, $alt_subject ) = _create_test_subjects($channel);

        $framework->login_with_permissions(
            {
                perms => {
                    $AUTHORISATION_LEVEL__OPERATOR => [
                        'Customer Care/Customer Search',
                        'Customer Care/Order Search',
                    ]
                }
            }
        );

        # The same options are visible on both the Customer View Page
        # and the Order View page so run the same tests for both

        # get data required to parse each Page - Customer View & Order View
        my $page_data = _get_page_data( $framework, $order );

        foreach my $page ( sort keys %{$page_data} ) {

            note "TESTING $page Page";

            $framework->errors_are_fatal( $page_data->{errors_are_fatal} );

            my $test_label = $page_data->{$page}{test_label};
            my $view_page  = $page_data->{$page}{view_page};
            my $record     = $page_data->{$page}{record};
            my $parse_page = $page_data->{$page}{parse_page};
            my $disclaimer = $page_data->{$page}{disclaimer};

            # clear out data for tests
            $customer->discard_changes->customer_csm_preferences->delete;
            $order->discard_changes->orders_csm_preferences->delete;

            # make sure there are no defaults overiding anything
            $customer->customer_correspondence_method_preferences->delete;
            $customer->update( { correspondence_default_preference => undef } );

            # a department which shouldn't be-able to edit the Preferences
            Test::XTracker::Data->set_department( 'it.god', 'Finance' );

            note
"Check when CANT edit Options that only the Methods that can be used are shown";

# go to the View page and check that without any Preferences set that the
# only Methods that have their 'default_can_use' field set to TRUE are shown.
# Also check that as 'it.god' not part of the Customer Care group or Shipping/Shipping Manager
# departments that the fields can't be edited
            $framework->$view_page( $record->id );
            my $data = $parse_page->($framework);
            $framework->mech->content_unlike( qr/$disclaimer/i,
                "Disclaimer message NOT shown" );
            ok(
                exists( $data->{ $subject->description } ),
                "Found Subject under 'Order Contact Options' in page"
            );
            is(
                $data->{ $subject->description },
                $methods{SMS}->description,
                "Only SMS Option Shown"
            );
            ok(
                exists( $data->{ $alt_subject->description } ),
"Found Alternative Subject under 'Order Contact Options' in page"
            );
            is(
                $data->{ $alt_subject->description },
                $methods{SMS}->description . " / "
                  . $methods{Email}->description,
                "SMS & Email Options are Shown"
            );

            note
"Check that when a user CAN edit Options that ALL Methods are shown but only the ones that can be used are CHECKED";

            # change Department which should allow editing of the Values
            Test::XTracker::Data->set_department( 'it.god', 'Customer Care' );

# go to the View page and check that without any Preferences set
# that the Methods are Turned On & Off appropriately according to their defaults
            $framework->$view_page( $record->id );
            $data = $parse_page->($framework);
            # don't use has_tag_like(); this method from dakkar behaves more
            # sensibly and survives the Test::WWW::Mechanize behaviour change
            # in 1.40
            ok(
                $framework->mech->look_down(
                    _tag => 'span',
                    sub { $_[0]->as_trimmed_text eq $disclaimer }
                ),
                'Disclaimer message IS in a span on the page'
            );

 # what is expected to be in the FORM and whether it should be checked ON or OFF
            my %expected = (
                $subject->description => {
                    subject_id => $subject->id,
                    SMS        => 'ON',
                    Phone      => 'OFF',
                },
                $alt_subject->description => {
                    subject_id => $alt_subject->id,
                    SMS        => 'ON',
                    Email      => 'ON',
                    Phone      => 'OFF',
                },
            );

            foreach my $test_subj ( keys %expected ) {
                my $test = $expected{$test_subj};
                ok(
                    exists( $data->{$test_subj} ),
"Found Subject: $test_subj, under 'Order Contact Options' in page"
                );
                my $options = $data->{$test_subj}{inputs};
                is(
                    $options->[0]{input_name},
                    'csm_subject_' . delete $test->{subject_id},
                    "Found Subject Id in Hidden Field"
                );
                shift @{$options};    # lose the hidden field for next tests
                cmp_ok( @{$options}, '==', ( scalar keys %{$test} ),
                        "Found "
                      . ( scalar keys %{$test} )
                      . " Methods for the Subject" );
                while ( my ( $method, $state ) = each %{$test} ) {
                    my ($option) =
                      grep { $_->{input_value} == $methods{$method}->id }
                      @{$options};
                    cmp_ok(
                        $option->{input_checked},
                        '==',
                        ( $state eq 'ON' ? 1 : 0 ),
                        "$method found and $state"
                    );
                    my $method_desc = $methods{$method}->description;
                    like( $data->{$test_subj}{value},
                        qr/\b$method_desc\b/,
                        "Found Description for Method: $method_desc" );
                }
            }

            note "Change Preferences of Methods";

      # because all of the Subjects are in the same FORM even if you change only
      # one of the options they all get submitted and if one of the Subjects
      # has no preferences set for the Record then they will have, after the
      # submission whether it was one of their options that changed or not.
            $framework->flow_mech__customercare__update_contact_options(
                { $subject->id => { $methods{SMS}->id => 0, }, } )
              ->mech->has_feedback_success_ok(
                qr/Order Contact Options Updated/);
            $record->discard_changes;
            my $pref_count = $record->_csm_relationship->count();
            cmp_ok( $pref_count, '>=', 5,
"Now got a minimum of 5 ($pref_count) $test_label CSM Preference records"
            );
            my $prefs = $record->get_csm_preferences( $subject->id );
            cmp_ok( scalar( keys %{$prefs} ), '==', 2,
                "Found 2 Preferences for the First Subject: "
                  . $subject->subject );
            my %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 0,
                    $methods{Phone}->id => 0,
                },
                "SMS now turned OFF, Phone also OFF"
            );
            $prefs = $record->get_csm_preferences( $alt_subject->id );
            cmp_ok( scalar( keys %{$prefs} ), '==', 3,
                "Found 3 Preferences for the Alternative Subject: "
                  . $alt_subject->subject );
            %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 1,
                    $methods{Email}->id => 1,
                    $methods{Phone}->id => 0,
                },
                "SMS is ON, Email is ON, Phone is OFF"
            );

            note "Change Preferences on Multiple Subjects at Once";

            $framework->flow_mech__customercare__update_contact_options(
                {
                    $subject->id     => { $methods{SMS}->id => 1, },
                    $alt_subject->id => {
                        $methods{SMS}->id   => 0,
                        $methods{Email}->id => 1,
                        $methods{Phone}->id => 1,
                    },
                }
              )
              ->mech->has_feedback_success_ok(
                qr/Order Contact Options Updated/);
            $record->discard_changes;
            cmp_ok( $record->_csm_relationship->count(),
                '==', $pref_count,
                "Still got $pref_count $test_label CSM Preference records" );
            $prefs = $record->get_csm_preferences( $subject->id );
            %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 1,
                    $methods{Phone}->id => 0,
                },
                "SMS now turned ON, Phone still OFF"
            );
            $prefs = $record->get_csm_preferences( $alt_subject->id );
            %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 0,
                    $methods{Email}->id => 1,
                    $methods{Phone}->id => 1,
                },
                "SMS now OFF, Email now OFF, Phone now ON"
            );

            note
"Change Nothing but Submit the FORM and expected no Success Message";
            $framework->flow_mech__customercare__update_contact_options();
            ok(
                !$framework->mech->app_status_message,
                "When nothing Changed NO Success Message Shown"
            );

            note
"Disable a Method and a Subject and expected them to disappear from the page as Options";
            $subject->update( { enabled => 0 } );
            $methods{Email}->update( { enabled => 0 } );
            $framework->$view_page( $record->id );
            $data = $parse_page->($framework);
            ok(
                !exists( $data->{ $subject->description } ),
                "Couldn't find Subject: " . $subject->description . " in Page"
            );
            my $options =
              $data->{ $alt_subject->description }
              {inputs};    # Alt. Subject should still be visible
            shift @{$options};    # lose the hidden field
            cmp_ok( @{$options}, '==', 2,
                "Only Found 2 Methods for the Alt. Subject" );
            ok(
                !grep (
                    { $_->{input_value} == $methods{Email}->id } @{$options} ),
                "Couldn't find Email Checkbox"
            );
            my $method_desc = $methods{Email}->description;
            unlike( $data->{ $alt_subject->description }{value},
                qr/\b$method_desc\b/,
                "Did NOT Find Description for Method: $method_desc" );

            $framework->flow_mech__customercare__update_contact_options();
            ok( !$framework->mech->app_status_message,
"Submit FORM with stuff Disabled but make no other changes, NO Changes were made"
            );

            $record->discard_changes;
            cmp_ok( $record->_csm_relationship->count(),
                '==', $pref_count,
                "Still got $pref_count $test_label CSM Preference records" );
            $prefs = $record->get_csm_preferences( $subject->id );
            %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 1,
                    $methods{Phone}->id => 0,
                },
                "SMS still turned ON, Phone still OFF"
            );
            $prefs = $record->get_csm_preferences( $alt_subject->id );
            %got = map { $_ => $prefs->{$_}{can_use} } keys %{$prefs};
            is_deeply(
                \%got,
                {
                    $methods{SMS}->id   => 0,
                    $methods{Email}->id => 1,
                    $methods{Phone}->id => 1,
                },
                "SMS still OFF, Email still ON, Phone still ON"
            );

            # Re-Enable
            $subject->update( { enabled => 1 } );
            $methods{Email}->update( { enabled => 1 } );

            $customer->discard_changes->customer_csm_preferences->delete;
            $order->discard_changes->orders_csm_preferences->delete;

            $framework->errors_are_fatal(1);    # restore checking for errors
        }

        # remove the new Subjects
        $subject->discard_changes->correspondence_subject_methods->delete;
        $alt_subject->discard_changes->correspondence_subject_methods->delete;
        $subject->delete;
        $alt_subject->delete;
    }

    return;
}

=head2 _test_permissions

    _test_permissions( $schema, $ok_to_do_flag );

This tests that only users with the correct Permissions can edit the Options.

=cut

sub _test_permissions {
    my ( $schema, $oktodo ) = @_;

  SKIP: {
        skip "_test_permissions", 1 if ( !$oktodo );

        note "TESTING 'Permissions'";

        note
          "Checking Permissions for those who Can & Can't Edit the Preferences";

        my $framework = Test::XT::Flow->new_with_traits(
            traits => [
                'Test::XT::Flow::Fulfilment', 'Test::XT::Flow::CustomerCare',
                'Test::XT::Data::Channel',
            ],
        );
        my $channel =
          $framework->channel( Test::XTracker::Data->channel_for_nap );

        my $orddetails = $framework->flow_db__fulfilment__create_order(
            channel  => $channel,
            products => 1,
        );
        my $order    = $orddetails->{order_object};
        my $customer = $order->customer;

        # create 2 subjects to use in tests
        my ( $subject, $alt_subject ) = _create_test_subjects($channel);

        my %departments =
          map { $_->id => $_ } $schema->resultset('Public::Department')->all;
        my @can_edit = map { delete $departments{$_} } (
            $DEPARTMENT__SHIPPING,              $DEPARTMENT__SHIPPING_MANAGER,
            $DEPARTMENT__PERSONAL_SHOPPING,     $DEPARTMENT__FASHION_ADVISOR,
            $DEPARTMENT__CUSTOMER_CARE_MANAGER, $DEPARTMENT__CUSTOMER_CARE,
        );
        my @cant_edit = values %departments;

        $framework->login_with_permissions(
            {
                perms => {
                    $AUTHORISATION_LEVEL__OPERATOR => [
                        'Customer Care/Customer Search',
                        'Customer Care/Order Search',
                    ]
                }
            }
        );

        # get data required to parse each Page - Customer View & Order View
        my $page_data = _get_page_data( $framework, $order );

        foreach my $page ( sort keys %{$page_data} ) {

            note "TESTING $page Page";

            $framework->errors_are_fatal( $page_data->{errors_are_fatal} );

            my $view_page  = $page_data->{$page}{view_page};
            my $record     = $page_data->{$page}{record};
            my $parse_page = $page_data->{$page}{parse_page};

            foreach my $dept (@cant_edit) {
                Test::XTracker::Data->set_department( 'it.god',
                    $dept->department );
                $framework->$view_page( $record->id );
                my $data = $parse_page->($framework);

                # if there are NO checkboxes then ref should just
                # return an empty string meaning nothing can be edited
                is(
                    ref( $data->{ $subject->description } ),
                    "",
                    "Department: " . $dept->department . " CAN'T edit Options"
                );
            }
            foreach my $dept (@can_edit) {
                Test::XTracker::Data->set_department( 'it.god',
                    $dept->department );
                $framework->$view_page( $record->id );
                my $data = $parse_page->($framework);

                # if there are checkboxes then ref should return a HASH
                is( ref( $data->{ $subject->description } ),
                    "HASH",
                    "Department: " . $dept->department . " CAN edit Options" );
            }

            $framework->errors_are_fatal(1);
        }

        $subject->discard_changes->correspondence_subject_methods->delete;
        $alt_subject->discard_changes->correspondence_subject_methods->delete;
        $subject->delete;
        $alt_subject->delete;
    }

    return;
}

=head2 _test_misc

    _test_misc( $schema, $ok_to_do_flag );

This will test miscellaneous functions/methods used by the pages tested above.

=cut

sub _test_misc {
    my ( $schema, $oktodo ) = @_;

  SKIP: {
        skip "_test_misc", 1 if ( !$oktodo );

        note "TESTING 'Miscellaneous'";

        note "Testing 'unpack_csm_changes_params' function";
        my $csm_changes = unpack_csm_changes_params(
            {
                ignore_param            => 'rubbish',
                csm_subject_method3     => 3,          # shouldn't get picked up
                csm_subject_method_1    => [ 2, 3 ],
                csm_subject_method_2    => [ 3, 1, 2 ],
                csm_subject_method_5    => 4,
                csm_subject_method_4s   => 1,          # shouldn't get picked up
                ccsm_subject_method_6   => 4,          # shouldn't get picked up
                dont_care_what_this_is  => 0,
                csm_subject_7           => 7,
                ccsm_subject_8          => 8,
                ccsm_subject_9s         => 9,
                csm_subject__method_10  => 1,
                csm_subject__11         => 11,
                csm_subject_method__12  => 4,
                csm_subject__method__13 => 2,
                something_else          => undef,
            }
        );
        isa_ok( $csm_changes, 'HASH',
            "'unpack_csm_changes_params' returned Type as Expected" );
        is_deeply(
            $csm_changes,
            {
                1 => {
                    2 => 1,
                    3 => 1,
                },
                2 => {
                    1 => 1,
                    2 => 1,
                    3 => 1,
                },
                5 => { 4 => 1, },
                7 => {},
            },
            "'unpack_csm_changes_params' returned Data as Expected"
        );

        # again with a realist examples
        $csm_changes = unpack_csm_changes_params(
            {
                csm_subject_1          => 1,
                csm_subject_36         => 36,
                csm_subject_37         => 37,
                csm_subject_method_1   => [ 1, 2 ],
                csm_subject_method_36  => 1,
                csm_subject_method_37  => 3,
                customer_id            => 1,
                update_contact_options => "Submit \xC2\xBB",
            }
        );
        is_deeply(
            $csm_changes,
            {
                1 => {
                    1 => 1,
                    2 => 1,
                },
                36 => { 1 => 1, },
                37 => { 3 => 1, },
            },
"'unpack_csm_changes_params' returned Data as Expected for Realistic Example 1"
        );

        $csm_changes = unpack_csm_changes_params(
            {
                csm_subject_1          => 1,
                csm_subject_38         => 38,
                csm_subject_39         => 39,
                csm_subject_method_1   => [ 1, 2 ],
                csm_subject_method_39  => [ 1, 2 ],
                customer_id            => 1,
                update_contact_options => "Submit \xC2\xBB",

            }
        );
        is_deeply(
            $csm_changes,
            {
                1 => {
                    1 => 1,
                    2 => 1,
                },
                38 => {},
                39 => {
                    1 => 1,
                    2 => 1,
                },
            },
"'unpack_csm_changes_params' returned Data as Expected for Realistic Example 2"
        );
    }

    return;
}

#-----------------------------------------------------------------

=head2 _get_page_data

    $hash_ref = _get_page_data( $framework, $dbic_order );

Helper to get the different information required for the Customer & Order view pages.

=cut

sub _get_page_data {
    my ( $framework, $order ) = @_;

    return {
        'Customer View' => {
            test_label => 'Customer',
            view_page  => 'flow_mech__customercare__customerview',
            record     => $order->customer,
            parse_page => sub {
                my $framework = shift;
                return $framework->mech->as_data->{page_data}{contact_options}
                  {data};
            },
            disclaimer =>
"Any changes to the above will also update the same options on any Un-Dispatched Orders for the Customer",
            errors_are_fatal => 0
            , # avoid know error communicating with Stomp on the Customer View page
        },
        'Order View' => {
            test_label => 'Order',
            view_page  => 'flow_mech__customercare__orderview',
            record     => $order,
            parse_page => sub {
                my $framework = shift;
                return $framework->mech->as_data->{meta_data}
                  {'Order Contact Options'};
            },
            disclaimer =>
"Any changes to the above will ONLY apply to this Order, go to the Customer View page to make changes globally",
            errors_are_fatal => 1,
        },
    };
}

=head2 _create_test_subjects

    ( $subject, $alt_subject ) = _create_test_subjects( $dbic_channel );

Helper to create Test Subjects.

=cut

sub _create_test_subjects {
    my $channel = shift;

# create new Correspondence Subjects & assiciate a Correspondence Methods to them
    my $subject = $channel->create_related(
        'correspondence_subjects',
        {
            subject     => 'Test Subject' . $$,
            description => 'Test Subject Description',
        }
    );
    my $alt_subject = $channel->create_related(
        'correspondence_subjects',
        {
            subject     => 'Alternative Test Subject' . $$,
            description => 'Alternative Test Subject Description',
        }
    );
    _add_csm_method(
        $subject,
        {
            method_id       => $methods{SMS}->id,
            can_opt_out     => 1,
            default_can_use => 1
        }
    );
    _add_csm_method(
        $subject,
        {
            method_id       => $methods{Phone}->id,
            can_opt_out     => 1,
            default_can_use => 0
        }
    );
    _add_csm_method(
        $alt_subject,
        {
            method_id       => $methods{SMS}->id,
            can_opt_out     => 1,
            default_can_use => 1
        }
    );
    _add_csm_method(
        $alt_subject,
        {
            method_id       => $methods{Email}->id,
            can_opt_out     => 1,
            default_can_use => 1
        }
    );
    _add_csm_method(
        $alt_subject,
        {
            method_id       => $methods{Phone}->id,
            can_opt_out     => 1,
            default_can_use => 0
        }
    );

    note "Subject     : " . $subject->id . ' - ' . $subject->subject;
    note "Alt. Subject: " . $alt_subject->id . ' - ' . $alt_subject->subject;

    return ( $subject, $alt_subject );
}

=head2 _add_csm_method

    _add_csm_method( $subject, $args );

Helper to associate a Correspondence Method to a Subject.

=cut

sub _add_csm_method {
    my ( $subject, $args ) = @_;

    $subject->create_related(
        'correspondence_subject_methods',
        {
            correspondence_method_id => $args->{method_id},
            can_opt_out              => $args->{can_opt_out},
            default_can_use          => $args->{default_can_use},
        }
    );

    return;
}
