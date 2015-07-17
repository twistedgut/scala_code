package XTracker::Role::Email;
use NAP::policy 'role';

use XTracker::EmailFunctions qw/send_internal_email send_templated_email/;

=head1 NAME

XTracker::Role::Email

=head1 DESCRIPTION

A role for classes that represent a type e-mail that can be sent

=head1 REQUIRED ATTRIBUTES

=head2 path_to_template

Should return the path to the e-mail's template (toolkit) file.
($ENV{XTDC_BASE_DIR} . 'root/base/' can be assumed as a base)

=head2 subject

Should return the text for the subject field of the e-mail

=head2 is_internal

Should return true if this is an internal e-mail, false if not

=head2 template_parameters

Should return a hashref of parameters that will be passed to the e-mail's template

=cut

requires qw/path_to_template subject is_internal template_parameters/;

=head1 PUBLIC ATTRIBUTES

=head2 send_to_address

The e-mail address that the e-mail should be sent to

=cut
has send_to_address => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

=head1 PUBLIC METHODS

=head2 send

Send the e-mail

=cut
sub send {
    my ($self) = @_;

    my $parameters = {
        to          => $self->send_to_address(),
        subject     => $self->subject(),
        from_file   => { path => $self->path_to_template() },
        stash       => {
            template_type => 'email',
            %{$self->template_parameters()},
        },
    };

    my $msg = ($self->is_internal()
        ? send_internal_email(%$parameters)
        : send_templated_email(%$parameters)
    );

    return 1;
}
