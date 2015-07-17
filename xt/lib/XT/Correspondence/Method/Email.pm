package XT::Correspondence::Method::Email;

use NAP::policy "tt",     'class';

extends 'XT::Correspondence::Method';

=head1 XT::Correspondence::Method::Email

This is the Class used to send Emails, it extends 'XT::Correspondence::Method'.

    my $corr_email_obj  = XT::Correspondence::Method->new( {
                                                    # see 'XT::Correspondence::Method' for details of the
                                                    # arguments required for all 'X::C::Method' Classes
                                                    csm_rec     => $correspondence_subject_method record
                                                    record      => The record used as a basis for sending the Correspondence
                                                    use_to_send => The Class such as 'Shipment' or 'Order' to use as a basis to find
                                                                   the correct Email or Mobile number to send the Correspondence to
                                                    body        => The body of the Message that will be sent

                                                    subject     => The Subject for the Email
                                            } );

Without passing the 'email_to' in directly it will use the 'use_to_send' Class to get it.


First done for CANDO-576.

=cut

use MooseX::Types::Moose qw( Object );
use XT::Data::Types;

use XTracker::Config::Local         qw( email_address_for_setting );


=head1 ATTRIBUTES

Here is the list of Attributes for this Class.

=cut

=head2 subject

The Subject for the Email.

=cut

has subject => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'subject',
    required    => 1,
);

=head2 email_to

The Address to send the Email to, will be derived from the 'use_to_send' record unless directly passed to 'new()'.

=cut

has email_to => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'email_to',
    lazy_build  => 1,
);

=head2 email_from

The From Address for the Email, will be derived from the 'csm_rec' record unless directly passed to 'new()'.

=cut

has email_from => (
    is          => 'rw',
    isa         => 'Str',
    init_arg    => 'email_from',
    lazy_build  => 1,
);


# do some validation for some of the Args.
sub BUILD {
    my ( $self, $args ) = @_;

    # if the 'email_to' has not been
    # explicitly passed in then check that
    # the 'send_record' can call 'email'
    if ( !$args->{email_to} ) {
        if ( !$self->send_record->can('email') ) {
            croak "'send_record/use_to_send' passed in '" . ref( $self->send_record ) . "' can't call method 'email' for '" . __PACKAGE__ . "'";
        }
    }

    return $self;
};

=head1 METHODS

Here are the Methods for this Class.

=cut

=head2 send_correspondence

    $boolean    = $self->send_correspondence();

Will Send an Email.

Will return TRUE or FALSE if it succeeded in doing this.

=cut

sub send_correspondence {
    my $self    = shift;

    my $result  = 0;

    if ( $self->_ok_to_send ) {
        eval {
            $result = $self->send_an_email( {
                                        from    => $self->email_from,
                                        replyto => $self->email_from,
                                        to      => $self->email_to,
                                        subject => $self->subject,
                                        body    => $self->body,
                                    } );
        };
        if ( my $err = $@ ) {
            $self->logger->warn( "Failed to Send an Email (Subject: '" . $self->subject . "') to '" . $self->email_to . "' in '" . __PACKAGE__ . "' with the following error:\n$err" );
        }
    }
    else {
        $self->logger->warn( "NOT OK to Send an Email (Subject: '" . $self->subject . "') to '" . $self->email_to . "' in '" . __PACKAGE__ . "' with Failure Code: " . $self->_failure_code );
    }

    return $result;
}


# Get an Email To Address
sub _build_email_to {
    my $self    = shift;
    return $self->send_record->email || "";
}

# Get an Email From Address
sub _build_email_from {
    my $self    = shift;

    # on the 'csm' rec in the 'send_from' field should
    # be the email setting used to get the from address
    return email_address_for_setting( $self->csm_rec->send_from, $self->channel ) || "";
}

# check whether it is ok to send an Email
around _ok_to_send => sub {
    my ( $orig, $self ) = @_;

    if ( !$self->email_to ||
         !$self->email_from ||
         !$self->subject ||
         !$self->body ) {
        return 0;
    }

    return $self->$orig();
};

1;
