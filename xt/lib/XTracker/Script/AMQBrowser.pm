package XTracker::Script::AMQBrowser;

use NAP::policy 'class';
use XTracker::Config::Local 'config_var';
use LWP::UserAgent;
use HTTP::Cookies;
use URI;
use XML::Simple 'XMLin';
use HTTP::Request;
use Term::ReadKey 'GetTerminalSize';
use XTracker::Utilities 'url_encode';
use XTracker::Metrics::Recorder;

=head1 PACKAGE

XTracker::Script::AMQBrowser

=head1 DESCRIPTION

Extract and Interact with AMQ Queues

=head1 ATTRIBUTES

=head2 max_name_length

Specify the maximum length of a queue name
so the table-style output doesn't become too ugly.

=cut

has max_name_length => (
    is => 'ro',
    isa => 'Int',
    default => sub {
        my ($width, @junk) = GetTerminalSize();
        # "54" is how much space all the other
        # columns take up.
        return (($width - 54) > 50) ? 50 : $width - 54;
    }
);

=head2 queue

Returns a perl structure containing all the information
about the AMQ Queues that have been pulled from the
appropriate XML document. This XML data that ends up
here is viable from AMQ directly like this:

http://<hostname>:8161/admin/xml/queues.jsp

=cut

has queues => (
    is => 'ro',
    lazy => 1,
    builder => '_build_queues'
);

=head2 amq_hostname

AMQ Broker host and port to connect to.

=cut

has amq_hostname => (
    is  => 'ro',
    isa => 'Str',
    default => sub {
        my $hostname = config_var('AMQBrowser', 'hostname');
        my $web_port = config_var('AMQBrowser', 'web_port');
        return "$hostname:$web_port";
    }
);

=head2 amq_username

Username for AMQ Broker UI's interface.

=cut

has amq_username => (
    is => 'ro',
    isa => 'Str',
    default => sub {
        return config_var('AMQBrowser', 'username');
    }
);

=head2 amq_password

Password for AMQ Broker UI's interface.

=cut

has amq_password => (
    is => 'ro',
    isa => 'Str',
    default => sub {
        return config_var('AMQBrowser', 'password');
    }
);

has _user_agent => (
    is => 'ro',
    lazy => 1,
    default => sub {
        my $ua = LWP::UserAgent->new;
        $ua->cookie_jar({});
        return $ua;
    }
);

############################################################
# This Package can be divided into two parts. The part that
# fetches the XML and the API that uses it. These function
# all work together to fetch the XML
############################################################

sub _build_queues {
    my $self = shift;
    my $xml_doc = $self->_fetch_xml_document('queues');
    return $xml_doc->{queue};
}

sub _fetch_xml_document {
    my ($self, $name) = @_;
    my $xml_url = $self->_get_xml_document_url($name);
    my $raw_xml = $self->_request_url($xml_url)->content;
    return $self->_parse_xml_document($raw_xml);
}

sub _parse_xml_document {
    my ($self, $raw_xml_contents) = @_;
    return XMLin($raw_xml_contents);
}

sub _request_url {
    my ($self, $url) = @_;

    my $request = HTTP::Request->new('GET', $url);
    $request->authorization_basic(
        $self->amq_username,
        $self->amq_password
    );
    my $response = $self->_user_agent->request($request);

    confess("Didnt get successful response. Got: ". $response->status_line)
        if (!$response->is_success());

    return $response;
}

sub _get_xml_document_url {
    my ($self, $name) = @_;
    my $amq_hostname = $self->amq_hostname;
    return "http://$amq_hostname/admin/xml/$name.jsp";
}

##########################################################
# The functions below comprise the API for working with
# this package.
##########################################################

=head2 filtered_queue_keys

Returns the queue names matching the
passed in regex.

=cut

sub filtered_queue_keys {
    my ($self, $filter) = @_;

    my $queues = $self->queues;

    return [ sort keys %$queues ] unless defined($filter);
    return [ sort grep { $_ =~ m/$filter/i } keys %$queues ];

}

=head2 print_amq_queue_stats($regex) : void

Print a table of information about the queues
that match the optional $regex that can be
passed in.

=cut

sub print_amq_queue_stats {
    my ($self, $filter) = @_;

    if (!defined($self->queues)) {
        say "No data";
        return;
    }

    my $max = $self->max_name_length;
    my $table_format = "%-${max}s | %5s | %14s | %10s | %10s";
    say sprintf($table_format,
        "QUEUE NAME",
        "SIZE",
        "CONSUMER COUNT",
        "ENQUEUED",
        "DEQUEUED",
    );

    # iterate over queues and print stats
    # for those matching "DLQ".

    my $queues = $self->queues;

    foreach my $key (@{ $self->filtered_queue_keys($filter) }) {
        say sprintf($table_format,
            $self->_cut_name($key),
            $queues->{$key}->{stats}->{size},
            $queues->{$key}->{stats}->{consumerCount},
            $queues->{$key}->{stats}->{enqueueCount},
            $queues->{$key}->{stats}->{dequeueCount},
        );
    }
}

sub _cut_name {
    my ($self, $key) = @_;
    return $key unless (length($key) > $self->max_name_length - 2);
    return substr($key, 0, $self->max_name_length - 3) . "...";
}

=head2 purge_amq_queues($regex) : void

Empty out any queue whose name matches the regex
specified

=cut

sub purge_amq_queues {
    my ($self, $filter) = @_;

    if (!defined($self->queues)) {
        say "No data";
        return;
    }

    # iterate over queues and call purge_amq_queue()
    # for those matching input.
    my $queues = $self->queues;

    foreach my $key (@{ $self->filtered_queue_keys($filter) }) {
        print "puring queue: $key ... ";

        try {
            $self->purge_amq_queue($key);
            say "[success]";
        } catch {
            say "[failed] (err=$_)";
        };
    }
}

=head2 purge_amq_queue

Delete all the messages on a named queue

=cut

sub purge_amq_queue {
    my ($self, $queue_name) = @_;
    my $purge_queue_url = $self->_get_amq_purge_queue_url($queue_name);
    $self->_request_url($purge_queue_url);
}

sub _get_amq_purge_queue_url {
    my ($self, $queue_name) = @_;
    my $secret_key = $self->_extract_secret_from_html;
    my $amq_hostname = $self->amq_hostname;

    my $url = URI->new("http://$amq_hostname/admin/purgeDestination.action");
    $url->query_form(
        JMSDestination => $queue_name,
        JMSDestinationType => 'queue',
        secret => $secret_key
    );

    return "$url";
}

# we have to retrieve CSRF token from the main page
# before we can press the purge button.

sub _extract_secret_from_html {
    my $self = shift;
    my $amq_hostname = $self->amq_hostname;
    my $html_page = $self->_request_url("http://$amq_hostname/admin/queues.jsp")->content;
    if ($html_page =~ m/.*secret=(.*)".*/) {
        return $1;
    }
    confess("could not extract secret key from main page");
}

# pull the queue information out of ActiveMQ and
# store it as an XTracker Metric.

sub generate_metrics {
    my $self = shift;

    my $metric_queues = [];
    my $queues = $self->queues;

    foreach my $key (sort keys %$queues ) {
        push(@{ $metric_queues }, {
            queue_name => $key,
            size => $queues->{$key}->{stats}->{size},
            consumerCount => $queues->{$key}->{stats}->{consumerCount},
            enqueueCount => $queues->{$key}->{stats}->{enqueueCount},
            dequeueCount => $queues->{$key}->{stats}->{dequeueCount},
        });
    }

    XTracker::Metrics::Recorder->new->store_metric(
        'amq_browser_stats',
        { queues => $metric_queues }
    );
}

