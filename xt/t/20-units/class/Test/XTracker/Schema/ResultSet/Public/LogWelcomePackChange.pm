package Test::XTracker::Schema::ResultSet::Public::LogWelcomePackChange;
use NAP::policy "tt", qw/test class/;
BEGIN {
    extends 'NAP::Test::Class';
};

=head1 Test::XTracker::Schema::ResultSet::Public::LogWelcomePackChange

Tests ResultSet methods used for the 'log_welcome_pack_change' table.

=cut

use Test::XTracker::Data;

use XTracker::Constants             qw( :application );
use XTracker::Constants::FromDB     qw( :welcome_pack_change );

use List::Util                      qw( shuffle );


sub startup : Test( startup => 0 ) {
    my $self = shift;

    $self->SUPER::startup();

    $self->{schema}     = Test::XTracker::Data->get_schema;
    $self->{channels}   = {
        map { $_->business->config_section => $_ }
            $self->schema->resultset('Public::Channel')->all
    };
    $self->{languages}  = [
        $self->schema->resultset('Public::Language')->all
    ];
    $self->{op_id}      = $APPLICATION_OPERATOR_ID;

    $self->{log_rs}     = $self->schema->resultset('Public::LogWelcomePackChange');
}

sub setup : Test( setup => 0 ) {
    my $self = shift;

    $self->SUPER::setup();

    $self->schema->txn_begin;

    $self->_create_test_settings;
    $self->log_rs->delete;
}

sub teardown : Test( teardown => 0 ) {
    my $self    = shift;

    $self->schema->txn_rollback;

    $self->SUPER::teardown();
}

=head1 TESTS

=head2 test_get_config_changes

=cut

sub test_get_config_changes : Tests {
    my $self    = shift;

    my $language    = $self->{languages}[0];

    my $group   = $self->{test_data}{groups}{NAP};
    my $setting = $self->{test_data}{settings}{NAP}{ $language->code };

    my @log_recs;

    # create a 'setting' change log
    push @log_recs, $self->log_rs->create( {
        welcome_pack_change_id  => $WELCOME_PACK_CHANGE__CONFIG_SETTING,
        affected_id             => $setting->id,
        value                   => 'Off',
        operator_id             => $self->{op_id},
    } );

    # create a 'group' change log
    push @log_recs, $self->log_rs->create( {
        welcome_pack_change_id  => $WELCOME_PACK_CHANGE__CONFIG_GROUP,
        affected_id             => $group->id,
        value                   => 1,
        operator_id             => $self->{op_id},
    } );

    my @got = $self->log_rs->get_config_setting_changes->all;
    cmp_ok( @got, '==', 1, "'get_config_setting_changes' returned 1 record" );
    cmp_ok( $got[0]->id, '==', $log_recs[0]->id, "and is for the correct Log record" );

    @got    = $self->log_rs->get_config_group_changes->all;
    cmp_ok( @got, '==', 1, "'get_config_group_changes' returned 1 record" );
    cmp_ok( $got[0]->id, '==', $log_recs[1]->id, "and is for the correct Log record" );

    @got    = $self->log_rs->get_config_changes->order_by_id->all;
    cmp_ok( @got, '==', 2, "'get_config_group_changes' returned 2 records" );
    is_deeply(
        [ map { $_->id } @got ],
        [ map { $_->id } @log_recs ],
        "and for the correct Log records"
    );
}

=head2 test_for_page

Tests the 'for_page' Result Set method used for displaying the logs on a page.

=cut

sub test_for_page : Tests {
    my $self    = shift;

    my %languages   = (
        map { $_->code => $_ }
            @{ $self->{languages} }
    );
    my $groups      = $self->{test_data}{groups};
    my $settings    = $self->{test_data}{settings};

    my @log_recs;

    # specify the Logs to create
    my @create_logs = (
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_GROUP, channel => 'NAP',
          affected => $groups->{NAP}, value => 0 },
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_SETTING, channel => 'MRP',
          affected => ( shuffle( values %{ $settings->{MRP} } ) )[0], value => 'On' },
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_SETTING, channel => 'JC',
          affected => ( shuffle( values %{ $settings->{JC} } ) )[0], value => 'Off' },
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_GROUP, channel => 'OUTNET',
          affected => $groups->{OUTNET}, value => 1 },
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_GROUP, channel => 'JC',
          affected => $groups->{JC}, value => 1 },
        { change_id => $WELCOME_PACK_CHANGE__CONFIG_SETTING, channel => 'OUTNET',
          affected => ( shuffle( values %{ $settings->{OUTNET} } ) )[0], value => 'On' },
    );

    my @expect;
    foreach my $create ( @create_logs ) {
        my $log = $self->log_rs->create( {
            welcome_pack_change_id  => $create->{change_id},
            affected_id             => $create->{affected}->id,
            value                   => $create->{value},
            operator_id             => $self->{op_id},
        } );

        my $change_id   = $create->{change_id};
        my $affected    = $create->{affected};
        my $channel     = $self->{channels}{ $create->{channel} };

        push @expect, {
            log => methods(
                id      => $log->id,
                value   => $create->{value},
            ),
            affected    => methods(
                id  => $affected->id,
                (
                    # check these to make sure the
                    # affected record is correct
                    $change_id == $WELCOME_PACK_CHANGE__CONFIG_GROUP
                    ? ( channel_id => ignore() )
                    : ( setting    => ignore() )
                ),
            ),
            date    => ignore(),
            time    => ignore(),
            channel => methods(
                id  => $channel->id,
            ),
            config_section  => $create->{channel},
            description     => (
                $change_id == $WELCOME_PACK_CHANGE__CONFIG_GROUP
                ? 'All Packs'
                : $languages{ $affected->setting }->description
            ),
            value   => (
                $change_id == $WELCOME_PACK_CHANGE__CONFIG_SETTING
                ? $create->{value}
                : ( $create->{value} ? 'Enabled' : 'Disabled' )
            ),
        };
    }

    my $got = $self->log_rs->for_page;
    cmp_deeply(
        $got,
        bag( @expect ),
        "'for_page' returned as Expected"
    );
}

#--------------------------------------------------------------------------

sub log_rs {
    my $self    = shift;
    return $self->{log_rs};
}

sub _create_test_settings {
    my $self    = shift;

    $self->{test_data}  = ();
    Test::XTracker::Data->remove_config_group('Welcome_Pack');

    foreach my $conf_section ( keys %{ $self->{channels} } ) {
        my $channel = $self->{channels}{ $conf_section };
        my $group = Test::XTracker::Data->create_config_group( 'Welcome_Pack', {
            channel     => $channel,
            settings    => [
                map { { setting => $_->code, value => 'On' } }
                    @{ $self->{languages} }
            ],
        } );

        $self->{test_data}{groups}{ $conf_section }   = $group;
        $self->{test_data}{settings}{ $conf_section } = {
            map { $_->setting => $_ }
                $group->config_group_settings->all
        };
    }

    return;
}
