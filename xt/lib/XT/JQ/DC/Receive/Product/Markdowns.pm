package XT::JQ::DC::Receive::Product::Markdowns;

use Moose;

use Data::Dump qw/pp/;

use MooseX::Types::Moose qw(Str Int Num ArrayRef);
use MooseX::Types::Structured qw( Dict Optional );


use namespace::clean -except => 'meta';
use XTracker::Database::Product         qw( get_product_channel_info );
use XTracker::Database::Pricing         qw( set_markdown );
use XTracker::Database::Channel         qw( get_channels get_channel_details );
use XTracker::Comms::DataTransfer       qw( :transfer_handles transfer_product_data );

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    required => 1,
    isa => Dict[
        channel_id  => Int,
        start       => Str,
        markdowns   => ArrayRef[
        Dict[
                product_id  => Int,
                percentage  => Num,
                category_id => Int,
                category    => Str,
            ]
        ],
        remote_targets => Optional[ArrayRef[Str]]
    ]

);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub do_the_task {
    my ($self, $job) = @_;

    # get channel id and start date for markdowns
    my $channel_id = $self->payload->{channel_id};
    my $start_date = $self->payload->{start};

    # get all available channels for DC
    my $channels = get_channels( $self->dbh );

    # channel doesn't exist on this DC - skip the job
    if ( !exists $channels->{ $self->payload->{channel_id} } ) {
        return();
    }


    # open website db connection for given channel
    my $transfer_dbh_ref;
    eval {
        $transfer_dbh_ref = get_transfer_sink_handle( {
                environment => 'live',
                channel => $channels->{$self->payload->{channel_id}}{config_section}
        } );
        $transfer_dbh_ref->{dbh_source} = $self->dbh;
    };
    if ($@) {
        $job->failed( $@ );
        return ();
    }

    # something to track completed and failed markdowns
    my $num_complete    = 0;
    my $num_failed      = 0;
    my $error_msg       = '';

    # process markdown for each product
    foreach my $record ( @{ $self->payload->{markdowns} } ) {
        eval {
            my $schema = $self->schema;
            my $guard = $schema->txn_scope_guard;

            # create XT record
            set_markdown(
                $self->dbh,
                {
                    product_id  => $record->{product_id},
                    percentage  => $record->{percentage},
                    start_date  => $start_date,
                    category    => $record->{category},
                }
            );

            # push markdowns to website if product is live on the channel
            my $active_channel_name;
            my $product = $schema->resultset('Public::Product')->find(
                $record->{product_id},
            );
            $active_channel_name = $product->get_current_channel_name() if $product;

            my $channel_data    = get_product_channel_info(
                $self->dbh, $record->{product_id}
            );

            if ( $channel_data->{ $active_channel_name }{channel_id} == $channel_id
                && $channel_data->{ $active_channel_name }{live} == 1 ) {
                transfer_product_data(
                    {
                        dbh_ref             => $transfer_dbh_ref,
                        channel_id          => $channel_id,
                        product_ids         => $record->{product_id},
                        transfer_categories => 'catalogue_markdown',
                        sql_action_ref      => { catalogue_markdown => {insert => 1} },
                    }
                );
            }

            $guard->commit();
            $transfer_dbh_ref->{dbh_sink}->commit();
            $num_complete++;
        };

        if($@){
            $transfer_dbh_ref->{dbh_sink}->rollback();

            $num_failed++;
            $error_msg .= "Markdown failed for "
                            . $record->{product_id}
                            ." - Error: ". $@ ."\r\n";
        }
    }

    if ( $num_failed > 0 ) {
        die $error_msg;
    }

    return;

}

sub check_job_payload {
    my ($self, $job) = @_;

    # validate start date format
    unless ( $self->payload->{start} =~ m/\d{4}-\d{2}-\d{2}/ ) {
        return (
            'Markdown start date does not match expected format YYYY-MM-DD : '
            . $self->payload->{start}
        );
    }

    # validate markdown % is sensible
    foreach my $record ( @{ $self->payload->{markdowns} } ) {
        unless ( $record->{percentage} >= 0 && $record->{percentage} < 100 ) {
            return (
                'Markdown % for product_id '
              . $record->{product_id}
              . ' is not within expected range of 0-100 : '
              . $record->{percentage} );
        }
    }

    return ();
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::Markdowns - Notification of product markdowns for
a given channel received from Fulcrum

=head1 DESCRIPTION

This message contains a list of products and markdown percentages entered by user
into Fulcrum.
