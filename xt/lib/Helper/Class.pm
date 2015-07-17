package Helper::Class;

use strict;
use warnings;
use Carp;
use Class::Std;

{
    my %debug_of :ATTR( get => 'debug', set => 'debug' );


    sub debug {
        my($self,$value) = @_;

        if (defined $value) {
            $self->set_debug($value);
        }

        return $self->get_debug;
    }

    sub check_params {
        my($self,$keys,$inattr) = @_;

        if (ref($keys) ne 'ARRAY') {
            #throw Error::Simple('$keys parameter expecting ARRAY ref');
            croak('$keys parameter expecting ARRAY ref');
        }

        if (ref($inattr) ne 'HASH') {
            #throw Error::Simple('$inattrs parameter expecting HASH ref');
            croak('$inattrs parameter expecting HASH ref');
        }

        foreach my $key (@{$keys}) {
            if (not defined $inattr->{$key}) {
                #throw Error::Simple('missing required field - '. $key);
                croak('missing required field - '. $key);
            }
        }

        return;
    }

}
1;
__END__

=head1 NAME

Helper::Class - a simple class to provide generally useful stuff

=head1 SYNOPSIS

 use Helper::Class;
 use base qw/ Helper::Class /;

 # provides
 $obj->debug(1);

 $obj->check_caller($regex);

 $obj->check_params(
    [ qw/ one two three four/ ],
    $hash_ref);

# throws Error::Simple - $E->{-text} for error message

=head1 FUTURE ENHANCEMENTS

check_params - room to extend this to provide typing of required fields
I'm sure there are modules out there to do this!!! Invesgitate

=head1 AUTHOR

Jason Tang jason.tang@net-a-porter.com

=cut


