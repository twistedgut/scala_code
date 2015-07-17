package Test::XTracker::Script::Sync::FraudHotlist;
use NAP::policy "tt",     'test';

use parent "NAP::Test::Class";

=head1 NAME

Test::XTracker::Script::Sync::FraudHotlist

=head1 DESCRIPTION

=cut

use Test::XTracker::Data;
use Test::XTracker::RunCondition   export => [ qw( $distribution_centre ) ];

use XTracker::Config::Local         qw( config_var );

use XTracker::Script::Sync::FraudHotlist;

use Test::File;
use String::Random;


# this is done once, when the test starts
sub startup : Test(startup) {
    my $self = shift;
    $self->SUPER::startup;

    $self->{schema} = Test::XTracker::Data->get_schema;
    $self->{amq}    = Test::XTracker::MessageQueue->new;
    $self->{topic}  = config_var('Producer::Sync::FraudHotlist','destination');
}

# done everytime before each Test method is run
sub setup: Test(setup) {
    my $self = shift;
    $self->SUPER::setup;

    # clear all messages from the topic
    $self->amq->clear_destination( $self->{topic} );

    # Start a transaction, so we can rollback after testing
    $self->schema->txn_begin;

    # clear out all current data
    $self->schema->resultset('Public::HotlistValue')->delete;
}

# done everytime after each Test method has run
sub teardown: Test(teardown) {
    my $self    = shift;
    $self->SUPER::teardown;

    $self->amq->clear_destination( $self->{topic} );

    # rollback changes done in a test
    # so they don't affect the next test
    $self->schema->txn_rollback;

    # clear the instance of $self->{script_obj}
    $self->{script_obj} = undef;
}


=head1 TEST METHODS

=head2 test_produce_one_message_with_all_records

This tests that the Script will produce just One AMQ Message for all records.

=cut

sub test_produce_one_message_with_all_records : Tests() {
    my $self    = shift;

    my $msg_expect  = $self->_create_test_data();

    my $obj = $self->script_obj;

    $obj->invoke;

    $self->amq->assert_messages({
        destination => $self->{topic},
        assert_count => 1,
    }, "ONE AMQ Message was produced" );
    $self->_message_ok( $msg_expect, "and Message is as Expected" );
}

=head2 test_batching_messages_sent_into_multiple_messages

This tests that the Script, when requested to do so with the '--batch' argument, will send multiple
messages with a maximum of records per batch as specified.

=cut

sub test_batching_messages_sent_into_multiple_messages : Tests() {
    my $self    = shift;

    my $msg_expect  = $self->_create_test_data();
    my $expected_message_count;
    my $batch_size  = 11;

    # split data into groups of $batch_size
    my $max_recs    = scalar( @{ $msg_expect } );
    my $remainder   = $max_recs % $batch_size;
    $expected_message_count = ( $max_recs - $remainder ) / $batch_size;
    $expected_message_count++       if ( $remainder );

    my @expected_messages;
    foreach my $idx ( 0..( $expected_message_count - 1 ) ) {
        my $start_idx   = $idx * $batch_size;
        my $end_idx     = $start_idx + ( $batch_size - 1 );
        $end_idx        = $#{ $msg_expect }     if ( $end_idx >= $#{ $msg_expect } );
        my @recs        =  @{ $msg_expect }[ $start_idx..$end_idx ];
        push @expected_messages, \@recs;
    }

    $self->_new_instance( { batch => $batch_size } );
    my $obj = $self->script_obj;

    $obj->invoke;

    $self->amq->assert_messages({
        destination => $self->{topic},
        assert_count => $expected_message_count,
    }, "Expected AMQ Messages were produced: ${expected_message_count}" );

    my $counter = 0;
    while ( my $expected_message = shift @expected_messages ) {
        $counter++;
        $self->_message_ok( $expected_message, "Message: ${counter} as Expected" );
    }
}

=head2 test_defaults

This tests that the expected defaults are used when instantiating the Script Class when NO options are passed to the Constructor.

=cut

sub test_defaults : Tests() {
    my $self    = shift;

    my $obj = $self->script_obj;

    my %expected    = (
            verbose     => 0,
            dryrun      => 0,
            max_msg_per_batch => 0,
        );
    my %got = map { $_ => $obj->$_ } keys %expected;

    is_deeply( \%got, \%expected, "Class has expected Defaults" );

    return;
}

=head2 test_when_in_verbose_mode

Tests that with the 'verbose' switch on that the script still does what it's supposed to.

=cut

sub test_when_in_verbose_mode : Tests() {
    my $self    = shift;

    my $msg_expect  = $self->_create_test_data();

    $self->_new_instance( { verbose => 1 } );
    $self->script_obj->invoke();

    $self->amq->assert_messages({
        destination => $self->{topic},
        assert_count => 1,
    }, "ONE AMQ Message was produced" );
    $self->_message_ok( $msg_expect, "and Message is as Expected" );

    return;
}

=head2 test_when_in_dryrun_mode_no_files_are_created

Tests that when the 'dryrun' switch is on that NO AMQ Messages are produced.

=cut

sub test_when_in_dryrun_mode_no_messages_sent : Tests() {
    my $self    = shift;

    $self->_create_test_data();

    # when called from the wrapper script 'verbose' will be TRUE too
    $self->_new_instance( { dryrun => 1, verbose => 1 } );

    # run the script
    $self->script_obj->invoke();

    $self->amq->assert_messages({
        destination => $self->{topic},
        assert_count => 0,
    }, "NO AMQ Messages were produced" );

    return;
}

=head2 test_wrapper_script

Tests the wrapper perl script that inbokes the Script class exists and is executable.
Then tests that it can be executed in 'dryrun' mode and NO AMQ Messages are produced

Wrapper Script:
    script/data_transfer/sync/fraud_hotlist_data.pl

=cut

sub test_script_wrapper : Tests() {
    my $self    = shift;

    my $script  = config_var('SystemPaths','xtdc_base_dir')
                  . '/script/data_transfer/sync/fraud_hotlist_data.pl';

    note "Testing Wrapper Script: ${script}";

    file_exists_ok( $script, "Wrapper Script exists" );
    file_executable_ok( $script, "and is executable" );

    note "attempt to run script in 'dryrun' mode";

    # rollback deletion of any real data (done in 'setup')
    $self->schema->txn_rollback;

    $self->schema->txn_begin;
    my $recs    = $self->_create_test_data( { return_with_objs => 1 } );
    $self->schema->txn_commit;  # need to commit the data otherwise the
                                # Script wouldn't pick up the data anyway

    system( $script, '-d' );    # run script in Dry-Run mode
    my $retval  = $?;
    if ( $retval == -1 ) {
        fail( "Script failed to Execute: ${retval}" )
    }
    else {
        cmp_ok( ( $retval & 127 ), '==', 0, "Script Executed OK: ${retval}" );
    }

    # check NO Messages created
    $self->amq->assert_messages({
        destination => $self->{topic},
        assert_count => 0,
    }, "NO AMQ Messages were produced" );

    # remove test data
    $_->delete      foreach ( @{ $recs } );

    # 'teardown' will fail if not in a transaction
    $self->schema->txn_begin;

    return;
}

#-----------------------------------------------------------------------------------------

# create Data for some of the above tests to use
# just create 53 records for the hotlist
sub _create_test_data {
    my ( $self, $args )     = @_;

    my $rstring = String::Random->new();

    my @fields  = $self->schema->resultset('Public::HotlistField')->all;
    my @channels= $self->schema->resultset('Public::Channel')->all;

    # as records are created set-up what is
    # expected to appear in the AMQ message
    my @expect_payload;

    RECORD:
    foreach my $counter ( 1..53 ) {
        my $channel = shift @channels;
        my $field   = shift @fields;

        # generate an Order Number which has
        # a value, a value with a prefix,
        # 'undef' or is empty
        my $order_nr;
        if ( $counter % 4 ) {
            $order_nr= ( $counter % 3 ? 'PRFX ' : '' );
            $order_nr   .= $counter * 1235;
        }
        elsif ( $counter % 3 ) {
            $order_nr   = '';
        }

        my $rec = $channel->create_related( 'hotlist_values', {
            hotlist_field_id    => $field->id,
            order_nr            => $order_nr,
            value               => $rstring->randregex( '\w' x 37 ),
        } );

        push @channels, $channel;
        push @fields, $field;

        if ( $args->{return_with_objs} ) {
            # if requested actual records instead
            push @expect_payload, $rec;
            next RECORD;
        }

        # expect the following in the AMQ Message
        if (defined $order_nr) {
            push @expect_payload, superhashof({
                action                  => 'add',
                hotlist_field_name      => $rec->hotlist_field->field,
                channel_config_section  => $channel->business->config_section,
                value                   => $rec->value,
                order_number            => $order_nr,
            });
        }
        else {
            push @expect_payload, all(superhashof({
                action                  => 'add',
                hotlist_field_name      => $rec->hotlist_field->field,
                channel_config_section  => $channel->business->config_section,
                value                   => $rec->value,
            }),code(sub{! exists $_[0]->{order_number} }));
        }
    }

    return \@expect_payload;
}

# get a new instance of the Script object, can
# pass options for the constructor if needed
sub _new_instance {
    my ( $self, $options )  = @_;
    $self->{script_obj} = undef;        # need this otherwise the 'SingleInstance' feature
                                        # will block new instantiations of the Class

    $self->{script_obj} = XTracker::Script::Sync::FraudHotlist->new( $options || {} );

    # need to use our copy of Schema & DBH
    $self->{script_obj}->{schema}   = $self->schema;
    $self->{script_obj}->{dbh}      = $self->schema->storage->dbh;

    return;
}

# returns the instance of the Script object
# that '_new_instance' has instantiated
sub script_obj {
    my $self    = shift;
    $self->_new_instance            if ( !$self->{script_obj} );
    return $self->{script_obj};
}

# checks that an AMQ message was as expected
sub _message_ok {
    my ( $self, $expected_recs, $test_msg ) = @_;

    my $msg = $self->amq->assert_messages( {
        destination  => $self->{topic},
        assert_header => superhashof({
            type => 'update_fraud_hotlist',
        }),
        filter_body => superhashof({
            from_dc => $distribution_centre,
            records => bag(@$expected_recs),
        }),
    }, $test_msg );

    #note p $expected_recs;

    #note "waiting input";<>;

    return;
}

sub amq {
    my $self    = shift;
    return $self->{amq};
}

sub schema {
    my $self    = shift;
    return $self->{schema};
}
