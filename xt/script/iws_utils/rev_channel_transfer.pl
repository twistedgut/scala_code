#!/usr/bin/env perl
use NAP::policy "tt";
use Getopt::Long;
use Pod::Usage;
use FindBin::libs;
use FindBin::libs qw( base=lib_dynamic );
use XTracker::Role::WithAMQMessageFactory;

my ($transfer_id, $pick_station);

{
    my $p=Getopt::Long::Parser->new(
        config => [qw(
            no_auto_abbrev
            no_getopt_compat
            no_gnu_compat
            no_permute
            no_bundling
            no_ignore_case
            no_auto_version
            no_auto_help
                 )],
    );
    my $help;
    $p->getoptions(
        'transfer_id=i' => \$transfer_id,
        'help|h' => \$help,
    ) or pod2usage(2);

    pod2usage(1) if $help;

    pod2usage(2) unless $transfer_id;
}

my $payload = {
    transfer_id => $transfer_id,
    rev_flag => 1
};

my $factory = XTracker::Role::WithAMQMessageFactory->build_msg_factory;

$factory->transform_and_send('XT::DC::Messaging::Producer::WMS::StockChange', $payload);
#$msg_factory->transform_and_send('XT::DC::Messaging::Producer::WMS::StockChange',{transfer_id => $args->{transfer_id} } );

__END__

=head1 NAME

rev_channel_transfer - send the C<shipment_cancel> message

=head1 SYNOPSIS

  rev_channel_transfer --transfer_id 12345

=cut

