package XTracker::Script::WebsiteAPI::FakeResponse;
use Moose;
extends 'XTracker::Script';

use XT::Net::WebsiteAPI::TestUserAgent;

sub invoke {
    my ($self, %args) = @_;
    my $verbose = !!$args{verbose};
    my $keep = !!$args{keep};

    if($verbose) {
        print "Fake Response ($args{code}) ($args{message}):\n-----\n$args{body}\n-----\n";
        print "\nThis response will be kept until you fake another one\n" if($keep);
    }

    my $response = HTTP::Response->new(
        $args{code},
        $args{message},
        HTTP::Headers->new(
            "Content-Type" => "application/json",
            ( $keep ? ("X-Fake-Keep" => 1) : () ),
        ),
        $args{body},
    );
    XT::Net::WebsiteAPI::TestUserAgent->setup_fake_response($response);

    return 0;
}

1;
