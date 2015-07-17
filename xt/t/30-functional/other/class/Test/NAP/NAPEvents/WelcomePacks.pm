package Test::NAP::NAPEvents::WelcomePacks;

=head1 NAME

Test::NAP::NAPEvents::WelcomePacks - Test the 'NAP Events->Welcome Packs' page

=head1 DESCRIPTION

Test the 'NAP Events->Welcome Packs' page.

#TAGS misc promotion loops

=head1 METHODS

=cut

use NAP::policy "tt",     'test';
use parent 'NAP::Test::Class';

use Test::XTracker::Data;
use Test::XT::Flow;

use XTracker::Constants::FromDB     qw( :authorisation_level :department );


sub startup : Test( startup => 1 ) {
    my $self    = shift;

    $self->SUPER::startup;

    $self->_store_existing_settings;
    $self->_remove_logs;

    $self->{channels}   = {
        map { $_->id => $_ }
                $self->schema->resultset('Public::Channel')
                                ->enabled
                                   ->all
    };

    $self->{languages}  = {
        map {
            $_->description => $_->code
        } $self->schema->resultset('Public::Language')->all
    };

    # get currently defined Welcome Packs in the
    # Promotion Type table that are linked to a Language
    my @welcome_packs   = $self->schema->resultset('Public::PromotionType')
                                        ->search(
        {
            name    => { ILIKE => 'Welcome Pack %' },
            'me.id' => { '=' => \'language__promotion_types.promotion_type_id' },
        },
        {
            '+select'   => [ qw( language.code ) ],
            '+as'       => [ qw( language_code ) ],
            join => { language__promotion_types => 'language' },
        }
    )->all;

    foreach my $pack ( @welcome_packs ) {
        push @{ $self->{welcome_packs}{ $pack->channel_id } },
                $pack;
    }

    $self->{framework}  = Test::XT::Flow->new_with_traits(
        traits => [
            'Test::XT::Flow::NAPEvents::WelcomePacks',
        ],
    );

    $self->framework->login_with_permissions( {
        perms => {
            $AUTHORISATION_LEVEL__MANAGER => [
                'NAP Events/Welcome Packs',
            ],
        },
    } );
}

sub shutdown : Test( shutdown ) {
    my $self    = shift;

    $self->SUPER::shutdown;

    $self->_restore_existing_settings;
}

sub setup : Test( setup ) {
    my $self    = shift;

    $self->SUPER::setup;
}

sub teardown : Test( teardown ) {
    my $self    = shift;

    $self->SUPER::teardown;

    $self->_restore_existing_settings;
    $self->_remove_logs;
}


=head2 test_welcome_packs_page

Runs through changing the Settings for Sales Channels and their Welcome Packs.

=cut

sub test_welcome_packs_page : Tests {
    my $self    = shift;

    my $test_data   = $self->_setup_settings_for_packs;
    my $expect      = $test_data->{expect_on_page};
    my $groups      = $test_data->{groups};
    my @pack_channels = keys %{ $groups };

    # should start with empty Logs
    $self->{expect_logs}    = [];

    $self->framework->flow_mech__napevents_welcomepacks;
    cmp_deeply( $self->pg_data, $expect, "Settings shown on Page are as expected" );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "NO Logs shown on Page are as expected" );

    # uncheck the 'Enable All Packs' option, also turning Off
    # one of the settings and check the Switch gets turned Off
    # but that the setting remains unchanged
    my $use_channel     = $pack_channels[0];
    my $use_group       = $groups->{ $use_channel };
    my ( $use_setting ) = values %{ $use_group->{settings} };
    $expect = $self->_change_what_to_expect( $expect, {
        group => {
            $use_group->{conf_section} => 0,
        },
    } );
    $self->framework->flow_mech__napevents_welcomepacks__submit( {
        switch_off_groups   => [ $use_group->{group}->id ],
        switch_off_settings => [ $use_setting->id ],
    } );
    cmp_deeply( $self->pg_data, $expect, "Switching Off a Sales Channel and NOT touching any of its Settings: ${use_channel}" );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "Logs shown on Page are as expected" );

    # switch back On the 'Enable All Packs' option, but switch Off the Pack
    $expect = $self->_change_what_to_expect( $expect, {
        group => {
            $use_group->{conf_section} => 1,
        },
        setting => {
            $use_channel => {
                $use_setting->setting => 0,
            },
        },
    } );
    $self->framework->flow_mech__napevents_welcomepacks__submit( {
        switch_on_groups    => [ $use_group->{group}->id ],
        switch_off_settings => [ $use_setting->id ],
    } );
    cmp_deeply( $self->pg_data, $expect, "Switching Back On a Sales Channel and Switching Off a Pack Setting: ${use_channel}" );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "Logs shown on Page are as expected" );

    # turn Off a Setting
    $use_channel    = $pack_channels[-1];
    $use_group      = $groups->{ $use_channel };
    ( $use_setting )= values %{ $use_group->{settings} };
    $use_setting->discard_changes->update( { value => 'On' } );     # make sure the Setting is 'On'
    $expect = $self->_change_what_to_expect( $expect, {
        setting => {
            $use_channel => {
                $use_setting->setting => 0,
            }
        },
    } );
    $self->framework->flow_mech__napevents_welcomepacks__submit( {
        switch_off_settings => [ $use_setting->id ],
    } );
    cmp_deeply( $self->pg_data, $expect, "Switching Off a Pack for a Sales Channel: ${use_channel} - " . $use_setting->setting );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "Logs shown on Page are as expected" );

    # switch back On a Setting
    $expect = $self->_change_what_to_expect( $expect, {
        setting => {
            $use_channel => {
                $use_setting->setting => 1,
            },
        },
    } );
    $self->framework->flow_mech__napevents_welcomepacks__submit( {
        switch_on_settings  => [ $use_setting->id ],
    } );
    cmp_deeply( $self->pg_data, $expect, "Switching On a Pack for a Sales Channel: ${use_channel} - " . $use_setting->setting );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "Logs shown on Page are as expected" );

    # turn on/off a few packs at once
    my $settings_for_form;
    my $settings_expect_to_change;
    foreach my $channel ( @pack_channels ) {
        my $settings    = $groups->{ $channel }{settings};
        foreach my $setting ( values %{ $settings } ) {
            my $current_setting = $setting->discard_changes->value;
            my $new_setting     = ( $current_setting eq 'On' ? 0 : 1 );

            $settings_expect_to_change->{ $channel }{ $setting->setting } = $new_setting;
            my $key_for_form    = ( $new_setting ? 'switch_on_settings' : 'switch_off_settings' );
            push @{ $settings_for_form->{ $key_for_form } }, $setting->id;
        }
    }
    $expect = $self->_change_what_to_expect( $expect, { setting => $settings_expect_to_change } );
    $self->framework->flow_mech__napevents_welcomepacks__submit( $settings_for_form );
    cmp_deeply( $self->pg_data, $expect, "Switching On/Off several Packs in one Submit" );
    cmp_deeply( $self->pg_log, bag( @{ $self->{expect_logs} } ), "Logs shown on Page are as expected" );
}

#----------------------------------------------------------------------------------

sub framework {
    my $self    = shift;
    return $self->{framework};
}

sub pg_data {
    my $self    = shift;
    my $pg_data = $self->framework->mech->as_data->{data};
    delete $pg_data->{log};
    return $pg_data;
}

sub pg_log {
    my $self    = shift;
    return $self->framework->mech->as_data->{data}{log};
}

sub _change_what_to_expect {
    my ( $self, $current, $change ) = @_;

    # get Channels by Config Section
    my $channels    = {
        map { $_->business->config_section => $_ }
            values %{ $self->{channels} }
    };

    # change switches
    foreach my $switch ( keys %{ $current->{switches} } ) {
        my $conf_section= $switch;
        $conf_section   =~ s/^conf_group_//g;
        if ( exists( $change->{group}{ $conf_section } ) ) {
            $current->{switches}{ $switch } = $change->{group}{ $conf_section };

            push @{ $self->{expect_logs} }, {
                Date            => ignore(),
                Operator        => ignore(),
                'Sales Channel' => $channels->{ $conf_section }->name,
                Description     => 'All Packs',
                Value           => (
                    $change->{group}{ $conf_section }
                    ? 'Enabled'
                    : 'Disabled'
                ),
            };
        }
    }

    # change settings
    foreach my $welcome_pack ( keys %{ $current->{tables} } ) {
        my $conf_section    = $welcome_pack;
        $conf_section       =~ s/^welcome_pack_//g;
        if ( exists( $change->{setting}{ $conf_section } ) ) {
            my $changes = $change->{setting}{ $conf_section };
            my $packs   = $current->{tables}{ $welcome_pack };
            foreach my $pack ( @{ $packs } ) {
                # get the Language Code from the Language Description
                # that appears on the page unless it says 'DEFAULT'
                my $lang_desc_code  = $pack->{Language};
                $lang_desc_code     = $self->{languages}{ $lang_desc_code }
                                        if ( $lang_desc_code ne 'DEFAULT' );
                if ( exists( $changes->{ $lang_desc_code } ) ) {
                    $pack->{Setting}    = $changes->{ $lang_desc_code };

                    push @{ $self->{expect_logs} }, {
                        Date            => ignore(),
                        Operator        => ignore(),
                        'Sales Channel' => $channels->{ $conf_section }->name,
                        Description     => $pack->{Language},
                        Value           => (
                            $changes->{ $lang_desc_code }
                            ? 'On'
                            : 'Off'
                        ),
                    };
                }
            }
        }
    }

    return $current;
}

# set-up all Config Settings for all
# existing Welcome Packs, setting them
# all to be 'Active' and 'On'
sub _setup_settings_for_packs {
    my $self    = shift;

    # will return what is expected to
    # be shown on the page
    my %expect_on_page;

    # will also return the Config Groups & Settings
    my %groups;

    Test::XTracker::Data->remove_config_group('Welcome_Pack');

    # set-up the settings for the Packs
    PACK:
    foreach my $channel_id ( keys %{ $self->{welcome_packs} } ) {
        my @packs           = sort { $a->get_column('language_code') cmp $b->get_column('language_code') }
                                        @{ $self->{welcome_packs}{ $channel_id } };
        my $channel         = $self->{channels}{ $channel_id };
        next PACK           if ( !$channel );       # Sales Channel might be Disabled

        my $conf_section    = $channel->business->config_section;

        # the Enabled flag should be TRUE
        $expect_on_page{switches}{ "conf_group_${conf_section}" } = 1;

        my @conf_settings;
        my @expect_packs;
        if ( @packs == 1 ) {
            # if there is only 1 Pack then assume it's the DEFAULT
            push @conf_settings, {
                setting => 'DEFAULT',
                value   => 'On',
            };
            # the DEFAULT pack should be 'On'
            push @expect_packs, {
                'Description in Documentation'  => $packs[0]->product_type,,
                'Message to Packers'            => $packs[0]->name,
                Language                        => 'DEFAULT',
                Setting                         => 1,
            };
        }
        else {
            foreach my $pack ( @packs ) {
                my $language    = $pack->language__promotion_types
                                        ->first->language;
                push @conf_settings, {
                    setting => $language->code,
                    value   => 'On',
                };

                push @expect_packs, {
                    'Description in Documentation'  => $pack->product_type,
                    'Message to Packers'            => $pack->name,
                    Language                        => $language->description,
                    Setting                         => 1,
                };
            }
        }
        $expect_on_page{tables}{ "welcome_pack_${conf_section}" } = \@expect_packs;

        my $group = Test::XTracker::Data->create_config_group( 'Welcome_Pack', {
            channel => $channel,
            settings=> \@conf_settings,
        } );

        $groups{ $conf_section } = {
            conf_section => $conf_section,
            group    => $group,
            settings => {
                map { $_->setting => $_ }
                    $group->config_group_settings->all
            },
        };
    }

    return {
        expect_on_page  => \%expect_on_page,
        groups          => \%groups,
    };
}

# store existing Welcome Pack Config settings
sub _store_existing_settings {
    my $self    = shift;

    my @channels = $self->schema->resultset('Public::Channel')->all;

    CHANNEL:
    foreach my $channel ( @channels ) {
        my $config_group = $channel->config_groups
                                    ->find( { name => 'Welcome_Pack' } );
        next CHANNEL        if ( !$config_group );

        my @config_settings = $config_group->config_group_settings->all;

        $self->{existing_settings}{ $config_group->id } = {
            $config_group->get_columns,
            settings => [
                map { { $_->get_columns } }
                    @config_settings
            ],
        };
    }

    return;
}

# restore existing Welcome Pack Config settings
sub _restore_existing_settings {
    my $self    = shift;

    my $config_group_rs   = $self->schema->resultset('SystemConfig::ConfigGroup');
    my $config_setting_rs = $self->schema->resultset('SystemConfig::ConfigGroupSetting');

    Test::XTracker::Data->remove_config_group( 'Welcome_Pack' );

    foreach my $group ( values %{ $self->{existing_settings} } ) {
        my %group_clone = %{ $group };
        my $settings    = delete $group_clone{settings};
        $config_group_rs->create( \%group_clone );
        foreach my $setting ( @{ $settings } ) {
            $config_setting_rs->create( $setting );
        }
    }

    return;
}

# remove the Change Logs
sub _remove_logs {
    my $self    = shift;

    $self->schema->resultset('Public::LogWelcomePackChange')->delete;

    return;
}

