package XTracker::Cookies;
use NAP::policy "tt", 'class';
use MooseX::Params::Validate;
use Module::Runtime 'require_module';

with 'XTracker::Cookies::Role::ManipulatesCookies';

=head1 NAME

XTracker::Cookies

=head1 DESCRIPTION

Allows manipulation of cookies through the XTracker::Cookies::Role::ManipulatesCookies
role. Also allows access to more specialised cookie classes

=head1 PUBLIC METHODS

=head2 get_cookies

Factory method that will return an object to manipulate cookies.

param - request : A Plack::Request object (required)
param - response : A Plack::Response object (required)
param - plugin : Identifier for a specialised Cookie class where:
    XTracker::Cookies::Plugin::$plugin
    If not supplied, an XTracker::Cookies object will be returned

return - XTracker::Cookies::Role::ManipulatesCookies implementing cookie object
=cut
sub get_cookies {
    my $class = shift;
    my ($request, $response, $plugin) = validated_list(\@_,
        request     => { isa => 'Plack::Request' },
        response    => { isa => 'Plack::Response' },
        plugin      => { isa => 'Str', optional => 1 }
    );

    my $class_name;
    if ($plugin) {
        # User wants specialised cookies
        $class_name = "XTracker::Cookies::Plugin::$plugin";
        try { require_module($class_name) }
        catch { die "Error loading plugin '$plugin': $_" };
    } else {
        # Use base class then
        $class_name = $class;
    }
    return $class_name->new(
        request     => $request,
        response    => $response,
    );
}

sub name_template {
    return '<NAME>';
};
