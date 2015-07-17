package XTracker::Admin::FraudRules;

use NAP::policy "tt";

use XTracker::Handler;
use XTracker::Error;

sub handler {
    my $handler = XTracker::Handler->new( shift );

    $handler->{data}{content}   = 'shared/admin/fraud_rules.tt';
    $handler->{data}{section}   = 'Fraud Rules';
    $handler->{data}{css}       = [
        '/css/fraudrules/fraudrules-admin.css',
    ];
    $handler->{data}{js}        = [
        '/javascript/fraudrules/fraudrules-admin.js',
    ];

    $handler->{data}{switches}  = {
        map { $_->id => $_ } $handler->schema->resultset('Public::Channel')->all
    };

    # if form submitted, update settings
    if ( $handler->{param_of}{submit} ) {
        my $changes;
        $handler->schema->txn_do( sub {
            $changes = _update_settings( $handler );
        } );
        if ( my $err = $@ ) {
            xt_warn( $err );
        }
        elsif ( $changes ) {
            xt_success("Switch Updated");
        }
    }

    $handler->{data}{switch_log}= [
        $handler->schema->resultset('Fraud::LogRuleEngineSwitchPosition')
                            ->in_display_order
                                ->all
    ];

    return $handler->process_template;
}

sub _update_settings {
    my $handler = shift;

    my $schema  = $handler->schema;

    my $post_ref= $handler->{param_of};

    my $changes = 0;

    # go through each Switch and see if anything has been changed
    CHANNEL:
    foreach my $channel_id ( keys %{ $handler->{data}{switches} } ) {
        my $new_position    = $post_ref->{ "switch_channel_${channel_id}" };
        next CHANNEL        if ( !$new_position );      # NO setting given don't change anything

        my $channel         = $handler->{data}{switches}{ $channel_id };
        my $current_position= $channel->get_fraud_rules_engine_switch_state;
        next CHANNEL        if ( lc( $new_position ) eq lc( $current_position ) );  # NO change

        my $setting = $schema->resultset('SystemConfig::ConfigGroupSetting')->search(
            {
                'setting'               => 'Engine',
                'config_group.name'     => 'Fraud Rules',
                'config_group.channel_id'=> $channel_id,
            },
            {
                join    => 'config_group',
            }
        )->first;

        if ( !$setting ) {
            croak "No 'Engine' Setting could be Found for Group: 'Fraud Rules' for Channel Id: ${channel_id}";
        }

        # Update the Switch Position and Log the Change
        $setting->update( { value => $new_position } );
        $channel->create_related( 'log_rule_engine_switch_positions', {
            position    => ucfirst( $new_position ),
            operator_id => $handler->operator->id,
        } );

        $changes++;
    }

    return $changes;
}

1;
