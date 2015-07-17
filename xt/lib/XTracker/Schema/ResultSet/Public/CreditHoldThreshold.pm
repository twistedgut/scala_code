package XTracker::Schema::ResultSet::Public::CreditHoldThreshold;
# vim: ts=8 sts=4 et sw=4 sr sta
use strict;
use warnings;

use base 'DBIx::Class::ResultSet';

sub select_tokens {
    my($self,@tokens) = @_;
    return $self->search({
        name => { in => \@tokens },
    });
}

sub select_to_hash {
    my($self,@tokens) = @_;
    my $set = $self->select_tokens(@tokens);
    my $hash;

    while (my $item = $set->next) {
        $hash->{$item->name} = $item->value;
    }

    return $hash;
}

1;
