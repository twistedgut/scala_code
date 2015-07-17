package XT::Order::Role::Parser::IntegrationServiceJSON::CustomerData;
use NAP::policy "tt", 'role';
    with 'XT::Order::Role::Parser::Common::CustomerData';

requires 'is_parsable';
requires 'parse';

requires '_extract_fields';

sub _get_customer_data {
    my($self,$node) = @_;
    my %keys = ();

    my $data = {
        email               => $node->{billing_detail}{contact_detail}{email},
        home_telephone      => ($node->{billing_detail}{contact_detail}{telephone}{number} // ''),
        work_telephone      => '',
        mobile_telephone    => '',

        title               => $node->{billing_detail}{name}{title},
        first_name          => $node->{billing_detail}{name}{first_name},
        last_name           => $node->{billing_detail}{name}{last_name},

        address             => $self->_extract_address($node->{billing_detail}->{address}),
        name                => $self->_extract_name($node->{billing_detail}->{name}),
    };

    return $data;
}

sub _extract_name {
    my($self,$node) = @_;

    my $mapping = {
        title       => "title",
        first_name  => "first_name",
        last_name   => "last_name",
    };
    return $self->_extract_fields($node,$mapping);
}

sub _extract_address {
    my($self,$node) = @_;

    my $mapping = {
        address_line_1      => "address_line_1",
        address_line_2      => "address_line_2",
        towncity            => "town_city",
        county              => "county",
        postcode            => "post_code",
        country             => "country",
    };

    my $data = $self->_extract_fields($node,$mapping);
    #warn "_extract_address";
    # sort out the address do don't need to do this again and again
#    if ($self->dc eq 'DC2') {
#        $data->{county} = delete $data->{state};
#    } else {
#        # we shouldn't have this if its not US
#        delete $data->{state};
#    }

    return $data;
}
