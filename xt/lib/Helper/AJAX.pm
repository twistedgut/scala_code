package Helper::AJAX;

use strict;
use warnings;
use Plack::App::FakeApache1::Constants qw(:common);
use Carp;
use Class::Std;
use JSON;

use XTracker::XTemplate;

use base qw/ Helper::Class /;

{
    my %request_of :ATTR( get => 'request', set => 'request', init_arg=> 'request');

    sub respond_in_json {
        my($self,$data) = @_;
        my $request = $self->get_request;

        $request->content_type('text/json');
        $request->print( encode_json( $data ) );

        return OK;
    }

    sub respond_with_parsed_template {
        my ($self, $template_name, $data) = @_;

        my $request = $self->get_request;
        my $template = XTracker::XTemplate->template();

        $template->process(
            $template_name,
            $data
        );

        $request->content_type('text/plain');
        return OK;
    }

    sub process_request {
        croak "You probably meant to override 'process_request'";
    }

}
1;
__END__

=head1 NAME

Helper::AJAX - a simple class to provide generally useful stuff

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
I'm sure there are modules out there to do this!!! Investigate

=head1 AUTHOR

Jason Tang jason.tang@net-a-porter.com

=cut


