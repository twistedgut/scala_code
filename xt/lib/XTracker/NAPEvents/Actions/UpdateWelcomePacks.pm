package XTracker::NAPEvents::Actions::UpdateWelcomePacks;

use NAP::policy     'tt';

use XTracker::Handler;
use XTracker::Error;

use XTracker::Constants::FromDB         qw( :welcome_pack_change );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema  = $handler->schema;
    my $params  = $handler->{param_of};

    my $redirect_to = "/NAPEvents/WelcomePacks";

    try {
        my $groups_and_settings = _get_groups_and_settings( $schema );
        my $groups_allowed      = $groups_and_settings->{groups};
        my $settings_allowed    = $groups_and_settings->{settings};

        my %to_update_groups;
        my %to_update_settings;

        #
        # Work out what needs to be updated
        #

        GROUP:
        foreach my $field_name ( keys %{ $params } ) {
            next GROUP      if ( $field_name !~ /^(?<prefix>conf_group_)(?<group_id>\d+)_checkbox$/ );
            my $prefix      = $+{prefix};
            my $group_id    = $+{group_id};
            my $value       = $params->{ $prefix . $group_id } // 0;

            if ( !exists( $groups_allowed->{ $group_id } ) ) {
                die "Attempted to Update a System Config Group Id: ${group_id}, that isn't a 'Welcome_Pack' Group";
            }

            if ( $groups_allowed->{ $group_id }->active != $value ) {
                $to_update_groups{ $group_id }  = {
                    rec     => $groups_allowed->{ $group_id },
                    field   => 'active',
                    value   => $value,
                }
            }
        }

        SETTING:
        foreach my $field_name ( keys %{ $params } ) {
            next SETTING    if ( $field_name !~ /^conf_setting_(?<setting_id>\d+)$/ );
            my $setting_id  = $+{setting_id};

            my $value       = $params->{ $field_name };
            next SETTING    if ( !defined $value );
            $value          = ( $value ? 'On' : 'Off' );

            if ( !exists( $settings_allowed->{ $setting_id } ) ) {
                die "Attempted to Update a System Config Setting Id: ${setting_id}, that isn't a 'Welcome_Pack' Setting";
            }

            # don't update a Group's Settings if the Group is being turned Off at the same time
            my $setting     = $settings_allowed->{ $setting_id };
            next SETTING    if (
                exists( $to_update_groups{ $setting->config_group_id } )
                && !$to_update_groups{ $setting->config_group_id }{value}
            );

            if ( lc( $setting->value ) ne lc( $value ) ) {
                $to_update_settings{ $setting_id }  = {
                    rec     => $setting,
                    field   => 'value',
                    value   => $value,
                };
            }
        }


        #
        # Now do the updating
        #

        my $log = $schema->resultset('Public::LogWelcomePackChange');

        # groups
        foreach my $to_update ( values %to_update_groups ) {
            $to_update->{rec}->update( {
                $to_update->{field} => $to_update->{value}
            } );

            $log->create( {
                welcome_pack_change_id  => $WELCOME_PACK_CHANGE__CONFIG_GROUP,
                affected_id             => $to_update->{rec}->id,
                value                   => $to_update->{value},
                operator_id             => $handler->operator_id,
            } );
        }

        # settings
        foreach my $to_update ( values %to_update_settings ) {
            $to_update->{rec}->update( {
                $to_update->{field} => $to_update->{value}
            } );

            $log->create( {
                welcome_pack_change_id  => $WELCOME_PACK_CHANGE__CONFIG_SETTING,
                affected_id             => $to_update->{rec}->id,
                value                   => $to_update->{value},
                operator_id             => $handler->operator_id,
            } );
        }

        xt_success("Welcome Packs Updated");
    }
    catch {
        my $error   = $_;
        xt_warn( "Couldn't Update Welcome Packs: ${error}" );
    };

    return $handler->redirect_to( $redirect_to );
}

# get all possingle Config Groups &
# Settings that are for Welcome Packs
sub _get_groups_and_settings {
    my $schema  = shift;

    # get all the Possible Config Groups for Welcome Packs
    my %welcome_pack_groups = map {
        $_->id => $_
    } $schema->resultset('SystemConfig::ConfigGroup')
                ->search( { name => 'Welcome_Pack' } )
                    ->all;

    # get all the Possible Config Group Settings for Welcome Packs
    my %welcome_pack_settings = map {
        $_->id => $_
    } $schema->resultset('SystemConfig::ConfigGroupSetting')
                ->search(
        {
            'config_group.name' => 'Welcome_Pack',
        },
        {
            join => 'config_group',
        }
    )->all;

    return {
        groups  => \%welcome_pack_groups,
        settings=> \%welcome_pack_settings,
    };
}

1;
