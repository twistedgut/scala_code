package XT::Net::Seaview::Role::GenAttrs;

use strict;
use warnings;
use true;

use MooseX::Role::Parameterized;

parameter fields => (
    isa      => 'HashRef',
    required => 1,
);

role {
    my $p = shift;

    foreach my $attrib (keys %{$p->fields}){
        has $attrib => (
            is      => 'ro',
            lazy    => 1,
            default => sub {
                return $_[0]->data->{$p->fields->{$attrib}}
            },
        );
    }
}
