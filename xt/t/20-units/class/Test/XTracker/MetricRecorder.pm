package Test::XTracker::MetricRecorder;

use NAP::policy 'test';
use parent "NAP::Test::Class";

use XTracker::Metrics::Recorder;
use Test::MockModule;
use XTracker::Config::Local 'config_var';

use Sys::Hostname;

=head1 NAME

Test::XTracker::MetricRecorder - Unit tests for XTracker::Metrics::Recorder

=head1 DESCRIPTION

Unit tests for XTracker::Metrics::Recorder

=cut

sub setup :Tests(setup) {

    # clear metrics between runs
    my $dir = config_var('SystemPaths', 'metric_dir');

    # this is not, and will never be a catch all
    die("failed sanity test rm -rf / (dir=$dir)")
        unless $dir =~ /.*\/var\/data\/xt_static\/metric.*/;

    say("empting directory: $dir");
    unlink glob "$dir/*";
}

sub store_metric_simple :Tests {

    # not actually the expected format.
    my $str_date = '24/01/2014 11:56:35';

    my $mocker = Test::MockModule->new('XTracker::Metrics::Recorder');
    $mocker->mock('dt_to_json', sub {
        my ($self, $datetime) = @_;

        return $str_date;
    });

    my $mr = XTracker::Metrics::Recorder->new;

    my $metric_name = 'store_metric_simple';
    my $metric_data = { key => 'value' };

    lives_ok(sub {
        $mr->store_metric(
            $metric_name,
            $metric_data
        )},
        'store_metric doesnt explode'
    );

    # see if file was written
    my $filename = $mr->_metric_name_and_hostname_to_filename($metric_name, hostname());
    say "json filename: $filename";

    ok($filename, '_metric_name_to_filename returns a filename');
    ok(-f $filename, 'file is written to disk');
    say "json filename: $filename";

    lives_ok(sub { $mr->_read_json_file($filename) }, 'can read json file back');

    my $retval = $mr->_read_json_file($filename);

    is($retval->{metric_name}, $metric_name, 'metric name is stored correctly');
    is_deeply($retval->{metric_data}, $metric_data, 'metric data accurately represented');
    ok(exists($retval->{hostname}), 'hostname provided');
    is($retval->{timestamp}, $str_date, 'timestamp provided');

}

=head2 metric_store_validation

Ensure no regressions in expected data

=cut

sub metric_store_validation :Tests {

    my $mr = XTracker::Metrics::Recorder->new;

    # name must be present
    throws_ok {
        $mr->store_metric(undef, { key => 'value' })
    } qr/No metric name specified/, 'A metric name must be specified (undef test)';

    throws_ok {
        $mr->store_metric('', { key => 'value' })
    } qr/No metric name specified/, 'A metric name must be specified (empty string test)';

    # metric data must be provided...
    throws_ok {
        $mr->store_metric('my_metric_1', undef)
    } qr/No metric data specified/, 'Metric data must be specified';

    # ... but we would accept an empty hash
    lives_ok {
        $mr->store_metric('my_metric_2', {})
    } 'Metric data must be specified';

    # invalid names
    my @invalid_names = (
        'hello i have spaces in',
        'hello"ihave@~#¬``symbols?',
        "what?\nnewline?",
        ">>redirect_chars_in_filename"
    );

    foreach my $n (@invalid_names) {
        throws_ok {
            $mr->store_metric($n, { key => 'value' })
        } qr/Metric name contains bad characters.*/, "metric name invalid (name=$n)";
    }

}

=head2 merge_metrics

Ensure that multiple metrics are returned.

=cut

sub fetch_metrics :Tests {

    #two example metrics
    my $proc_metrics = {
        'Starman Server' => {
            'Starman Worker #1' => 'active',
            'Starman Worker #2' => 'active',
            'Starman Worker #3' => 'zombie'
        }
    };

    my $memory_metrics = {
        'firefox' => '5GB',
        'virtual box' => '4GB',
        'thunderbird' => '1GB',
        'emacs' => '8MB' # and counting
    };

    my $hostname = hostname();

    # ensure 'mr' goes out of scope
    {
        my $mr = XTracker::Metrics::Recorder->new;

        $mr->store_metric('process_metric', $proc_metrics);
        $mr->store_metric('memory_metric', $memory_metrics);
    }

    my $mr2 = XTracker::Metrics::Recorder->new;
    my $metrics = $mr2->fetch_metrics();

    # check multiple metrics are present
    ok(exists($metrics->{process_metric}), 'process_metric present from fetch_metrics');
    ok(exists($metrics->{memory_metric}), 'memory_metric present from fetch_metrics');

    # check fields on a metric
    my $pm = $metrics->{process_metric}->{$hostname};

    ok($pm->{metric_name} // '' eq 'process_metric', 'metric name in fetch_metrics');
    ok(exists($pm->{timestamp}), 'metric timestamp in fetch_metrics');
    ok(exists($pm->{hostname}), 'metric hostname in fetch_metrics');

    # ensure data out matched data going in
    cmp_deeply($pm->{metric_data}, $proc_metrics, 'process_metric data ok');
    cmp_deeply($metrics->{memory_metric}->{$hostname}->{metric_data}, $memory_metrics, 'memory_metric data ok');

}
