package XT::DC::Messaging::Producer::Packaging;
use NAP::policy "tt", 'class';
with 'XT::DC::Messaging::Role::Producer';

sub message_spec {
    return {
        type => '//rec',
        required => {
            public_title               => '//str',
            title                      => '//str',
            public_name                => '//str',
            name                       => '//str',
            type                       => '//str',
            product_id                 => '//int',
            size_id                    => '//int',
            sku                        => '//str',
            business_id                => '//int',
            business_name              => '//str',
            channel_id                 => '//int',
            channel_name               => '//str',
            description                => '//str',
        },
    };
}

has '+type' => ( default =>'PackagingMessage' );

sub transform {
    my ( $self, $header, $data ) = @_;

    my $pa = $data->{packaging_attribute}
        // croak "Missing packaging_attribute argument";

    croak "Expects a Public::PackagingAttribute object"
        unless $pa->isa('XTracker::Schema::Result::Public::PackagingAttribute');

    my $body = {};

    # If we're passed env variables, use those
    if ( $data->{envs} ) {
        $header->{live}    = $data->{envs}->{live}//0;
        $header->{staging} = $data->{envs}->{staging}//0;
    }
    # Or default to staging and live
    else {
        $header->{live} = $header->{staging} = 1;
    }

    $header->{business_id}   = $body->{business_id} = $pa->business->id;
    $header->{business_name} = $body->{business_name} = $pa->business->name;
    $header->{channel_id}    = $body->{channel_id} = $pa->channel->id;
    $header->{channel_name}  = $body->{channel_name} = $pa->channel->web_name;

    $body->{name}            = $pa->name;
    $body->{public_name}     = $pa->public_name;
    $body->{title}           = $pa->title;
    $body->{public_title}    = $pa->public_title;
    $body->{type}            = $pa->type;
    $body->{product_id}      = $pa->product_id;
    $body->{size_id}         = $pa->size_id;
    $body->{sku}             = $pa->sku;
    $body->{description}     = $pa->description;

    return ( $header, $body );
}
