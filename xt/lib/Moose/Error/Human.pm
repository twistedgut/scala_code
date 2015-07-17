package Moose::Error::Human;

use strict;
use warnings;

use base qw(Moose::Error::Default);

sub create_error_croak {
    my ( $self, %args ) = @_;
    return $args{message};
}

sub create_error_confess {
    my ( $self, %args ) = @_;
    return $args{message};
}

1;

# ABSTRACT: Prefer C<confess>

__END__

=pod

=head1 NAME

Moose::Error::Human - Prefer C<confess>

=head1 VERSION

version 2.0802

=head1 SYNOPSIS

    # Metaclass definition must come before Moose is used.
    use metaclass (
        metaclass => 'Moose::Meta::Class',
        error_class => 'Moose::Error::Human',
    );
    use Moose;
    # ...

=head1 DESCRIPTION

This error class uses L<Carp/confess> to raise errors generated in your
metaclass.

=head1 AUTHOR

Moose is maintained by the Moose Cabal, along with the help of many contributors. See L<Moose/CABAL> and L<Moose/CONTRIBUTORS> for details.

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Infinity Interactive, Inc..

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

