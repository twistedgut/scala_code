package Test::XT::Feature::AppMessages;

use NAP::policy "tt", qw( test role );

=head1 NAME

Test::XT::Feature::AppMessages

=head1 DESCRIPTION

Role to add testing methods for various user-displayed messages

=head1 SYNOPSIS

 with 'Test::XT::Feature::AppMessages'; # requires 'mech'

 $self->test_mech__app_info_message__like(qr!to the packing exception desk!);

=head1 METHODS

=head2 test_mech__app_CLASS_message__COMPARATOR

Where C<CLASS> is one of C<error>, C<status>, C<info>, and C<COMPARATOR> is one
of C<is> and C<like>. The C<is> version takes a literal string, the C<like>
version accepts a regular expression.

Calls C<Test::More>'s C<is> or C<like> method appropriately on the user message
of the class specified.

=cut

requires 'mech';

for my $action (qw/is like/) {
    for my $message (qw/ error status info /) {
        my $method_name = 'test_mech__app_' . $message . '_message__' . $action;

        __PACKAGE__->meta->add_method(
            $method_name => sub {
                my ( $self, $compare, $name ) = @_;
                $self->_app_messages_test( $message, $action, $compare, $name );
            }
        );
    }
}

sub _app_messages_test {
    my ( $self, $message_type, $action, $compare, $name ) = @_;

    my $message_method = 'app_' . $message_type . '_message';
    my $received_message = $self->mech->$message_method;

    if ( $action eq 'like' ) {
        like( $received_message // '', $compare, $name );
    } elsif ( $action eq 'is' ) {
        is( $received_message, $compare, $name );
    } else {
        croak "Unknown message comparator [$action]. Choose 'is' or 'like'";
    }

    return $self;
}

1;
