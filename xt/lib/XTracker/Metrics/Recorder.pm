package XTracker::Metrics::Recorder;

=head1 NAME

XTracker::Metrics::Recorder

=head1 DESCRIPTION

Routines for storing and retrieving metrics.

=cut

use NAP::policy qw/class tt/;
use JSON::XS;
use DateTime;
use IO::File;
use File::Slurp;
use XTracker::Config::Local 'config_var';
use File::Spec::Functions 'catfile';
use Sys::Hostname;
use XTracker::Logfile 'xt_logger';

my $FILE_EXT = '.metric.json';

=head2 store_metric (metric_name, metric_data)

Used by scripts that generate metrics to be able to uniformly
write the metric to disk. The metric data is serialised and stored
in a configured location.

Keep the metric name simple a-z, A-Z, 0-9 and underscore so it can
be used as a filename without any adaptations being required.

=cut

sub store_metric {
    my ($self, $metric_name, $metric_data) = @_;

    die("No metric name specified") unless (defined($metric_name) && ($metric_name ne ''));
    die("No metric data specified for metric (metric_name=$metric_name)") unless defined($metric_data);
    die("Metric name contains bad characters (metric_name=$metric_name)") unless $metric_name =~ m/^\w+$/;

    my $hostname = hostname();
    # data to dump.
    my $full_metric_dump = {
        metric_name   => $metric_name,
        metric_data   => $metric_data,
        timestamp     => $self->dt_to_json(DateTime->now()),
        hostname      => $hostname,
    };

    # generate filename to store data.
    my $filename = $self->_metric_name_and_hostname_to_filename($metric_name, $hostname);

    # perform dump
    $self->_write_json_file($filename, $full_metric_dump);

}

# generates one filename per metric per host.

sub _metric_name_and_hostname_to_filename {
    my ($self, $metric_name, $hostname) = @_;

    my $dir = config_var('SystemPaths', 'metric_dir');
    my $basename = $metric_name . '-' . $hostname . $FILE_EXT;

    my $filename = catfile($dir, $basename);
    return $filename;

}

=head2 fetch_metrics

Find all the latest metrics that have been generated on this machine
and return in one big hash.

=cut

sub fetch_metrics {
    my $self = shift;

    my $dir = config_var('SystemPaths', 'metric_dir');
    my @metric_filenames = glob($dir . "/*" . $FILE_EXT);

    my $all_metric_data = {};

    foreach my $metric_file (sort @metric_filenames) {
        # ignore individual failures...
        try {
            my $full_metric_data = $self->_read_json_file($metric_file);
            my $metric_name = $full_metric_data->{metric_name};
            my $hostname = $full_metric_data->{hostname};

            $all_metric_data->{$metric_name}->{$hostname} = $full_metric_data;
        } catch {

            # a metric for failures!
            my $mn = 'metric_load_failures';
            my $err_msg = "Can't read metric file: $metric_file";
            xt_logger->warn($err_msg);

            if (!exists($all_metric_data->{$mn})) {
                $all_metric_data->{$mn} = {
                    metric_name => $mn,
                    metric_data => [],
                    timestamp   => $self->dt_to_json(DateTime->now()),
                    hostname    => hostname()
                };
            }

            push(@{$all_metric_data->{$mn}->{metric_data}}, $err_msg);
        };
    }

    return $all_metric_data;
}


# saves a perl hash to a file (in json format)
#
# we write to a temp file based on our pid so as not to corrupt data
# if two processes are trying to write the same metric at the same time.
#
# then we use rename to move it into place, which is effectively an atomic
# operation

sub _write_json_file {
    my ($self, $filename, $perl_hash) = @_;

    my $pid = $$;
    my $tmp_filename = "$filename.$pid.tmp";
    my $fh;

    try {
        $fh = IO::File->new($tmp_filename, '>');
    } catch {
        die("Can't open json metric file $tmp_filename for writing: $_");
    };

    try {
        my $contents = $self->_get_encoder->encode($perl_hash);
        print $fh $contents;
    } catch {
        die("Can't encode perl hash to json encoded string: $_ (filename: $filename)");
    };

    $fh->close();

    try {
        rename($tmp_filename, $filename);
    } catch {
        die("Can't update metrics file ($filename from $tmp_filename: $_)");
    };

}

# returns a perl hash for a given filename

sub _read_json_file {
    my ($self, $filename) = @_;

    my $contents;

    try {
        $contents = read_file($filename);
    } catch {
        die("Can't read json metric file $filename: $_");
    };

    my $perl_hash;

    try {
        $perl_hash = $self->_get_encoder->decode($contents);
    } catch {
        die("Can't parse contents of json metric file $filename: $_");
    };

    return $perl_hash;
}


sub _get_encoder {
    my $self = shift;

    my $enc = JSON::XS->new;
    $enc->allow_blessed(0);
    $enc->pretty(1);
    $enc->utf8(1);

    return $enc->utf8;
}

=head2 dt_to_json_in_struct

Iterate over a hash structure and
stringify dates automatically.

=cut

sub dt_to_json_in_struct {
    my ($self, $object) = @_;

    if (ref($object) eq 'DateTime') {
        return $self->dt_to_json($object);
    } elsif (ref($object) eq 'HASH') {
        my $new_hash = {};

        foreach my $k (keys %$object) {
            my $val = $object->{$k};
            $new_hash->{ $self->dt_to_json_in_struct($k) } =
                $self->dt_to_json_in_struct($val);
        }

        return $new_hash;
    } else {
        return $object;
    }
}

=head2 dt_to_json

Helper function for stringifying DateTime objects consistently

=cut

sub dt_to_json {
    my ($self, $datetime) = @_;
    return $datetime->strftime("%F %T %z");
}

