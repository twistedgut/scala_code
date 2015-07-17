package XTracker::Admin::UserAdmin;

use strict;
use warnings;

use Data::Page;

use XTracker::Handler;
use XTracker::Constants qw{ $PER_PAGE };
use XTracker::Database qw ( :common );
use XTracker::Navigation;

use Plack::App::FakeApache1::Constants qw(:common);
use XTracker::DBEncode      qw( encode_it );

use vars qw($r $operator_id $auth_level);

sub handler {
    my $handler = XTracker::Handler->new(shift);

    if ( $handler->{param_of}{export_permissions} ) {
        return _export_permissions( $handler );
    }

        my $schema              = $handler->{schema};
        my $oper_rs;
        my $results;
        my $total               = 0;

    $operator_id = $handler->{data}{'operator_id'};
    $auth_level  = $handler->{data}{'auth_level'};

    my $page = Data::Page->new();
    $page->current_page( $handler->{param_of}{'page'} || 1 );
    $page->entries_per_page( $handler->{param_of}{'results'} || $PER_PAGE );
        $oper_rs        = $schema->resultset('Public::Operator');

        $handler->{data}{content}               = 'shared/admin/users.tt';
        $handler->{data}{section}               = 'User Admin';
        $handler->{data}{subsection}    = 'User List';
        $handler->{data}{subsubsection} = '';
        $handler->{data}{mainnav}               = build_nav($operator_id);
        $handler->{data}{auth_level}    = $auth_level;
        $handler->{data}{yui_enabled}   = 1;
        $handler->{data}{js}                    = ['/javascript/yui_autocomplete.js',];

        $handler->{data}{users} = _get_users($oper_rs, $page, $auth_level);

# Remove as Fulcrum now does the Creation of new Users
#       if ( $auth_level > 1 ) {
#               push(
#                       @{ $handler->{data}{sidenav}[0]{'None'} },
#                       { 'title' => 'Create New User', 'url' => "/Admin/UserAdmin/Profile" }
#               );
#       }

    # pass the page object through to the template
    $handler->{data}{pager} = $page;

        return $handler->process_template( undef );
}

### Subroutine : _get_users                     ###
# usage        :                                  #
# description  :                                  #
# parameters   :                                  #
# returns      :                                  #

sub _get_users {
        my ($rs, $page, $auth_level) = @_;
    my %customer = ();
        my ($results,$total);
        my %cond;

    # operator level access can only view memebers of Distribtuion dept.
        %cond   = %{ ( $auth_level == 2 ? { department => 'Distribution' } : {} ) };

        $total  = $rs->count(\%cond,{ join => 'department' });
    $page->total_entries($total);

        $results= $rs->operator_list(\%cond,$page->entries_per_page,$page->skipped);

    foreach my $row (@{ $results }) {
        my $cust_ref = $row->customer_ref();

        $customer{ $cust_ref }{id}                      = $row->id;
        $customer{ $cust_ref }{name}            = $row->name;
        $customer{ $cust_ref }{username}        = $row->username;
        $customer{ $cust_ref }{password}        = $row->password;
        $customer{ $cust_ref }{auto_login}      = $row->auto_login;
        $customer{ $cust_ref }{disabled}        = $row->disabled;
        $customer{ $cust_ref }{ldap}            = $row->use_ldap;
        $customer{ $cust_ref }{dept}            = $row->department->department          if ($row->department);
    }
    return \%customer;
}

sub _export_permissions {
    my ( $handler ) = @_;

    my $schema = $handler->schema;

    # list of permissions to build the column headings
    # (some permissions might not be assigned to any users)
    my @permissions = $schema->resultset('Public::AuthorisationSubSection')->permissions_hashref->all;

    # list of users to build the user list
    # (some users may not have any assigned permissions)
    my @users = $schema->resultset('Public::Operator')->search(undef,
        {
            join => 'department',
            columns => [ 'me.name', 'department.department' ],
            order_by => 'me.name',
            result_class => 'DBIx::Class::ResultClass::HashRefInflator',
        }
    );

    # get permissions for users and arrange them for the template
    my @user_permissions = $schema->resultset('Public::AuthorisationSubSection')->data_for_user_access_report;

    my $permissions_for_template = { };

    for my $user_permission (@user_permissions) {
        my $username = $user_permission->{operator}{name};
        my $section = $user_permission->{section}{section};
        my $sub_section = $user_permission->{sub_section};
        my $level = $user_permission->{auth_level}{description};

        $permissions_for_template->{$username}{$section}{$sub_section} = $level;
    }

    # TT is too slow for this - generate and write the CSV directly :(
    my $body = '';

    # add headings to CSV
    $body .= join(',', map { qq|"$_"| } ('', '', map { $_->{section}{section} } @permissions))."\n";
    $body .= join(',', map { qq|"$_"| } (qw|User Department|, map { $_->{sub_section} } @permissions))."\n";

    # add user permissions to CSV
    for my $user (@users) {
        my $username = $user->{name} // '';
        my $department = $user->{department}{department} // '';
        $body .= join(',', map { qq|"$_"| } $username, $department);
        for my $permission (@permissions) {
            my $section = $permission->{section}{section};
            my $sub_section = $permission->{sub_section};
            my $level = $permission->{auth_level}{description};
            $body .= ',"' . ($permissions_for_template->{$username}{$section}{$sub_section} // '') . '"';
        }
        $body .= "\n";
    }

    # we're generating a CSV file rather than a regular rendered template
    $handler->{r}->header_out( 'Content-Disposition' => 'inline; filename="permissions.csv"' );
    $handler->{r}->header_out( 'Content-Length' => length( $body ) );
    $handler->{r}->content_type( 'text/csv' );

    $handler->{r}->print( encode_it($body) );

    return OK;
}

1;
