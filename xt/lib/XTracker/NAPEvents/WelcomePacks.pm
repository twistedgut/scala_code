package XTracker::NAPEvents::WelcomePacks;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;

use XTracker::Config::Local     qw( config_var );


sub handler {
    my $handler = XTracker::Handler->new( shift );

    my $schema = $handler->schema;

    $handler->{data}{section}       = 'NAP Events';
    $handler->{data}{subsection}    = 'Welcome Packs';
    $handler->{data}{content}       = 'marketing_promotion/welcome_packs.tt';
    $handler->{data}{css}           = [ '/css/nap_events_welcome_packs.css' ];
    $handler->{data}{js}            = [ '/javascript/nap_events_welcome_packs.js' ];

    my @channels = $schema->resultset('Public::Channel')
                            ->enabled_channels
                              ->all;

    CHANNEL:
    foreach my $channel ( @channels ) {
        my $group       = $channel->config_groups->find( { name => 'Welcome_Pack' } );
        next CHANNEL    if ( !$group );

        my @settings= $group->config_group_settings
                                ->search( {}, { order_by => 'setting' } )
                                    ->all;

        # Get the Welcome Packs assigned to the Channel
        my @packs;
        foreach my $setting ( @settings ) {
            my $language_code   = lc( $setting->setting );
            $language_code      = config_var('Customer', 'default_language_preference')
                                    if ( $language_code eq 'default' );

            my $pack    = $channel->find_welcome_pack_for_language( $language_code );
            if ( $pack ) {
                push @packs, {
                    welcome_pack    => $pack,
                    config_setting  => $setting,
                    language        => $schema->resultset('Public::Language')
                                                ->find( { code => $language_code } ),
                    is_turned_on    => ( lc( $setting->value ) eq 'on' ? 1 : 0 ),
                };
            }
        }
        next CHANNEL        if ( !@packs );

        $handler->{data}{channels}{ $channel->name } = {
            channel     => $channel,
            config_group=> $group,
            packs       => \@packs,
        }
    }

    $handler->{data}{change_log}    = $schema->resultset('Public::LogWelcomePackChange')
                                                ->get_config_changes
                                                    ->order_by_date_id
                                                        ->for_page;

    return $handler->process_template;
}

1;
