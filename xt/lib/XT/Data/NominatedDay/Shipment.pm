package XT::Data::NominatedDay::Shipment;


use Readonly;
use NAP::policy "tt", 'class';
use XTracker::EmailFunctions qw/send_internal_email/;
use XTracker::Config::Local qw/config_var/;
use XT::Data::DateStamp;

with 'XTracker::Role::WithSchema';

Readonly my $NOMINATEDDAY_CAP_REACHED_TEMPLATE
    => 'email/internal/nominated_day_cap_reached.tt';


=head1 NAME

XT::Data::NominatedDay::Shipment

=head1 SYNOPSIS

=head1 METHODS

=cut

has max_daily_shipment_count => (
    is => "ro",
    default => sub {
        return config_var('NominatedDay','max_daily_shipment_count');
    }
);

has alert_every_n => (
    is => "ro",
    default => sub {
        return config_var('NominatedDay','nominated_day_cap_alert_every_n');
    }
);

=head2 check_daily_cap( DateTime )

For a given date check the currently nominated day shipment count and alert
by email if necessary

=cut

sub check_daily_cap {
    my($self,$date) = @_;
    my $cap = $self->max_daily_shipment_count;
    my $count = $self->schema->resultset('Public::Shipment')
        ->nominated_to_dispatch_on_day(
            XT::Data::DateStamp->from_datetime($date)
        )->count;

    # not reached the cap yet
    return if ($count < $cap);


    my $alert_every_n = $self->alert_every_n;
    my $offset = $count - $cap;

    # reached cap or in multiples of 'alert_every_n' eg 20
    if ($offset % $self->alert_every_n == 0) {

        return send_internal_email(
            to => config_var('NominatedDay','alert_emails_to'),
            subject => "Nominated Day Daily Cap Reached - ". $date->ymd,
            from_file => {
                path => $NOMINATEDDAY_CAP_REACHED_TEMPLATE,
            },
            stash => {
                cap => $cap,
                count => $count,
                date => $date,
                template_type => 'email',
            },
        );

    }

    return;
}


