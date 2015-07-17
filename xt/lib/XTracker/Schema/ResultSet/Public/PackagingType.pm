package XTracker::Schema::ResultSet::Public::PackagingType;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

use Carp;

sub hash(){
    my ($self)=@_;

    my %return;
    foreach my $type ( $self->all() ){
        $return{$type->sku()} = 1;
    }
    return %return;
}

=head2 find_by_sku

Finds packaging type by its SKU

=cut

sub find_by_sku {
    my $self = shift;
    my $sku = shift or croak 'Must supply a SKU';

    return $self->search({sku => $sku})->first;
}

=head2 find_by_name

Finds packaging type by its name

=cut

sub find_by_name {
    my $self = shift;
    my $name = shift or croak 'Must supply a SKU';

    return $self->search({name => $name})->first;
}

1;
