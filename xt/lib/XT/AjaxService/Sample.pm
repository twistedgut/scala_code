package XT::AjaxService::Sample;

use strict;
use warnings;


use base qw/ XT::AjaxService /;

use Class::Std;
{

    sub foo {
        my($self) = @_;
        my $response = $self->get_response;

        # code here to do what you need to do to $response

        return $self->return_response;
    }

}
1;

__END__

=pod

=head1 NAME

XT::AjaxService::Sample;

=head1 AUTHOR

Jason Tang

=cut

