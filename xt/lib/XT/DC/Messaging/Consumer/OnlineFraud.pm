package XT::DC::Messaging::Consumer::OnlineFraud;

use NAP::policy "tt",     'class';


use XTracker::Config::Local         qw( config_var );
use XTracker::Database::Finance     qw( set_hotlist_value );

extends 'NAP::Messaging::Base::Consumer';
with 'NAP::Messaging::Role::WithModelAccess';
use XT::DC::Messaging::Spec::OnlineFraud;

# used for dumping the payload to the logs so
# that someone can see what was trying to be done
use Data::Dump      qw( pp );

sub routes {
    return {
        destination => {
            update_fraud_hotlist => {
                spec => XT::DC::Messaging::Spec::OnlineFraud->update_fraud_hotlist(),
                code => \&update_fraud_hotlist,
            },
        },
    };
}

=head1 NAME

XT::DC::Messaging::Consumer::OnlineFraud

=head1 DESCRIPTION

Consumer for Online Fraud updates.

=head1 METHODS

=head2 update_fraud_hotlist

This updates the 'hotlist_value' table with any new entries from other DCs.

=cut

has listen_for_hotlist_update => (
    is => 'ro',
    isa => 'Str',
    default => 'yes',
);

sub update_fraud_hotlist {
    my ( $self, $message, $header ) = @_;

    my $schema  = $self->model('Schema');
    my $this_dc = config_var('DistributionCentre','name');

    if ( $self->listen_for_hotlist_update() ne 'yes' ) {
        $self->log->debug("This DC doesn't listen for Updates from AMQ");
        return;
    }

    my $from_dc = $message->{from_dc};
    if ( $this_dc eq $from_dc ) {
        $self->log->debug("The message was from This DC in the first place");
        return;
    }

    # get a Sales Channel and Hotlist Field map so as to get the
    # correct id's to use from the text versions in the message
    my %channel_map = map { $_->business->config_section => $_->id }
                        $schema->resultset('Public::Channel')->all;
    my %field_map   = map { $_->field => $_->id }
                        $schema->resultset('Public::HotlistField')->all;

    foreach my $record ( @{ $message->{records} } ) {
        try {
            my $action  = $record->{action};
            given ( $action ) {
                when ( 'add' ) {
                    set_hotlist_value(
                        $schema,
                        {
                            field_id    => $field_map{ $record->{hotlist_field_name} },
                            channel_id  => $channel_map{ $record->{channel_config_section} },
                            value       => $record->{value},
                            order_nr    => (
                                # don't put another DC prefix on it if there already is one
                                $record->{order_number} && $record->{order_number} !~ m/^DC\d+: /
                                ? "${from_dc}: " . $record->{order_number}
                                : $record->{order_number}
                            ),
                        },
                    );
                }
                default {
                    $self->log->error(
                        "Unknown 'action' in message: '${action}'\n" .
                        "Record couldn't be Processed: " . pp( $record )
                    );
                }
            }
        }
        catch {
            when (m/DUPLICATE/ ) {
                $self->log->debug(
                    "Found Duplicate when updating Hotlist Value\n" .
                    "Record couldn't be Processed: " . pp( $record )
                );
            }
            default {
                $self->log->error(
                    "Error updating Hotlist Value: ${_}\n" .
                    "Record couldn't be Processed: " . pp( $record )
                );
            }
        };
    }

    return;
}
