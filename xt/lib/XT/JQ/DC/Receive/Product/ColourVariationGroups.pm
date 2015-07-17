package XT::JQ::DC::Receive::Product::ColourVariationGroups;

use Moose;

use List::MoreUtils;
use Try::Tiny;
use MooseX::Types::Moose        qw( Str Int ArrayRef HashRef);

use XTracker::Comms::DataTransfer       qw( :transfer_handles );
use XTracker::Comms::FCP qw(
    ensure_fcp_related_products_fully_connected ensure_fcp_related_products_group_isolated
);

extends 'XT::JQ::Worker';

has channels => (
    is => 'rw',
    isa => HashRef,
    lazy_build => 1,
);

has payload => (
    is  => 'ro',
    isa => ArrayRef[ArrayRef[Int]],
    required => 1,
);

sub _build_channels {
    my $self = shift;
    $self->schema->resultset('Public::Channel')->get_channels({ fulfilment_only => 0 });
}

# We want to help people out who try and update a product, that's part of a
# product upload, before that product has made it to the DC
sub max_retries { return 10 }
sub retry_delay { return 60 * 10 }

sub check_job_payload {
    my ($self) = @_;

    my $payload = $self->payload;

    if ( ! @$payload) {
        return 'There must be at least one colour variation group specified';
    }

    my @errors;

    if ( ! List::MoreUtils::all { scalar @$_ } @$payload) {
        push @errors, 'All Colour variation groups must have at least one product ID';
    }

    my %seen_pids;

    PID_UNIQUE: foreach my $group (@$payload) {
        foreach my $product_id (@$group) {
            if (exists $seen_pids{$product_id}) {
                push @errors, 'Each product ID can only occur once across all colour variation groups';
                last PID_UNIQUE;
            }
            $seen_pids{$product_id} = undef;
        }
    }

    return @errors;
}

sub do_the_task {
    my ($self, $job)    = @_;

    my $payload  = $self->payload;
    my $channels = $self->channels;

    my @product_ids = map { (@$_); } @$payload;

    my $pc_data_rs = $self->schema->resultset('Public::ProductChannel')->search(
        {
            product_id => { -in => \@product_ids },
            -bool      => 'live'
        },
        {
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
            select => [ qw{ product_id channel_id } ]
        }
    );

    my %pids_live_on_channels;

    while (my $pc_datum = $pc_data_rs->next) {
        $pids_live_on_channels{ $pc_datum->{channel_id} }{ $pc_datum->{product_id} } = undef;
    }

    my @affected_channel_ids = sort { $a <=> $b } keys %pids_live_on_channels;

    my %web_dbhs;
    my $fail_action = 'die';

    try {
        # Get handles for front end website databases
        foreach my $cid (@affected_channel_ids) {
            try {
                $web_dbhs{$cid} = get_transfer_sink_handle({
                    environment => 'live',
                    channel => $channels->{$cid}{config_section},
                });
            } catch {
                if ( ! (defined $web_dbhs{$cid} && defined $web_dbhs{$cid}->{dbh_sink})) {
                    $fail_action = 'retry';
                    die "Can't Talk to Web Site for Channel "
                        . $cid . " (" . $channels->{$cid}{config_section} . ") - " . $_;
                }
            };
        }

        # NOTE: We do NOT need to update the colour variation in DC
        # - it's mastered in Fulcrum now and
        # MIS don't need recommended_produccts stored here

        # Need to update website for all channels in this DC
        # No need to wrap in an xtracker transaction as we're not updating XT DB
        foreach my $group (@$payload) {
            # Product IDs are in @$group
            foreach my $cid (@affected_channel_ids) {
                # Constrain the set of product ids to be linked
                # to those which are live on this channel
                my @product_ids = grep { exists $pids_live_on_channels{$cid}{$_} } @$group;

                # Skip if no relevant products on this channel
                next if scalar @product_ids == 0;

                ensure_fcp_related_products_fully_connected(
                    dbh         => $web_dbhs{$cid}->{dbh_sink},
                    product_ids => \@product_ids,
                    type_id     => 'COLOUR'
                );

                ensure_fcp_related_products_group_isolated(
                    dbh         => $web_dbhs{$cid}->{dbh_sink},
                    # Use the unconstrained set of product IDs when removing
                    # unwanted links so that we could self-heal any erroneous
                    # links created
                    product_ids => $group,
                    type_id     => 'COLOUR'
                );
            }
        }

        # Commit all the changes
        $web_dbhs{$_}->{dbh_sink}->commit() foreach keys %web_dbhs;
        $web_dbhs{$_}->{dbh_sink}->disconnect() foreach keys %web_dbhs;
    } catch {
        my $err = $_;

        # Rollback all changes
        $web_dbhs{$_}->{dbh_sink}->rollback() foreach keys %web_dbhs;
        $web_dbhs{$_}->{dbh_sink}->disconnect() foreach keys %web_dbhs;

        $fail_action = "retry" if $err =~ /Deadlock/;
        if ( $fail_action eq "retry" ) {
            $job->failed( $err );
        } else {
            die $err;
        }
    };

    return;
}

=head1 NAME

XT::JQ::DC::Receive::Product::ColourVariationGroups - Add/Delete colour
variation links, whole groups at a time

=head1 DESCRIPTION

This message is sent via the Fulcrum Send::Product::ColourVariationGroups
message when products linked/unlinked as colour variants

Expected Payload should look like:

    ArrayRef[
        ArrayRef[
            Int
        ]
    ]

The outer array represents a list of colour variation groups.

Each colour variation group is represented by an array of product IDs.

=cut

1;
