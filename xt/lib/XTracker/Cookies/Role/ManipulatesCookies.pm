package XTracker::Cookies::Role::ManipulatesCookies;
use NAP::policy "tt", 'role';

=head1 NAME

XTracker::Cookies::Role::ManipulatesCookies

=head1 DESCRIPTION

Allows modules to manipulate cookies via a supplied Plack::Request object

=head1 ATTRIBUTES

=head2 request

The Plack::Request object

=cut
has 'request' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Plack::Request',
);

=head2 response

The Plack::Response object

=cut
has 'response' => (
    is          => 'ro',
    required    => 1,
    isa         => 'Plack::Response',
);

=head1 ROLE REQUIRED METHODS

Methods that need to be supplied by the implementing object

=head2

=head2 name_template

Returns the template used for this type of cookie's names. The string should
contain '<NAME>' where the individual cookies identifier is inserted.

e.g. 'xt_<NAME>_search'
=cut

requires 'name_template';

=head1 PUBLIC METHODS

Cookies are stored as hashrefs with the following values:

    value   => Value stored,
    path    => ,
    domain  => ,
    expires => When the cookie expires (epoch),

=head2 get_cookie

Return the value for a given cookie

param - $name : Name of cookie requested

return - $cookie_data : Described above

=cut
sub get_cookie {
    my ($self, $name) = @_;
    return $self->request()->cookies()->{$self->_get_full_cookie_name($name)};
}

=head2 set_cookie

Set some cookie data in the response

param - $name : Name of cookie to set
param - $cookie_data : Described above

=cut
sub set_cookie {
    my ($self, $name, $cookie_data) = @_;
    my $cookie_name = $self->_get_full_cookie_name($name);
    $self->response()->cookies()->{$cookie_name} = $cookie_data;
    return 1;
}

=head2 unset_cookie

Remove some cookie data from the response

param - $name : Name of cookie to unset

=cut
sub unset_cookie {
    my ($self, $name) = @_;
    my $cookie_name = $self->_get_full_cookie_name($name);
    delete $self->response()->cookies()->{$cookie_name};
}

=head2 expire_cookie

Assuming the cookie actually exists, it will be set to expire
(else nothing will happen)

param - $name : Name of cookie to expire

=cut
sub expire_cookie {
    my ($self, $name) = @_;
    return 1 unless $self->get_cookie($name);
    $self->set_cookie($name, {
        expires => -1,
        path    => '/',
    });
    return 1;
}

# Helper function to return the 'full' name for this cookie
# e.g. the name given wrapped in this cookie type's template
sub _get_full_cookie_name {
    my ($self, $name) = @_;

    my $template = $self->name_template();
    $template =~ s/<NAME>/$name/g;
    return $template;
}
