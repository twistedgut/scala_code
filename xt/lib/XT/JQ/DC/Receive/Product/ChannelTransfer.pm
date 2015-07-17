package XT::JQ::DC::Receive::Product::ChannelTransfer;

use Moose;

use Data::Dump qw/pp/;
use Try::Tiny;
use XTracker::Logfile 'xt_logger';

use MooseX::Types::Moose qw(Str Int Num ArrayRef);
use MooseX::Types::Structured qw(Dict Optional);


use namespace::clean -except => 'meta';
use XTracker::Database::Product         qw( create_product_channel create_new_channel_navigation_attributes );
use XTracker::Database::ChannelTransfer qw( set_product_transfer_status create_channel_transfer );
use XTracker::Constants::FromDB         qw( :product_channel_transfer_status :channel_transfer_status );
use XTracker::Database::Channel         qw( get_channels );

extends 'XT::JQ::Worker';


has payload => (
    is => 'ro',
    required => 1,
    isa => Dict[
        source_channel  => Int,
        dest_channel    => Int,
        currency        => Str,
        operator_id     => Int,
        products        => ArrayRef[
            Dict[
                product    => Int,
                price      => Num,
                navigation => Optional[
                    Dict[
                        classification => Str,
                        product_type   => Str,
                        sub_type       => Str
                    ],
                ],
            ],
        ],
    ],
);

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub do_the_task {
    my ($self, $job) = @_;

    my $channels = get_channels( $self->dbh );

    my $has_source_channel = (exists $channels->{ $self->payload->{ source_channel } });
    my $has_dest_channel = (exists $channels->{ $self->payload->{ dest_channel } });

    if (!$has_source_channel || !$has_dest_channel) {
        xt_logger->error("Channel Transfer for payload because of a missing source/dest field");
        return ();
    }

    # process each product in payload
    $self->schema->txn_do(sub {
        foreach my $product ( @{$self->payload->{products}} ) {
            try {
                xt_logger->info("Channel Transfer for PID Started (pid=". $product->{product} . ")");
                $self->process_product($product);
            } catch {
                xt_logger->error("Channel Transfer for PID Failed (pid=". $product->{product} . ",reason=$_)");
            };
        }
    });
}

sub check_job_payload {
    my ($self, $job) = @_;

    my $channels_rs = $self->schema->resultset('Public::Channel');

    # check that source and destination channels are for the same client
    # (so that NAP stock can't be transferred to Jimmy Choo, for instance)

    my $get_client_id = sub {
        my $type = shift;

        my $channel_id = $self->payload->{"${type}_channel"} // return 0;
        my $channel = $channels_rs->find( $channel_id );

        return $channel->business->client->id;
    };

    if ($get_client_id->('source') != $get_client_id->('dest')) {
        die 'Source and destination channels must belong to the same client for a channel transfer';
    }

    # per-product sanity checks
    my @errors;
    my $product_rs = $self->schema->resultset('Public::Product');
    my @transfer_products = @{ $self->payload->{products} };
    for my $product_id ( map { $_->{product} } @{ $self->payload->{products} } ) {
        # product should exist
        my $product = $product_rs->find( $product_id );
        die "Unknown product id $product_id in channel transfer request" unless $product;
        # product should not have outstanding channel transfers
        my @pending_transfers = $product->channel_transfers->search(
            {
                status_id => { '-not_in' => [ $CHANNEL_TRANSFER_STATUS__COMPLETE ] },
            },
        );
        if (@pending_transfers) {
            # transfers outstanding - check what kind so we can report suitable error
            if (@pending_transfers > 1) {
                # this shouldn't happen as we should already be rejecting the
                # second one
                die "multiple channel transfers already exist for product $product_id";
            }

            # look at existing channel transfer and check whether or not source channel matches
            my $existing_transfer = shift @pending_transfers;
            my $error_msg = "channel transfer already requested for product $product_id";
            if ($existing_transfer->from_channel_id == $self->payload->{source_channel}) {
                # check whether or not destination channel matches
                if ($existing_transfer->to_channel_id == $self->payload->{dest_channel}) {
                    $error_msg = "duplicate channel transfer requested for product $product_id";
                } else {
                    $error_msg = "conflicting channel transfer requested for product $product_id";
                }
            }
            push @errors, $error_msg;
        }
    }

    if (@errors) {
        xt_logger->error("Channel Transfer Error: $_") foreach (@errors);
        die join("\n", @errors);
    }

    return ();
}

sub process_product {
    my ($self, $product) = @_;

    # set transfer status on source channel
    set_product_transfer_status(
        $self->dbh,
        {
            product_id  => $product->{product},
            channel_id  => $self->payload->{source_channel},
            status_id   => $PRODUCT_CHANNEL_TRANSFER_STATUS__REQUESTED,
            operator_id => $self->payload->{operator_id},
        }
    );

    # create channel record on destination channel
    create_product_channel(
        $self->dbh,
        {
            product_id  => $product->{product},
            channel_id  => $self->payload->{dest_channel},
        }
    );

    # DCS-847: create new navigational attributes for the new channel
    create_new_channel_navigation_attributes(
        $self->dbh,
        {
            product_id      => $product->{product},
            from_channel_id => $self->payload->{source_channel},
            to_channel_id   => $self->payload->{dest_channel},
            navigation_categories => $product->{navigation},
        }
    );

    # create a channel transfer job for stock movement
    create_channel_transfer(
        $self->dbh,
        {
            product_id      => $product->{product},
            from_channel_id => $self->payload->{source_channel},
            to_channel_id   => $self->payload->{dest_channel},
            operator_id     => $self->payload->{operator_id},
        }
    );
}

1;

=head1 NAME

XT::JQ::DC::Receive::Product::ChannelTransfer - Notification of sales channel
transfer received from Fulcrum

=head1 DESCRIPTION

This message contains data on products to be flagged for transfer between two sales
channels.  The transfer status field in product_channel is set to "Transfer
Requested" for each product.
