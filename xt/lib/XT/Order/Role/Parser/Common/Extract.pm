package XT::Order::Role::Parser::Common::Extract;
use Moose::Role;

sub _extract {
    my($self,$keys,$node) = @_;

    my $out;
    foreach my $key (keys %{$keys}) {
        if (defined $key) {
            $out->{$keys->{$key}} = $node->{$key} || '';
        }
    };

    return $out;
}

sub _extract_fields {
    my($self,$node,$mapping) = @_;

    my $out = { };
    foreach my $key (keys %{$mapping}) {
        # FIXME try/catch -> throw exception
        eval {
            my $field = $mapping->{$key};
            $out->{$key} = $node->{$field} || '';
        };
        if ($@) {
            print "FECK $@ ". caller()." ". ref($node)
            ." ". pp($node)
            ." ". pp($mapping) ."\n";
        }
    }

    return $out;
}
1;
