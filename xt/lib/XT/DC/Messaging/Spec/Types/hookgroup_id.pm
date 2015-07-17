package XT::DC::Messaging::Spec::Types::hookgroup_id;

use NAP::policy 'tt';

use parent 'Data::Rx::CommonType::EasyNew';

use NAP::DC::Barcode::Container;
use NAP::DC::Exception::Barcode;

sub type_uri {
  sprintf 'http://net-a-porter.com/%s', $_[0]->subname
}

sub subname { 'hookgroup_id' };

sub assert_valid {
    my ( $self, $value ) = @_;

    return try {

        # make sure passed value is "hook group" barcode: first check if
        # it is container's barcode and if so - if it is "hook group"
        $value = NAP::DC::Barcode::Container->new_from_id($value);

        NAP::DC::Exception::Barcode->throw({
            error => 'Scanned barcode is ' . $value->name
        }) unless $value->is_type('hook_group');

        return 1;
    } catch {
        if ( ref($_) eq 'NAP::DC::Exception::Barcode' ) {
            return $self->fail({
                error   => [$self->subname],
                message => 'invalid hookgroup id, reason: ' . $_,
                value   => $value,
            });
        } else {
            # propagate any unknown error further
            die $_;
        }
    };
}

1;
