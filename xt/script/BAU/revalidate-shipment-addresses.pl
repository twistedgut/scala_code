#!/opt/xt/xt-perl/bin/perl
use NAP::policy 'tt';
use lib '/opt/xt/deploy/xtracker/lib';
use lib '/opt/xt/deploy/xtracker/lib_dynamic';
use XTracker::Database 'xtracker_schema';
use XTracker::Database::Shipment;
use XTracker::Constants ':application';
use XTracker::Constants::FromDB qw(:shipment_status :shipment_hold_reason);
use NAP::Carrier;

my $schema = xtracker_schema();

my @shipment_ids = @ARGV;
if (@ARGV==1 and $ARGV[0] =~ /\D/) { # one arg, not a number: it's a channel name
    my $inv_ships = $schema->resultset('Public::Shipment')->invalid_shipments(
        $schema->resultset('Public::Channel')->get_channel_config()
    );
    #use Data::Printer;p $inv_ships;
    @shipment_ids = map { keys %$_ } map { values %$_ } values %{$inv_ships->{$ARGV[0]}//{}};
}

my $shipment_rs = $schema->resultset('Public::Shipment')->search({
    id => { -in => \@shipment_ids },
},{
    order_by => { -asc => 'id' },
});

while (my $shipment = $shipment_rs->next) {
    try {
        $schema->txn_do(sub{
            say "Working on shipment ".$shipment->id;

            if ($shipment->has_validated_address) {
                say " it does not seem to be an invalid shipment, ignoring";
                return;
            }
            if (not $shipment->is_on_hold_for_reason($SHIPMENT_HOLD_REASON__INCOMPLETE_ADDRESS)) {
                say " it does not seem to be have an address problem, ignoring";
                return;
            }

            $shipment->update_status(
                $SHIPMENT_STATUS__PROCESSING,
                $APPLICATION_OPERATOR_ID,
            );
            $shipment->validate_address({
                operator_id => $APPLICATION_OPERATOR_ID,
            });
            $shipment->discard_changes;
            $shipment->hold_if_invalid({
                operator_id => $APPLICATION_OPERATOR_ID,
            });
            $shipment->discard_changes;

            if ($shipment->is_on_hold) {
                say " Shipment STILL HELD!";
            }
            else {
                say " Shipment released";
            }
        });
    }
    catch {
        warn $shipment->id . " failed: $_";
    };
}

__END__

=head1 NAME

revalidate-shipment-addresses.pl

=head1 SYNOPSIS

  revalidate-shipment-addresses.pl 123456 126563 734536

  revalidate-shipment-addresses.pl NET-A-PORTER.COM

=head1 DESCRIPTION

This script takes a list of shipment ids, or a (long) channel name,
and for each shipment (given, or on the "invalid shipment" page for
that channel) thas is on hold for invalid address, will re-validate
the address and, if valid, will take the shipment off hold.

It will work on each shipment in a separate transaction, and will warn
(on STDERR) of problems.

The valid channel names are:

=over 4

=item *

NET-A-PORTER.COM

=item *

theOutnet.com

=item *

MRPORTER.COM

=item *

JIMMYCHOO.COM

=back

