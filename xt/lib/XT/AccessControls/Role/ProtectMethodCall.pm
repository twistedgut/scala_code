package XT::AccessControls::Role::ProtectMethodCall;
use NAP::policy;


=head1 XT::AccessControls::Role::ProtectMethodCall

Protects Method Calls.

Usage :
   with 'XT::AccessControls::Role::ProtectMethodCall' => {
      protect => {
          <XYY_method_name> => {
              roles               => [ <ldap_roles>],# array of roles for accessing method call
              return_if_no_access => { }, # return type, return {} if no access
          }
      }
  };

Here <XYZ_method_name> method would return data for specified <ldap_roles> and would return
empty HashRef as return type if access is denied. You can specify what return type method
should return if access is denied. To test if the method call was allowed or not, attribute
"pmc_<method_name>_was_allowed" attribute can be used. Note that this would return data of last
method call. So make sure to use it as soon as you load the class.

=cut

use MooseX::Role::Parameterized;

parameter protect => (
    isa         => 'HashRef',
    required    => 1,
);

role {
    my $self = shift;

    foreach my $method ( keys %{ $self->protect } ) {

        # Get the roles & return _type
        my $roles                = $self->protect->{$method}->{roles};
        my $return_if_no_access  = $self->protect->{$method}->{return_if_no_access};

        my $method_name     = "protected_${method}";
        my $attribute_name  = "pmc_${method_name}_call_was_allowed";

        # Define attribute to tell if the method
        # returned protected data or access was denied
        has $attribute_name => (
            is      => 'rw',
            isa     => 'Bool',
            default => 0,
        );

        method $method_name => sub {
            my $self   = shift;
            my @params = @_;

            my $allowed = 0;

            # Check if method is protected
            if( $self->can("acl") && blessed($self->acl) ) {
                # if operators has correct roles,
                # set allowed=1 else undef
                $allowed = $self->acl->operator_has_role_in($roles);
            }

            $self->$attribute_name( $allowed );


            return( $allowed
                    ? $self->$method( @params)
                    : $return_if_no_access
            );


        }
    }
};

1;
