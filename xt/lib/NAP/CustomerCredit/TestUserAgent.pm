package NAP::CustomerCredit::TestUserAgent;
use NAP::policy "tt", 'class';
use HTTP::Request;
use HTTP::Response;
use MooseX::Types::Path::Class;
use MooseX::Types::URI 'Uri';
use XTracker::Config::Local qw(config_var);
use XTracker::Logfile qw(xt_logger);
use JSON;

has data_dir => (
    is       => 'ro',
    isa      => 'Path::Class::Dir',
    coerce   => 1,
    default  => sub{ config_var("NAP::CustomerCredit::Client", "test_data_dir") },
);

has base_uri => (
    is => 'ro',
    isa => Uri,
    coerce => 1,
    default => sub{ config_var("NAP::CustomerCredit::Client", "api_uri") },
);

sub request {
    my ($self,$request) = @_;

    $self->_save_request($request);
    my $response = $self->_retrieve_response($request);
    return $response;
}

sub _filename_for_message {
    my ($self,$message,$kind) = @_;
    my $method = uc($message->method);
    my @path_segments = $message->uri->path_segments;
    my @base_path_segments = $self->base_uri->path_segments;
    if ($base_path_segments[-1] eq '') { pop @base_path_segments };
    splice @path_segments,0,scalar @base_path_segments;
    my $path = join '-', map { s{\W+}{-}gr } @path_segments;

    return "${kind}:${method}=${path}";
}

sub _save_request {
    my ($self,$request) = @_;

    my $file = $self->data_dir->file(
        $self->_filename_for_message($request,'request')
    );
    $file->spew(iomode=>'>:raw',$request->as_string);
    return;
}

sub _retrieve_response {
    my ($self,$request) = @_;

    my $file = $self->data_dir->file(
        $self->_filename_for_message($request,'response')
    );
    if (! -f $file) {
        return HTTP::Response->new(404,'not there');
    }
    my $response = HTTP::Response->parse(scalar $file->slurp(iomode=>'<:raw'));
    return $response;
}

sub set_response {
    my ($self,$request,$response) = @_;

    my $file = $self->data_dir->file(
        $self->_filename_for_message($request,'response')
    );
    $file->spew(iomode=>'>:raw',$response->as_string);
    return;
}

sub set_response_simple {
    my ($self,$method,$uri,$status,$payload) = @_;
    $uri=URI->new($uri) unless ref($uri);

    my $abs_uri=$self->base_uri->clone;
    my @segments = $abs_uri->path_segments;
    if ($segments[-1] eq '') { pop @segments };
    $abs_uri->path_segments(@segments,$uri->path_segments);
    my $req = HTTP::Request->new(uc($method),$abs_uri);
    my $res = HTTP::Response->new($status,'test',[
        'content-type' => 'application/json',
    ]);
    $res->content(encode_json($payload));
    $self->set_response($req,$res);
}

sub dumped_requests {
    my ($self) = @_;

    return grep {
        $_->basename =~ /^request:/
    } $self->data_dir->children
}

sub clear_requests {
    my ($self) = @_;

    my @files = $self->dumped_requests();
    $_->remove for @files;

    return;
}

sub dumped_responses {
    my ($self) = @_;

    return grep {
        $_->basename =~ /^response:/
    } $self->data_dir->children
}

sub clear_responses {
    my ($self) = @_;

    my @files = $self->dumped_responses();
    $_->remove for @files;

    return;
}

sub get_requests {
    my ($self) = @_;

    my @files = $self->dumped_requests();
    my @ret = map { HTTP::Request->parse(scalar $_->slurp(iomode=>'<:raw')) }
        @files;

    return @ret;
}
