package XT::Net::XTrackerAPI::Server;
use NAP::policy "tt", "class";
use Module::Runtime 'require_module';
use Plack::App::FakeApache1::Constants qw(:common HTTP_OK :4xx);
use JSON;

use XTracker::Handler;
use XTracker::Logfile qw/ xt_logger /;

=head1 NAME

XT::Net::XTrackerAPI::Server - Base class for serving specific parts of the XTracker API

=head1 DESCRIPTION

Serving the XTracker API.

=cut

sub serve_request {
    my ($self, $args) = @_;
    my $apache_request = $args->{apache_request};

    my $response_data = eval {
        my $request_class = $args->{request_class};
        require_module $request_class;

        my $handler = XTracker::Handler->new($apache_request);
        my $request = $request_class->new({
            operator      => $handler->operator,
            authorization => XT::Net::XTrackerAPI::Request::Authorization->new(
                $handler->{data},
            ),
        });

        my $method = $apache_request->method;
        my $request_method = "${method}_$args->{request_method_base}";
        $request->can($request_method)
            or die("Unknown method ($request_class->$request_method)\n");
        my $response_objects = eval {
            $request->$request_method( $handler->{param_of} );
        };
        if(my $e = $@) {
            xt_logger->error($e);
            die $self->clean_exception($e);
        }

        +{
            status => { code => HTTP_OK },
            data   => $response_objects,
        };
    };
    if(my $e = $@) {
        chomp($e);
        $response_data = {
            status => { code => HTTP_BAD_REQUEST, error => $e },
        };
    }

    $apache_request->print( $self->json->encode( $response_data ) );

    return OK;
}

sub clean_exception {
    my ($self, $e) = @_;

    $e =~ s| in call to \w+::.+||sm;
    $e =~ s|in the call to \S+ ||sm;
    $e =~ s|( callback)?\n? at /\S+ line \d+.*||sm;
    $e =~ s| at reader \w+::.+||sm;

    chomp($e);
    return "$e\n";
}

my $json_parser_singleton;
sub json {
    return $json_parser_singleton ||= JSON->new
        ->utf8
        ->convert_blessed(1)
        ->canonical(1)
        ->pretty;
}

1;
