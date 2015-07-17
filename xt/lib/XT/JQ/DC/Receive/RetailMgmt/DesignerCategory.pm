package XT::JQ::DC::Receive::RetailMgmt::DesignerCategory;

use Moose;
use Moose::Util::TypeConstraints;

use MooseX::Types::Moose                qw( Str Int ArrayRef Bool);
use MooseX::Types::Structured           qw( Dict Optional );

use Data::Dump qw/pp/;

use XTracker::Constants                 qw( :application );
use XTracker::Constants::FromDB         qw( :designer_attribute_type );
use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::DB::Factory::Designer;

use namespace::clean -except => 'meta';

extends 'XT::JQ::Worker';


has payload => (
    is  => 'ro',
    isa => ArrayRef[
        Dict[
            action      => enum([qw/add delete update/]),
            name        => Str,
            channel_id  => Int,
            new_name    => Optional[Str], # update only
            designers   => Optional[ArrayRef[Str]],
        ],
    ],
    required => 1,
);


sub check_job_payload {
    return ();
}


sub do_the_task {
    my ($self, $job)    = @_;

    my $schema                  = $self->schema;
    my $channels = $schema->resultset('Public::Channel')
        ->enabled_channels_with_public_website();

    my $des_factory             = XTracker::DB::Factory::Designer->new({ schema => $schema });

    my %web_dbhs;
    my $cant_talk_to_web = 0;

    eval {
        # get website dbh (and some other stuff in the 'sink handler')
        foreach my $cid (keys %$channels){
            eval {
                $web_dbhs{$cid} = get_transfer_sink_handle({
                    environment => 'live',
                    channel => $channels->{$cid}{config_section}
                });
            };
            if ($@ || !defined $web_dbhs{$cid}->{dbh_sink}){
                $cant_talk_to_web   = 1;
                die "Can't Talk to live Web Site for Channel ".$cid." (".$channels->{$cid}{config_section}.") - ".$@;
            }
            $web_dbhs{$cid}->{dbh_source} = $schema->storage->dbh;
        }

        # do the updates
        $schema->txn_do( sub {
            ITEM:
            foreach my $item ( @{ $self->payload } ) {
                my $cid = $item->{channel_id};
                next unless $channels->{$cid}; # channel not in this DC - not our concern.


                if ($item->{action} eq 'add'){
                    my $attribute_id = $des_factory->create_category({
                        name                => $item->{name},
                        channel_id          => $cid,
                        designers           => $item->{designers},
                        operator_id         => $APPLICATION_OPERATOR_ID,
                        transfer_dbh_ref    => $web_dbhs{$cid},
                    });
                    die "Failed to create designer category $item->{name}" unless $attribute_id;
                }

                elsif ($item->{action} eq 'update') {
                    $des_factory->update_category({
                        name                => $item->{name},
                        new_name            => $item->{new_name},
                        channel_id          => $cid,
                        designers           => $item->{designers},
                        operator_id         => $APPLICATION_OPERATOR_ID,
                        transfer_dbh_ref    => $web_dbhs{$cid},
                    });
                }

                elsif ($item->{action} eq 'delete') {
                    $des_factory->delete_category({
                        name                => $item->{name},
                        channel_id          => $cid,
                        operator_id         => $APPLICATION_OPERATOR_ID,
                        transfer_dbh_ref    => $web_dbhs{$cid},
                    });
                }
            }
        });
        # commit all the changes
        $web_dbhs{$_}->{dbh_sink}->commit() foreach keys %web_dbhs;
        $web_dbhs{$_}->{dbh_sink}->disconnect() foreach keys %web_dbhs;
    };
    if (my $err = $@){
        # rollback & disconnect for the web
        foreach my $cid (keys %web_dbhs){
            next unless $web_dbhs{$cid}->{dbh_sink};
            $web_dbhs{$cid}->{dbh_sink}->rollback();
            $web_dbhs{$cid}->{dbh_sink}->disconnect();
        }

        my %exceptions  = (
            'Deadlock'      => 'retry'
        );

        my $action  = "die";
        foreach my $exception ( keys %exceptions ) {
            $action = $exceptions{$exception} if ( $err =~ /$exception/ )
        }
        if ( $action eq "retry" || $cant_talk_to_web ) {
            $job->failed( $err );
        }
        else {
            die $err;
        }
    }
}

1;


=head1 NAME

XT::JQ::DC::Receive::RetailMgmt::DesignerCategory - Add/edit/delete designers category

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::RetailMgmt::DesignerCategory message when designer categories are added/updated/removed

Expected Payload should look like:

ArrayRef[
    Dict[
        action      => enum([qw/add delete update/]),
        name        => Str,
        channel_id  => Int,
        new_name    => Optional[Str], # update only
        designers   => Optional[ArrayRef[Str]],
    ],
],
