package XTracker::Schema::ResultSet::Public::PromotionType;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub search_by_ilike_name{
    my ($self,$name)=@_;

#    $self->result_source->storage->debug(1);
    return $self->search({ name => { ilike => $name } });
}

1;
