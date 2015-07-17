package XTracker::Role::Metrics;

use NAP::policy                 qw( role );
use XTracker::Config::Local     qw( config_var sys_config_var );

use NAP::Metrics::Graphite;

with 'XTracker::Role::WithXTLogger',
     'XTracker::Role::WithSchema';

=head1 NAME

XTracker::Role::Metrics

=head1 SYNOPSIS

    use NAP::policy 'class';
    with 'XTracker::Role::Metrics';

    ...

    $self->send_metric( {
        'name.for.metric'   => $value_for_metric;
    } );

=head1 DESCRIPTION

A role for sending Metrics to Graphite

=head1 METHODS

=head2 send_metric

Sends the metric to Graphite.

Pass in a hashref containing one or more metrics where the key to the hash
is the name of the metric and the value is an integer value for the metric.

Note that the metric will be prepended with the prefix specified in the
graphite_metric_prefix specified in the XT configuration.

=cut

has graphite_object => (
    is          => 'ro',
    isa         => 'NAP::Metrics::Graphite',
    lazy        => 1,
    builder     => '_build_graphite_object',
);

sub _build_graphite_object {
    my $self = shift;

    my $graphite = NAP::Metrics::Graphite->new(
        logger              => $self->xtlogger,
        host                => config_var('Metrics', 'graphite_hostname') // 'riemann01.wtf.nap',
        metric_name_prefix  => config_var('Metrics', 'graphite_metric_prefix') //
                'metrics.notconfiguredproperly.'.lc(config_var('DistributionCentre', 'name')).'.xtracker',
    );

    return $graphite;
}

sub send_metric {
    my ( $self, $metric ) = @_;

    if ( ! $metric ) {
        my ($package, $filename, $line) = caller;
        $self->xtlogger->warn( "send_metric called by line $line in $package without any input" );
        return;
    }

    if ( sys_config_var($self->schema, 'Send_Metrics_to_Graphite', 'is_active') ) {
        # Send the metrics if the we have enabled the configuration in the system config
        return $self->graphite_object->send_metric( $metric );
    }
    else {
        # Log the data so we can replay it later if we want to
        my $data = {
            prefix => $self->graphite_object->metric_name_prefix,
            metric => $metric
        };
        my $json = JSON->new->encode( $data );
        $self->xtlogger('Metrics')->info($json);
        return;
    }
}


