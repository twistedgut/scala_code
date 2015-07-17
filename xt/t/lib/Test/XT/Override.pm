package Test::XT::Override;

use NAP::policy "tt";

use Class::Load 'load_class';
use Class::MOP::Package;
use Module::Pluggable::Object;
use Moose::Util 'apply_all_roles';

=head1 NAME

Test::XT::Override - Override XT subroutines.

=head1 SYNOPSIS

    use Test::XT::Override;

    Test::XT::Override->apply_roles

=head1 DESCRIPTION

Use this module to apply roles to packages. It will automatically pick up all
modules that live in C<__PACKAGE__::TraitFor>, and apply anything in them to
the matching packages without the prefix.

=cut

sub _roles {
    my $class = shift;

    return [ sort Module::Pluggable::Object->new(
        search_path => $class->_role_path, require => 1,
    )->plugins ];
}

sub _role_path { __PACKAGE__ . '::TraitFor'; }

=head1 METHODS

=head2 apply_roles()

Apply all roles under C<__PACKAGE__::TraitFor> to their respective modules.

=cut

sub apply_roles {
    my $class = shift;

    for my $role ( @{$class->_roles} ) {
        my $applicant_name = $class->_strip_package_prefix($role);

        # Make sure the applicant is already loaded or our method modifiers
        # wouldn't be applying to anything.
        load_class($applicant_name);
        my $applicant = Class::MOP::Package->initialize($applicant_name);

        # We can't apply roles if our object is immutable, so make it mutable
        # if required...
        my %immutable_options;
        if ( $applicant->can('is_immutable') && $applicant->is_immutable ) {
            %immutable_options = $applicant->immutable_options;
            $applicant->make_mutable;
        }
        apply_all_roles($applicant, $role);
        # ... and re-apply the options
        $applicant->meta->make_immutable(%immutable_options) if %immutable_options;
    }
}

sub _strip_package_prefix {
    my ($class, $role) = @_;
    my $prefix = $class->_role_path . q{::};
    return $role =~ s{\A\Q$prefix}{}r;
}
