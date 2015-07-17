package NAP::Template::Plugin::URLRoleFilter;

use NAP::policy "tt";

=head1 NAME

NAP::Template::Plugin::URLRoleFilter

=head1 DESCRIPTION

Used to Filter Forms & Links where their URLs should be restricted or
restricting by a TAGs 'class' attribute value.

Each TAG that needs restricting will be removed along with any of its children.

In the case of Links any <a> tag that is in an Unordered List (<ul>) will
not only be removed but if afterwards the list is now empty will also have its
parent <ul> tag removed.

=cut

use Template::Plugin::Filter;
use parent              qw( Template::Plugin::Filter );

use HTML::TreeBuilder;
use HTML::Element;

# used for dumping data to logs
use Data::Dumper;

use XTracker::Logfile   qw( xt_logger );
use Const::Fast;

our $DYNAMIC = 1;
const my $kill_parent => 1;

# This flag is used to indicate that the Log Level is TRACE.
# The reason for this is there are several 'trace' statements
# which dump data structrures and the act of dumping these
# structures can take time. Even though the trace message
# may never get to a log file it still does the dumping
# when it constructs the message and so takes time. This
# is for performance reasons and its use does get a little
# messy.
my $is_tracing = 0;
sub _set_is_trace_flag {
    my $self = shift;
    return $is_tracing = shift;
}

# store the Logger
my $logger;
sub _set_logger {
    my $self = shift;
    $logger = xt_logger();
    $self->_set_is_trace_flag( $logger->is_trace );
    return $logger;
}

# store the XT::AccessControls object
my $acl;
sub _set_acl {
    my $self = shift;
    return $acl = shift;
}

# build the restrictions that need to be done
my $restriction_conf;
sub _set_restriction_conf {
    my ( $self, $conf ) = @_;

    # make sure any setting set from
    # previous calls will be wiped out
    $restriction_conf = {};

    my $default_action = $conf->{default_action} // 'remove';

    foreach my $key ( keys %{ $conf } ) {
        if ( $key =~ m/^restrict_(?<category>.*)/ ) {
            my $category    = $+{category};
            my $restriction = $conf->{ $key };

            # 'url' restrictions will be an Array Ref of
            # types of restrictions to apply, where as
            # 'class' restrictions will be a Hash Ref of
            # CSS Classes & the Roles that can see them

            given ( $category ) {
                when ( 'url' ) {
                    foreach my $option ( @{ $restriction } ) {
                        die "Invalid Option passed to '${key}' should be either SCALAR or ARRAY Ref"
                                if ( ref( $option ) && ref( $option ) ne 'ARRAY' );
                        my ( $type, $action ) = ( ref( $option ) ? @{ $option } : ( $option, $default_action ) );
                        $restriction_conf->{ $category }{ $type } = { action => $action };
                    }
                }
                when ( 'class' ) {
                    while ( my ( $class, $options ) = each %{ $restriction } ) {
                        die "Invalid Option passed to '${class}' for '${key}' should be either a HASH or ARRAY Ref"
                                if ( !ref( $options ) || ref( $options ) !~ m/(ARRAY|HASH)/ );
                        $restriction_conf->{ $category }{ $class } = {
                            ref( $options ) eq 'HASH'
                            ? %{ $options }
                            : ( roles => $options, action => $default_action )
                        };
                    }
                }
                default {
                    $logger->logcroak( "Don't know how to Restrict '${category}', in '" . __PACKAGE__ . "'" );
                }
            }
        }
    }

    $logger->logcroak( "Wasn't asked to Restrict anything, in '" . __PACKAGE__ . "'" )
                    if ( !scalar( keys %{ $restriction_conf } ) );

    return $restriction_conf;
}


=head1 METHODS

=head2 filter

This is the automatically called method by the TT infrastructure when you use this filter.

    # to call it using perl
    my $plugin = NAP::Template::Plugin::URLRoleFilter->new;
    $string    = $plugin->filter(
        $text_to_be_filterd,
        [ $xt_access_controls_object ],
        # restrictions Hash Ref
        {
            # what you want the default action to be for the restrictions
            # if omitted then 'remove' will be set as the default
            default_action => 'remove' or 'disable' or 'empty',
            # include this if you want to exclude by URL for <form> or <a> tags
            restrict_url => [
                'form',                 # set this to restrict forms
                [ 'link', 'disable' ],  # set this to 'disable' a link which overrides the default action to 'remove'
                'sidenav',              # set this if specifically protecting a Sidenav
            ],
            # include this if you want to remove TAGs by their 'class' Attribute
            restrict_class => {
                # class_name => [ qw( list of role names ) ],
                #         or
                # class_name => { roles => [ qw( roles ) ], action => 'empty' },
                aclprotect_data      => [ qw( app_can_see_some_stuff ) ],   # to remove TAGs with class 'aclprotect_data'
                aclprotect_more_data => {
                    # to 'disable' TAGs with class of 'aclprotect_more_data' overriding the default 'remove' action
                    roles  => [ qw( app_can_see_some_more_stuff app_can_see_everyting ) ],
                    action => 'disable',
                },
            },
        }
    );

    # to call it in a TT Document
    [%-
        USE URLRoleFilter;
        SET restriction_hash = {
            default_action = 'remove',
            restrict_url = {
                [ 'form', [ 'link', 'disable' ] ],
            }
            restrict_class = {
                aclprotect_add_entry  = [ 'app_can_add' ],
                aclprotect_edit_entry = { roles = [ 'app_can_add' ], action = 'disable' },
            },
        };
    -%]
    [%- FILTER $URLRoleFilter xt_access_controls_obj restriction_hash -%]
        <form action="/Some/URL">
            DOB: <input type="text" class="aclprotect_edit_entry" value="01/01/1900" />
            <button type="submit">Press Big Red Button</button>
        </form>
        <ul>
            <li><a href="/Some/Other/URL">Click to see Secrets</a></li>
        </ul>
        <div>
            <p class="aclprotect_data">
                Credit Card Information: 1231231231
            </p>
            <p class="aclprotect_more_data">
                Bank Account Number: 213412344
            </p>
            <p class="in_bold">
                Trivial Information: Red
            </p>
        </div>
    [%- END # FILTER -%]

You need to pass in an instance of 'XT::AccessControls' as this will be used to check the
Roles of the Operator viewing the TT Document against what is asked to be restricted.

Pass in a Hash Ref. detailing what restrictions are to be applied to the Document.

There are the following Actions you can use to restrict:
    * remove (default)
    * disable
    * empty

Use the 'default_action' key to specify which of the above should be the default behaviour
for the restrictions.

Removing will simply remove the TAG and its children from the Document.

Emptying will keep the TAG in the Document but clear its content which will include
removing any child TAGs if there are any. This doesn't make sense to use this for Forms
and Links they should be either Removed or Disabled, this is mainly to be used to
maintain structure on a page such as keeping <td> tags that would upset the rest of a
<table> if they were removed such as 'colspan' settings.

Disabling will do one of the following:
    * form    : will set the 'disabled' attribute on each of the elements within the <form>.
    * link    : will empty the 'href' attribute.
    * sidenav : will empty the 'href' attribute.
    * class   : will set a 'disabled' attribute on the TAG, if this is not supported by the
                TAG then it will have no effect, if the class is on a <form> tag then it
                will behave as above for 'form'.

When restricting a URL the 'XT::AccessControls' object will be used to call its
'url_restrictions' method and give back all URLs and the Roles required to use them. These
will then be compared with the URLs in the Document and if there are any matches and the
Operator doesn't have the required Roles, then the 'action' specified for them will be done.

When restricting by a TAGs 'class' Attribute a Hash Ref. of classes in the Document along
with the Roles required to see them will be passed in and this will be used to find all
TAGs which have one of these Class names and when found will be checked against the
Operator's Roles using the 'XT::AccessControls' object and if the Operator has at least
one Role required then they can see the TAG but if they don't have any of the Roles the TAG
will be dealy with using the 'action' specified for it.

Use the 'sidenav' option with 'restrict_url' to protect a Sidenav. This is different to
'link' as any Sidenav Headings will be Removed if all of the Options under them are also
Removed.

=cut

sub filter {
    my ( $self, $text, $args, $conf ) = @_;

    $self->_set_logger();

    # Merge USE and FILTER parameters
    $args = $self->merge_args($args);
    $conf = $self->merge_config($conf);

    $self->_set_acl( $args->[0] );
    $self->_set_restriction_conf( $conf );

    # DEBUG
    if ( $is_tracing ) {
        local $Data::Dumper::Indent = 1;
        local $Data::Dumper::Maxdepth = 5;

        # $args contains $acl which contains DBIC objects which *are
        # huge*; don't dump them!
        #$logger->trace( 'ARGS: ' . Dumper( $args ) );
        $logger->trace( 'CONF: ' . Dumper( $conf ) );
        $logger->trace( 'RSTR: ' . Dumper( $restriction_conf ) );
    }

    # create an HTML tree
    my $tree = HTML::TreeBuilder->new_from_content( $text );

    # Find and Protect restricted links, sidenav, forms & classes
    $self->_protect_links( $tree );
    $self->_protect_sidenav( $tree );
    $self->_protect_forms( $tree );
    $self->_protect_classes( $tree );

    # Return the filtered tree or a comment element if we've removed the
    # whole thing. We can only pull out the guts once.
    my $guts = $tree->guts;
    return (
        defined $guts
        ? $guts->as_HTML
        : HTML::Element->new( '~comment', 'text' => 'REDACTED' )->as_HTML
    );
}

# private method to get rid of Forms
sub _protect_forms {
    my ( $self, $tree ) = @_;

    my $options = $restriction_conf->{url}{form};
    return      if ( !$options );

    my @forms = $tree->look_down( '_tag', 'form' );

    foreach my $form ( @forms ) {
        $logger->trace( 'LOOKING AT FORM ACTION: ' . ( $form->attr('action') // 'undef' ) );
        $self->_restrict( {
            element      => $form,
            restrictions => $acl->url_restrictions,
            key          => $self->_strip_url( $form->attr('action') ),
            action       => $options->{action},
        } );
    }

    return;
}

# private method to get rid of Links
sub _protect_links {
    my ( $self, $tree ) = @_;

    my $options = $restriction_conf->{url}{link};
    return      if ( !$options );

    # Find and kill restricted links
    my @links = $tree->look_down('_tag', 'a');

    foreach my $link ( @links ) {
        $logger->trace( 'LOOKING AT LINK: ' . ( $link->attr('href') // 'undef' ) );
        $self->_restrict( {
            element      => $link,
            restrictions => $acl->url_restrictions,
            key          => $self->_strip_url( $link->attr('href') ),
            action       => $options->{action},
            kill_parent  => $kill_parent,
        } );
    }

    # Delete the wrapping links list (<ul></ul>) if it's empty
    my @link_wrappers = grep { $_->is_empty } $tree->look_down( '_tag', 'ul' );
    $_->delete          foreach ( @link_wrappers );

    return;
}

# private method to protect a Sidenav which also
# removes any Sidenav Headings if all of the
# options under them have been removed
sub _protect_sidenav {
    my ( $self, $tree ) = @_;

    my $options = $restriction_conf->{url}{sidenav};
    return      if ( !$options );

    # Find and kill restricted links
    my @list_items = $tree->look_down('_tag', 'li');

    my $link_heading;
    my $can_delete_heading = 1;
    OPTION:
    foreach my $item ( @list_items ) {
        # get a link in the '<li>' tag if there isn't one then
        # look for a '<span>' tag which must be the heading
        my $link = $item->look_down('_tag', 'a');
        if ( !$link ) {
            $link_heading->parent->delete       if ( $link_heading && $can_delete_heading );
            $link_heading = $item->look_down('_tag', 'span');
            $can_delete_heading = 1;
            next OPTION;
        }

        $logger->trace( 'LOOKING AT SIDENAV LINK: ' . ( $link->attr('href') // 'undef' ) );
        $self->_restrict( {
            element      => $link,
            restrictions => $acl->url_restrictions,
            key          => $self->_strip_url( $link->attr('href') ),
            action       => $options->{action},
            kill_parent  => $kill_parent,
        } );

        # if all Options are deleted then $can_delete_heading will be TRUE
        $can_delete_heading &= $item->is_empty // 0;
    }
    $link_heading->parent->delete       if ( $link_heading && $can_delete_heading );

    # Delete the wrapping links list (<ul></ul>) if it's empty
    my @link_wrappers = grep { $_->is_empty } $tree->look_down( '_tag', 'ul' );
    $_->delete          foreach ( @link_wrappers );

    return;
}

# private method to get rid of TAGs by 'class' Attribute
sub _protect_classes {
    my ( $self, $tree ) = @_;

    my $restricted = $restriction_conf->{class};
    return      if ( !$restricted );

    foreach my $class_name ( keys %{ $restricted } ) {
        my @classes = $tree->look_down( 'class', qr/\b${class_name}\b/ );
        # need to set class name even though it's the only key so
        # as to keep in-line with how 'form' & 'link' are handled
        my $roles   = { $class_name => $restricted->{ $class_name }{roles} };
        my $action  = $restricted->{ $class_name }{action};
        foreach my $elem ( @classes ) {
            $self->_restrict( {
                element      => $elem,
                restrictions => $roles,
                key          => $class_name,
                action       => $action,
            } );
        }
    }

    return;
}

# this actually does the restricting, given a tag
# a set of restrictions and the Roles required to
# see the tag, it will either leave it alone or
# restrict it based on the 'action' to be done
sub _restrict {
    my ( $self, $args ) = @_;

    my $element         = $args->{element};
    my $restrictions    = $args->{restrictions};
    my $key             = $args->{key};
    my $action          = '_' . $args->{action} . '_element';
    my $kill_parent     = $args->{kill_parent} // 0;

    $logger->trace( "KEY: '${key}', ACTION: '${action}'" );

    # Grab access restrictions - unroll array if present
    my $restrict_unless = $restrictions->{ $key } // [];

    if ( $is_tracing ) {
        local $Data::Dumper::Indent = 1;
        local $Data::Dumper::Maxdepth = 5;
        $logger->trace( 'RESTRICTIONS: ' . Dumper( $restrict_unless ) );
    }

    # Only restrict if we have restrictions
    if ( @{ $restrict_unless } ) {
        if ( !$acl->operator_has_role_in( $restrict_unless ) ) {
            # perform the appropriate Action
            $self->$action( $element, $key, $kill_parent );
        }
        else {
            $logger->trace( "'${key}' left alone" );
        }
    }

    return;
}

# 'remove' an Element
sub _remove_element {
    my ( $self, $element, $key, $want_to_kill_parent ) = @_;

    my $kill_parent = 0;

    if ( $element->tag eq 'a' && $element->parent->tag eq 'li' ) {
        # XT links are wrapped in list items (<li></li>) so we delete that if
        # requested. This also nukes the elements children - the link itself
        $kill_parent = $want_to_kill_parent;
    }

    $kill_parent ? $element->parent->delete
                 : $element->delete;

    $logger->trace( "'${key}' removed" );

    return;
}

# 'empty' an Element
sub _empty_element {
    my ( $self, $element, $key ) = @_;

    $element->delete_content;

    $logger->trace( "'${key}' emptied" );

    return;
}

# 'disable' an Element
sub _disable_element {
    my ( $self, $element, $key ) = @_;

    my $tag_name = $element->tag;

    # pattern for <form> elements that
    # can have a 'disabled' attribute
    my $disableable_elements = qr/^(
        input |
        textarea |
        button |
        select |
        option |
        optgroup |
        fieldset
    )$/ix;

    given ( $tag_name ) {
        when ( 'a' ) {
            # remove the Link
            $element->attr( 'href', undef );
        }
        when ( 'form' ) {
            # loop round all Disableable Elements
            # and set their 'disabled' Attribute
            my @elements = $element->look_down( '_tag', qr/${disableable_elements}/ );
            $_->attr( 'disabled', 'disabled' )      foreach ( @elements );
        }
        default {
            $element->attr( 'disabled', 'disabled' );
        }
    }

    $logger->trace( "'${key}' disabled" );

    return;
}

# strip a URL from a Link or Form Action
sub _strip_url {
    my ( $self, $url ) = @_;

    return ''   if ( !defined $url );

    # Strip query string from URL and ensure single leading slash
    $url =~ s|/?(.*)\?.*|/$1|xms;

    return $url;
}

