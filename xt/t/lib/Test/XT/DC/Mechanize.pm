package Test::XT::DC::Mechanize;
# vim: set ts=4 sw=4 sts=4:

use NAP::policy "tt", 'class';
use MooseX::NonMoose;
use Test::XT::PSGI;
extends 'Test::WWW::Mechanize::PSGI';

use Test::XTracker::Data;

# TODO-PSGI: Documentation

sub FOREIGNBUILDARGS {
    my $class = shift;
    return (app => Test::XT::PSGI->new->app);
}

with 'WWW::Mechanize::TreeBuilder' => { tree_class => 'HTML::TreeBuilder::XPath' },
     'Test::XTracker::Client',
;

=head2 login_ok

=cut

sub login_ok {
    my ($self) = @_;

    my $operator = Test::XTracker::Data->_get_operator('it.god');
    Test::XTracker::Data->_enable_operator($operator);

    $self->get('/Login');

    # There is a Plack Auth middleware that ensures that all logins to the
    # server running under the 'test' env are always 'it.god'. See xt.psgi and
    # the NAP::AuthForm authenticator
    $self->post('/Login', { username => 'it.god',
                            password => 'nopass' });

    return $self;
}

=head2 grant_permissions

=cut

sub grant_permissions {
    my ($self, $args) = @_;

    my @auths;

    foreach my $level ( keys %{$args->{perms}} ) {
        my @paths = @{$args->{perms}->{$level}};
        push( @auths, map {
            [ split(/\//, $_), $level ]
        } @paths );
    }

    my $schema = XT::DC->model('DB')->schema;

    my $operator = $schema->resultset('Public::Operator')->search( {
        username => $args->{operator} // 'it.god'
    } )->first;
    die "No such operator" unless $operator;

    if ( defined $args->{dept} ) {
        # If the department exists assign the operator to it
        my $dept = $schema->resultset('Public::Department')->search( {
            department => $args->{dept}
        } )->first;

        if ( ! $dept ) {
            die "Unable to find department '". ($args->{dept} // '') ."'";
        }
        $operator->update( { department_id => $dept->id } );
    }

    foreach my $auth ( @auths ) {
        my $section = $auth->[0];
        my $sub = $auth->[1];
        my $level = $auth->[2];

        my $sub_section = $schema->resultset('Public::AuthorisationSubSection')->search( {
            'me.sub_section'    => $sub,
            'section.section'   => $section,
        },
        {
            join => 'section',
        } )->first;

        die "Unable to find auth section $section/$sub" unless $sub_section;

        my $current = $operator->permissions->search( {
            authorisation_sub_section_id    => $sub_section->id
        } )->first;

        if ( $current ) {
            $current->update( { authorisation_level_id => $level } );
        }
        else {
            $operator->permissions->create( {
                authorisation_sub_section_id    => $sub_section->id,
                authorisation_level_id          => $level
            } );
        }
    }

    return $operator;
}

1;
