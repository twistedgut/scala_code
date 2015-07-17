package Test::RoleHelper;
use NAP::policy "tt", "class";
with "Test::Role::WithSchema";

=head1 NAME

Test::RoleHelper - Container class for Test::Role::* helpers

=head1 DESCRIPTION

This is a helper class to bring together the NAP::Test::Class roles
for use in regular .t files, so that they can be reused across both
Test::Class and .t tests.

The roles are composed at run-time in each test file, according to
whatever functionality the test needs. However, the
Test::Role::WithSchema is always applied.

=SYNOPSIS

    use Test::RoleHelper;
    my $test_helper = Test::RoleHelper->new_with_roles(
        "Test::Role::NominatedDay::WithRestrictedDates",
    );

    my $schema = $test_helper->schema;       # from WithSchema
    $test_helper->delete_all_restrictions(); # from WithRestrictedDates

=cut

use Moose::Util qw/ ensure_all_roles /;

sub new_with_roles {
    my ($class, @roles) = @_;

    my $self = $class->new();
    ensure_all_roles($self, @roles);

    return $self;
}
