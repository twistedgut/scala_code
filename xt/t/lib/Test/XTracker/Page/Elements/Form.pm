package Test::XTracker::Page::Elements::Form;
use NAP::policy qw( test );

=head1 NAME

Test::XTracker::Page::Elements::Form

=head1 DESCRIPTION

Helper methods to test HTML page elements for forms defined in
root/base/page_elements/forms.

=head1 SYNOPSIS

In a test:

    use Test::XTracker::Page::Elements::Form;

This class does not export any methids, they must be used fully qualified.

=head1 METHODS

=head2 page__elements__form__select_resultset_ok( $got, $expected, $message )

Test the root/base/page_elements/forms/select_resultset.tt element.

Takes an ArrayRef that represents the contents of an HTML SELECT element from
C<$got> and compares it to the results of calling C<html_select_data> on
C<$expected>, which must be a ResultSet.

The content of C<$got> must be in the following format:

    {
        group   => 'Group Name',
        name    => 'Option Display Name',
        value   => 'Option Value',
    }

Where "group" must be the HTML OPTGROUP the OPTION element is contained in,
"name" is the display value of the OPTION and "value" is the attribute of the
same name. Suitable data can be obtained by using the :w

The  C<$message> is optional and if provided will be suffixed to the sub test
name.

    Test::XTracker::Page::Elements::Form
        ->page__elements__form__select_resultset_ok(
            $got,
            schema->resultset('Public::SomeResultSet')->search_rs( ... ),
            'A description of the test'
        );

=cut

sub page__elements__form__select_resultset_ok {
    my $class = shift;
    my ( $got, $expected, $message ) = @_;

    return fail 'Not an ArrayRef when comparing $got'
        unless ref( $got ) eq 'ARRAY';

    my $test_suffix = defined $message
        ? ": $message"
        : '';

    subtest 'Testing Select ResultSet' . $test_suffix => sub {

        my $current_group   = undef;
        my @dropdown        = @{ $got };
        my @instructions    = @{ $expected->html_select_data };

        foreach my $instruction ( @instructions ) {

            if ( $instruction->{action} eq 'insert-option' ) {

                subtest $instruction->{data}->{display} => sub {

                    cmp_ok( scalar @dropdown, '>', 0,
                        'There are still options to check' );

                    # Get the next item from the dropdown. If there isn't one,
                    # use an empty HashRef so the test below fails rather
                    # than breaks.
                    my $next = @dropdown
                        ? shift @dropdown
                        : {};

                    cmp_deeply( $next, {
                        group   => $current_group,
                        name    => $instruction->{data}->{display},
                        value   => $instruction->{data}->{value},
                    }, "Option inserted correctly" );

                }

            } elsif ( $instruction->{action} eq 'start-group' ) {

                # Update the current group.
                $current_group = $instruction->{data}->{label};

            } elsif ( $instruction->{action} eq 'end-group' ) {

                # Reset the current group.
                $current_group = undef;

            }

        }

    }

}
