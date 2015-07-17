package NAP::CustomerCredit::Client;
use NAP::policy "tt", 'class';
use Moose::Util::TypeConstraints 'duck_type';
use MooseX::Types::URI 'Uri';
use Class::Load 'load_class';
use HTTP::Request;
use JSON;
use Data::Printer;

# portions stolen from NAP::Solr::Client, we should factor them out

has config => (
    is       => 'ro',
    isa      => 'HashRef'
);

has log => (
    is => 'ro',
    isa => duck_type([qw(debug info warn error)]),
    default => sub { Log::Log4perl->get_logger(__PACKAGE__) }
);

has config_sections => (
    is => 'ro',
    isa => 'ArrayRef',
    lazy_build => 1,
);

sub _build_config_sections {
    return [ __PACKAGE__ ];
}

sub config_value {
    my ($self, @path) = @_;

    my $config = $self->config;

    if (defined $config) {
        foreach my $config_section (@{ $self->config_sections }) {
            my $config_walker = $config->{$config_section};

            my @walk_path = @path;

            while (@walk_path) {
                my $key = shift @walk_path;

                $config_walker = $config_walker->{$key} if defined $config_walker;
            }

            return $config_walker if defined $config_walker;
        }
    }

    return undef;
}

has user_agent => (
    is         => 'ro',
    isa        => duck_type([qw(request)]),
    lazy_build => 1,
);

sub _build_user_agent {
    my ($self) = @_;

    my $user_agent_class = $self->config_value('user_agent_class') // 'LWP::UserAgent';

    load_class($user_agent_class);
    return $user_agent_class->new;
}

has base_uri => (
    is => 'ro',
    isa => Uri,
    coerce => 1,
    lazy_build => 1,
);

sub _build_base_uri {
    my ($self) = @_;

    return $self->config_value('api_uri');
}

sub _endpoint_uri {
    my ($self,@components) = @_;

    my $uri = $self->base_uri->clone;
    my @segments = $uri->path_segments;
    if ($segments[-1] eq '') { pop @segments };
    $uri->path_segments(@segments,@components);

    return $uri;
}

sub _clean_channel_name {
    my ($name) = @_;
    my $clean_name = uc( $name =~ s{[^A-Z]+}{_}gr );
    # our "web name" has OUTNET-INTL (&c), but the Customer Credit API
    # wants OUT_INTL
    $clean_name =~ s{\A OUTNET _}{OUT_}x;
    return $clean_name;
}

sub _execute_request {
    my ($self,$opts) = @_;

    my $req = HTTP::Request->new(
        $opts->{method} // 'GET',
        $self->_endpoint_uri(@{$opts->{path}//[]}),
        [
            'X-Retail-Channel' => _clean_channel_name($opts->{channel_name}),
            Accept => 'application/json',
        ]
    );
    if ($opts->{payload}) {
        $req->content(encode_json($opts->{payload}));
        $req->headers->header('Content-type','application/json');
    }

    #p $req;

    my $res = $self->user_agent->request($req);
    $res->decode;
    my $output;
    if ($res->content && $res->content_type eq 'application/json') {
        $output = decode_json($res->content);
    }

    #p $res;

    return $res->code, $output;
}

sub get_store_credit {
    my ($self,$channel_name,$customer_id) = @_;

    my ($code,$output) = $self->_execute_request({
        path => [ $customer_id ],
        channel_name => $channel_name,
    });

    if ($code == 200 && $output) {
        return ('ok',$output->{data});
    }
    if ($code == 500) {
        return ('error',$output);
    }
    return ('ok',[]); # 404 mean "no credit", it's not an error
}

sub get_store_credit_balance {
    my ($self,$channel_name,$customer_id,$currency_code) = @_;

    my ($code,$output) = $self->_execute_request({
        path => [ $customer_id, $currency_code, 'balance' ],
        channel_name => $channel_name,
    });

    if ($code == 200 && $output) {
        return ('ok',$output->{data}{credit});
    }
    if ($code == 500) {
        return ('error',$output);
    }
    return ('ok',0); # 404 mean "no credit", it's not an error
}

sub get_store_credit_deltas {
    my ($self,$channel_name,$customer_id,$currency_code) = @_;

    my ($code,$output) = $self->_execute_request({
        path => [ $customer_id, $currency_code, 'deltas' ],
        channel_name => $channel_name,
    });

    if ($code == 200 && $output) {
        return ('ok',$output->{data});
    }
    if ($code == 500) {
        return ('error',$output);
    }
    return ('ok',[]); # 404 mean "no credit", it's not an error
}

sub get_store_credit_and_log {
    my ($self,$channel_name,$customer_id) = @_;

    my ($status,$credits) = $self->get_store_credit($channel_name,$customer_id);
    if ($status ne 'ok') {
        return ($status,$credits);
    }

    for my $credit (@$credits) {
        my $deltas;
        ($status,$deltas) = $self->get_store_credit_deltas(
            $channel_name,
            $customer_id,
            $credit->{currencyCode},
        );
        if ($status ne 'ok') {
            next;
        }

        $credit->{log}=$deltas;
    }

    return ('ok',$credits);
}

sub add_store_credit {
    my ($self,$channel_name,$customer_id,$currency_code,$amount,$created_by,$notes) = @_;

    my ($code,$output) = $self->_execute_request({
        method => 'POST',
        path => [ $customer_id, $currency_code ],
        channel_name => $channel_name,
        payload => {
            createdBy => $created_by,
            credit => 0+$amount,
            notes => $notes//'',
        },
    });

    if ($code == 200 && $output) {
        return ('ok',$output->{data}{credit});
    }
    if ($code == 201) {
        return $self->get_store_credit_balance($channel_name,$customer_id,$currency_code);
    }
    return ('error',$output);
}
