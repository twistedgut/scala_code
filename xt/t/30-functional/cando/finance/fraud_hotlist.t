#!/usr/bin/env perl

use NAP::policy "tt",     qw( class test );

BEGIN {
    extends "NAP::Test::Class";
}

=head1 NAME

fraud_hotlist.t - Tests the Fraud Hotlist page

=head2 DESCRIPTION

Verifies that correct submissions to the Fraud Hotlist page are accepted and
added to the database while invalid submissions are rejected with the correct
error message.

#TAGS finance hotlist loops cando

=cut

use Test::XTracker::Data;
use Test::XTracker::Data::AccessControls;
use Test::XT::Flow;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw (
                                            :authorisation_level
                                            :hotlist_field
                                        );

use String::Random;


sub startup : Test( startup => no_plan ) {
    my $self    = shift;

    $self->SUPER::startup;

    my $framework   = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::Finance',
        ],
    );
    my $mech    = $framework->mech;

    my ( $channel )         = $self->rs('Public::Channel')->all;
    my $max_hotlist_id      = $self->rs('Public::HotlistValue')->get_column('id')->max // 0;
    $self->{channel}        = $channel;
    $self->{hotlist_rs}     = $channel->hotlist_values->search(
        {
            id  => { '>' => $max_hotlist_id }
        },
        {
            order_by => 'id DESC',
        }
    );


    $self->{framework}  = $framework;
    $self->{mech}       = $mech;

    $self->{framework}->login_with_roles( {
        paths => [
            '/Finance/FraudHotlist%',
        ],
    } );
}

=head1 TESTS

=head2 test_adding_an_entry

Test Adding Entries and what happens when adding Duplicate entries.

=cut

sub test_adding_an_entry : Tests() {
    my $self    = shift;

    my $schema      = $self->schema;
    my $framework   = $self->{framework};
    my $mech        = $self->{mech};
    my $hotlist_rs  = $self->{hotlist_rs};
    my $channel     = $self->{channel};

    my ( $field1, $field2 ) = $schema->resultset('Public::HotlistField')->all;
    my $rstring             = String::Random->new();
    my $entry_value = 'test_' . $rstring->randregex( '\w' x 37 );

    note "Add an Entry";
    $framework->flow_mech__finance__fraud_hotlist
                ->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field1->id,
                    channel_id  => $channel->id,
                    value       => $entry_value,
                } );
    $mech->has_feedback_success_ok( qr/Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field1, $entry_value );
    _check_entry_on_page_ok( $mech, $channel, $field1, $entry_value );

    note "Add the same entry but with an Order Number";
    $framework->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field1->id,
                    channel_id  => $channel->id,
                    value       => $entry_value,
                    order_nr    => '346874846',
                } );
    $mech->has_feedback_success_ok( qr/Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field1, $entry_value, '346874846' );
    _check_entry_on_page_ok( $mech, $channel, $field1, $entry_value, '346874846' );

    note "Now Add a duplicate entry";
    $framework->errors_are_fatal(0);
    $framework->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field1->id,
                    channel_id  => $channel->id,
                    value       => $entry_value,
                } );
    $mech->has_feedback_error_ok( qr/Duplicate - No Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field1, $entry_value );
    _check_entry_on_page_ok( $mech, $channel, $field1, $entry_value );

    note "Now Add a duplicate entry - but in UPPERCASE";
    $framework->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field1->id,
                    channel_id  => $channel->id,
                    value       => uc( $entry_value ),
                } );
    $mech->has_feedback_error_ok( qr/Duplicate - No Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field1, $entry_value );
    _check_entry_on_page_ok( $mech, $channel, $field1, $entry_value );
    $framework->errors_are_fatal(1);

    note "Now Add the same value but with a different Field and Order Number";
    $framework->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field2->id,
                    channel_id  => $channel->id,
                    value       => $entry_value,
                    order_nr    => '325345345',
                } );
    $mech->has_feedback_success_ok( qr/Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field2, $entry_value, '325345345' );
    _check_entry_on_page_ok( $mech, $channel, $field2, $entry_value, '325345345' );

    note "Now Add the same value again with the different Field and NO Order Number";
    $framework->flow_mech__finance__fraud_hotlist_add_entry( {
                    field_id    => $field2->id,
                    channel_id  => $channel->id,
                    value       => $entry_value,
                } );
    $mech->has_feedback_success_ok( qr/Hotlist Entry Added/i );
    _check_entry_in_table_ok( $hotlist_rs, $field2, $entry_value );
    _check_entry_on_page_ok( $mech, $channel, $field2, $entry_value );
}

=head2 test_validating_entries

Test Validating the input when Adding an Entry.

=cut

sub test_validating_entries : Tests() {
    my $self    = shift;

    my $schema      = $self->schema;
    my $framework   = $self->{framework};
    my $mech        = $self->{mech};
    my $hotlist_rs  = $self->{hotlist_rs};
    my $channel     = $self->{channel};

    my %validation_spec = (
        $HOTLIST_FIELD__STREET_ADDRESS => {
            valid => '123 High Street',
            invalid => ' '
        },
        $HOTLIST_FIELD__TOWN_FSLASH_CITY => {
            valid => 'London',
            invalid => ''
        },
        $HOTLIST_FIELD__COUNTY_FSLASH_STATE => {
            valid => 'Manhattan',
            invalid => '       '
        },
        $HOTLIST_FIELD__POSTCODE_FSLASH_ZIPCODE => {
            valid => 'W10 1NT',
            invalid => ' '
        },
        $HOTLIST_FIELD__COUNTRY => {
            valid => 'Spain',
            invalid => 'fslajfljs'
        },
        $HOTLIST_FIELD__EMAIL => {
            valid => 'testing@hotmail.com',
            invalid => ''
        },
        $HOTLIST_FIELD__TELEPHONE => {
            valid => '07862763324',
            invalid => ' '
        },
        $HOTLIST_FIELD__CARD_NUMBER => {
            valid => '677637483728',
            invalid => '        '
        }
    );


    my $fields = $schema->resultset('Public::HotlistField')->search({});

    while(my $field = $fields->next) {
        note $field->field .' valid data';
        $framework->flow_mech__finance__fraud_hotlist_add_entry( {
            field_id    => $field->id,
            channel_id  => $channel->id,
            value       => $validation_spec{$field->id}{valid},
        } );
        $mech->has_feedback_success_ok( qr/Hotlist Entry Added/i );
        _check_entry_in_table_ok( $hotlist_rs, $field, $validation_spec{$field->id}{valid} );
        _check_entry_on_page_ok( $mech, $channel, $field, $validation_spec{$field->id}{valid} );

        note 'removing test data for ' .$field->field;
        my $hotlist_entry = $schema->resultset('Public::HotlistValue')->search({
                hotlist_field_id    =>  $field->id,
                value       =>  $validation_spec{$field->id}{valid}
            });
        ok($hotlist_entry, 'Entry found');
        $hotlist_entry->delete;

        note $field->field .' invalid data';
        $framework->errors_are_fatal(0);
        $framework->flow_mech__finance__fraud_hotlist_add_entry( {
            field_id    => $field->id,
            channel_id  => $channel->id,
            value       => $validation_spec{$field->id}{invalid},
        } );
        $self->{mech}->has_feedback_error_ok( qr/The value you have entered is not valid/i );
    }
}

=head2 test_check_acl_protection

Test the ACL Protection implemented for this page and these URLs:

    /Finance/FraudHotlist
    /Finance/FraudHotlist/Add
    /Finance/FraudHotlist/Delete

=cut

sub test_check_acl_protection : Tests() {
    my $self    = shift;

    my $framework = $self->{framework};

    # just get an entry to be added later in the test
    my $field       = $self->rs('Public::HotlistField')->first;
    my $channel     = $self->{channel};
    my $rstring     = String::Random->new();
    my $entry_value = 'test_' . $rstring->randregex( '\w' x 37 );
    my $max_id      = $self->rs('Public::HotlistValue')->get_column('id')->max // 0;

    # get the Name of the field in the format
    # used to build the Delete <form>
    my $form_field_name = lc( $field->field );
    $form_field_name    =~ s/[^\w]//g;

    # start with NO Roles
    $framework->login_with_roles( {
        # make sure Department is 'undef' as it
        # shouldn't be required for this page
        dept => undef,
    } );

    $framework->test_for_no_permissions(
        "can't access 'Finance->Fraud Hotlist'",
        flow_mech__finance__fraud_hotlist => ()
    );

    note "set Roles for Read-Only access";
    $self->{mech}->set_session_roles( '/Finance/FraudHotlist' );

    $framework->flow_mech__finance__fraud_hotlist;
    my $pg_data = $self->{mech}->as_data->{page_data};
    ok( !exists( $pg_data->{hotlist_add_entry} ), "Add Hotlist Entry table NOT found" );

    note "set Roles for Adding an Entry";
    $self->{mech}->set_session_roles( [ qw( /Finance/FraudHotlist /Finance/FraudHotlist/Add ) ] );
    $framework->flow_mech__finance__fraud_hotlist;
    $pg_data = $self->{mech}->as_data->{page_data};
    ok( exists( $pg_data->{hotlist_add_entry} ), "Add Hotlist Entry table FOUND" );

    note "remove Roles for Adding an Entry";
    my $add_args    = {
        field_id    => $field->id,
        channel_id  => $channel->id,
        value       => $entry_value,
    };
    $self->{mech}->set_session_roles( '/Finance/FraudHotlist' );
    $framework->test_for_no_permissions(
        "can't Add a Fraud Hotlist Entry",
        flow_mech__finance__fraud_hotlist_add_entry => ( $add_args )
    );
    $add_args->{value} = $entry_value .= '2';

    note "add back in Roles for Adding an Entry";
    $self->{mech}->set_session_roles( [ qw( /Finance/FraudHotlist /Finance/FraudHotlist/Add ) ] );
    $framework->flow_mech__finance__fraud_hotlist
                ->flow_mech__finance__fraud_hotlist_add_entry( $add_args );
    my $hotlist_entry = $self->rs('Public::HotlistValue')
                                ->search( { id => { '>' => $max_id } } )
                                    ->first;
    my $entry_rec = _check_entry_in_table_ok( $self->{hotlist_rs}, $field, $entry_value );

    note "make page Read-Only again";
    $self->{mech}->set_session_roles( '/Finance/FraudHotlist' );
    $framework->flow_mech__finance__fraud_hotlist;
    my $entry_onpage = _check_entry_on_page_ok( $self->{mech}, $channel, $field, $entry_value );
    ok( !exists( $entry_onpage->{Delete}{input_name} ), "NO 'Delete' checkbox on the page for Entry" );

    note "set Roles for Deleting an Entry";
    $self->{mech}->set_session_roles( [ qw( /Finance/FraudHotlist /Finance/FraudHotlist/Delete ) ] );
    $framework->flow_mech__finance__fraud_hotlist;
    $entry_onpage = _check_entry_on_page_ok( $self->{mech}, $channel, $field, $entry_value );
    ok( exists( $entry_onpage->{Delete}{input_name} ), "'Delete' checkbox NOW on the page for Entry" );

    note "remove Roles for Deleting an Entry";
    $self->{mech}->set_session_roles( '/Finance/FraudHotlist' );
    my @delete_args = (
        $form_field_name,
        { "delete-" . $entry_rec->id => 1 },
    );
    $framework->test_for_no_permissions(
        "can't Delete a Fraud Hotlist Entry",
        flow_mech__finance__fraud_hotlist_delete_entry => @delete_args
    );

    note "add back in Roles for Deleting an Entry";
    $self->{mech}->set_session_roles( [ qw( /Finance/FraudHotlist /Finance/FraudHotlist/Delete ) ] );
    $framework->flow_mech__finance__fraud_hotlist
                ->flow_mech__finance__fraud_hotlist_delete_entry( @delete_args );
    $entry_rec = $self->{hotlist_rs}->find( $entry_rec->id );
    ok( !defined $entry_rec, "Hotlist Entry record has been Deleted from the table" );
}

#-----------------------------------------------------------------

sub _check_entry_on_page_ok {
    my ( $mech, $channel, $field, $value, $order_nr )   = @_;
    $order_nr   //= '-';

    # work out the key for the Field in the page data
    my $field_key   = lc( $field->field );
    $field_key      =~ s/[^\w]//g;

    my $data = $mech->as_data->{page_data}{ "fraud_hotlist_list_${field_key}" };

    my @entries = grep {
        $_->{'Sales Channel'} eq $channel->name
                    &&
        $_->{'Order Number'} eq $order_nr
                    &&
        $_->{'Value'} =~ m/^${value}$/i
    } @{ $data };

    cmp_ok( @entries, '==', 1, "Found ONE Entry: '${value}' on the Page for Field: '" . $field->field . "'" );

    return $entries[0];
}

sub _check_entry_in_table_ok {
    my ( $hotlist_rs, $field, $value, $order_nr )   = @_;

    # if NO Order Number then
    # check for both NULL & empty
    $order_nr //= [ undef, '' ];

    my $rs  = $hotlist_rs->reset->search( {
        hotlist_field_id    => $field->id,
        order_nr            => $order_nr,
        value               => { ILIKE => $value },
    } );

    cmp_ok( $rs->count, '==', 1, "Found ONE Entry: '${value}' in the Table for Field: '" . $field->field . "'" );

    return $rs->first;
}

Test::Class->runtests;
