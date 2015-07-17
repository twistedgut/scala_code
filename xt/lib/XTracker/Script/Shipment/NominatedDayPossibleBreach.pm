package XTracker::Script::Shipment::NominatedDayPossibleBreach;

use Moose;
use Readonly;


extends 'XTracker::Script';
with map { "XTracker::Script::Feature::$_" } qw(
    SingleInstance
    Schema
);

use XTracker::Config::Local qw/
    config_var
    customercare_email
/;
use XTracker::Constants qw<$APPLICATION_OPERATOR_ID>;
use XTracker::Constants::FromDB qw/
    :shipment_hold_reason
/;
use XTracker::Database::Shipment;
use XTracker::EmailFunctions qw/send_internal_email/;
use XTracker::Logfile qw(xt_logger);


Readonly my $NOMINATEDDAY_POSSIBLE_BREACH_TEMPLATE
    => 'email/internal/nominated_day_possible_breach.tt';

=head1 NAME

XTracker::Script::Shipment::NominatedDayPossibleBreach

=head1 SYNOPSIS

  XTracker::Script::Shipment::NominatedDayPossibleBreach->invoke();

=head1 DESCRIPTION

A script to report via email the shipments that near to breaching their SLAs.
Also worth noting that it deliberately DOES NOT report premier orders. This is
intended behaviour. Search for FLEX-794 in this module

=head1 METHODS

=head2 @|ARRAYREF invoke (verbose => 1)

verbose -provide more information about what it is doing

dryrun -do nothing but give indication of what may happen

period_mins -

=cut

sub invoke {
    my ($self, %args) = @_;
    my $verbose = !!$args{verbose};
    my $dryrun = !!$args{dryrun};


    # which shipments are not going to make their delivery deadline
    my $min_selection_dispatch_period_mins = config_var(
        "NominatedDay",
        "min_selection_dispatch_period__minutes",
    );

    my $ready_for_dispatch = $self->schema->db_now->add(
        minutes => $min_selection_dispatch_period_mins,
    );

    if ($verbose) {
        xt_logger->info("  invoke: ready_for_dispatch: ($ready_for_dispatch)");
    }

    # these look like they're not going to make the carrier's last pickup
    my $set = $self->schema->resultset('Public::Shipment')
        ->nominated_day_possible_sla_breach( $ready_for_dispatch );

    if ($verbose) {
        xt_logger->info("  possible nominated day breach shipment count: "
            .$set->count) ;
    }

    # update all these items to be on hold and add add Hold Reason
    my %bulk_email;
    my @shipments;

    $self->schema->txn_do(sub {
        foreach my $shipment ($set->all) {
            # set status to Hold
            my $rec = $shipment->set_status_hold(
                $APPLICATION_OPERATOR_ID,
                $SHIPMENT_HOLD_REASON__NOMINATED_DAY_POSSIBLE_SLA_BREACH,
                'Put on hold by automatic system script',
            );

            # gather the shipments per business to make sending easier
            my $config_section = $shipment->order->channel
                ->business->config_section;

            # if we've already seen the shipment, don't add it
            if (!scalar grep { $_->id == $shipment->id }
                    @{$bulk_email{$config_section}}) {

                # FLEX-794: we want to deliberately exclude all premier orders
                # from being mentioned in the email as they will be handled by
                # the premier team separately
                next if ($shipment->is_premier);


                push @{$bulk_email{$config_section}}, $shipment;
                push @shipments, $shipment->id;
            }

        }
        print "  Shipments captured: ". join(',',@shipments) ."\n\n"
            if ($verbose);
    });

    # send email per business
    foreach my $key (keys %bulk_email) {
        my $items = $bulk_email{$key};

        if (scalar @{$items} > 0) {
            $self->_send_summary_email($key,$items);
        }
    }

    return @shipments if (wantarray);
    return \@shipments;
}

sub _send_summary_email {
    my($self,$config_section,$shipments) = @_;

    return send_internal_email(
        to => customercare_email($config_section),
        subject => "$config_section - Nominated Day Shipments - Possible SLA Breach",
        from_file => {
            path => $NOMINATEDDAY_POSSIBLE_BREACH_TEMPLATE,
        },
        stash => {
            shipments => $shipments,
            template_type => 'email',
        },
    );
}

1;
