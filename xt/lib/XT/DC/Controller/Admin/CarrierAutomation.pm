package XT::DC::Controller::Admin::CarrierAutomation;

use NAP::policy qw( class );
use XTracker::Config::Local qw( config_var sys_config_var );
use XTracker::Constants     qw( :carrier_automation );
use XTracker::Constants::FromDB qw( :carrier );
use XTracker::Config::Parameters qw( sys_param);

BEGIN { extends 'Catalyst::Controller' };

=head1 NAME

XT::DC::Controller::Admin::CarrierAutomation

=head1 DESCRIPTION

Controller for /Admin/CarrierAutomation which is used to switch on or off the
carrier automation status for UPS (on a per-channel basis) and DHL shipments.

=head1 METHODS

=cut

sub root : Chained('/') PathPart('Admin/CarrierAutomation') CaptureArgs(0) {
    my ($self, $c) = @_;
    $c->check_access('Admin', 'CarrierAutomation');
}

=head2 carrier_automation

Action for Admin/CarrierAutomation

=cut

sub carrier_automation : Chained('root') PathPart('') Args() ActionClass('REST') { }


=head2 carrier_automation_GET

GET REST action for Admin/CarrierAutomation

Populates the page with current Carrier Automation statuses for UPS (per channel)
and DHL (not on per channel basis) shipments.

=cut

sub carrier_automation_GET {
    my ( $self, $c ) = @_;

    # foreach channel get the current setting for the Automation State
    my $schema    = $c->model('DB')->schema;

    if ( config_var( 'UPS', 'enabled' ) ) {
        $c->stash(
            channel_list   => $schema->resultset('Public::Channel')->get_channels(),
            ups_state_list => \@CARRIER_AUTOMATION_STATES,
        );
    }

    $c->stash(
        dhl_ca_status  => sys_param('dhl_carrier_automation/is_dhl_automated'),
    );

    return;
}

=head2 carrier_automation_POST

POST REST action for Admin/CarrierAutomation

Updates the Carrier Automation statuses for UPS (per channel) and DHL (not on
per channel basis) shipments.

=cut

sub carrier_automation_POST {
    my ( $self, $c ) = @_;

    my $schema = $c->model('DB')->schema;

    try {
        my $txn = $schema->txn_scope_guard;

        foreach my $param (keys %{$c->req->params}){
            my $value = $c->req->param($param);
            my ( $config_update_msg, $carrier_tag );
            if ( $param =~ /^ups_state_(\d*)$/ ) {
                if ( grep { $_ eq $value } @CARRIER_AUTOMATION_STATES) {
                    my $channel_row = $schema->resultset('Public::Channel')->find( $1 );
                    $config_update_msg = $channel_row->update_carrier_automation_state( $value );
                }
                $carrier_tag = 'UPS';
            }
            elsif ( $param =~ /^dhl_state/  ) {
                if ( $value =~ /^[0-1]$/ ) {
                    $config_update_msg = sys_param('dhl_carrier_automation/is_dhl_automated', $value);
                }
                $carrier_tag = 'DHL';
            }
            else {
                next;
            }
            unless ( defined $config_update_msg ) {
                $c->feedback_warn( "Unable to update $carrier_tag Carrier Automation State Setting to $value" );
                $c->detach;
            }
        }
        $txn->commit();
        $c->feedback_success("Updated Carrier Automation State");
    }
    catch {
        $c->feedback_warn( "Unable to update Carrier Automation State Settings" );
    };
    $c->response->redirect( $c->uri_for_action('/admin/carrierautomation/carrier_automation') );

    return;
}

__PACKAGE__->meta->make_immutable;

1;
