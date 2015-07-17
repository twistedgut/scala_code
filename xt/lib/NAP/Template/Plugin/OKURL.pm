package NAP::Template::Plugin::OKURL;
use strict;
use warnings;

use LWP::UserAgent;

use base qw{ Template::Plugin };

sub new {
    my ($class, $context, @args) = @_;
    my $new_obj = bless {}, $class;

    $new_obj->{ua} = LWP::UserAgent->new;
    $new_obj->{ua}->timeout(2);

    return $new_obj;
}

sub uri_ok {
    my ($self, $uri) = @_;
    my $request = HTTP::Request->new(
        GET => $uri
    );
    my $response = $self->{ua}->request($request);

    if ($response->is_success) {
        return 1;
    }
    else {
        return 0;
    }
}

sub alternate_uri {
    my ($self, $alternate_uri) = @_;
    if (defined $alternate_uri) {
        $self->{_alternate_uri} = $alternate_uri;
    }
    return $self->{_alternate_uri};
}

sub uri_or_alternate {
    my ($self, $uri, $alternate_uri) = @_;
    my $request = HTTP::Request->new(
        GET => $uri
    );
    my $response = $self->{ua}->request($request);


    if ($response->is_success) {
        return $uri;
    }
    else {
        if (defined $alternate_uri) {
            return $alternate_uri;
        }
        elsif (defined $self->{_alternate_uri}) {
            return $self->{_alternate_uri}
        }
        else {
            return 'NO_ALTERNATE_URI_GIVEN';
        }
    }
}

1;
