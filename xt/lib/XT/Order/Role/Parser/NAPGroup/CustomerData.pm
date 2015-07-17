package XT::Order::Role::Parser::NAPGroup::CustomerData;

use Moose::Role;
    with 'XT::Order::Role::Parser::Common::CustomerData';
    with 'XT::Order::Role::Parser::NAPGroup::DataFudging';

use feature ':5.14';
use XT::Data::Types;
use DateTime::Format::Strptime;

requires 'is_parsable';
requires 'parse';

requires '_extract_fields';
requires '_fudge_address';

sub _get_customer_data {
    my($self,$node) = @_;
    my %keys = ();

    my $billing_node = $node->{billing_details};
    $self->_fudge_address( $billing_node->{address} ); # ORT-61

    my $data = {
        email               => $billing_node->{contact_details}{email},

        # we aim to set these to something sensible shortly (see below)
        home_telephone      => '',
        work_telephone      => '',
        mobile_telephone    => '',

        title               => $billing_node->{name}{title},
        first_name          => $billing_node->{name}{first_name},
        last_name           => $billing_node->{name}{last_name},

        address             => $self->_extract_address($billing_node->{address}),
        name                => $self->_extract_name($billing_node->{name}),
    };

    # This isn't wonderful, but currently MrP are sending through a LIST of
    # phone numbers (in a type,content hash)
    # To make it even more fun, they use office instead of work
    #
    # TODO: find out how much of this *needs* to stay like this
    #       it's nice that we're flexible enough to deal with this, but still,
    #       there just seems to be way more effort and pain here than really
    #       required
    if ('ARRAY' eq ref($billing_node->{contact_details}{telephone})) {
        foreach my $telephone (@{$billing_node->{contact_details}{telephone}}) {
            SMARTMATCH: {
                use experimental 'smartmatch';
                given (my $type = lc($telephone->{type})) {
                    when (m{\A(?:home|mobile)\z}) {
                        $data->{"${type}_telephone"} = $telephone->{number}
                            if defined $telephone->{number};
                    }

                    when ('office') {
                        $data->{'work_telephone'} = $telephone->{number}
                            if defined $telephone->{number};
                    }

                    default {
                        warn "unexpected telephone type: $telephone->{type}";
                    }
                }
            }
        }
    }
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
        address_line_3      => "address_line_3",
        towncity            => "towncity",
        county              => "county",
        postcode            => "postcode",
        country             => "country",
    };

    return $self->_extract_fields($node,$mapping);
}

1;
