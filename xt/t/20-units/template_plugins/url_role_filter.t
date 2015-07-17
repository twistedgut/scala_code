#!/opt/xt/xt-perl/bin/perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XTracker::Data::AccessControls;

use HTML::TreeBuilder;

use_ok( 'NAP::Template::Plugin::URLRoleFilter' );


my $schema = Test::XTracker::Data->get_schema;
$schema->txn_begin;

# get an example HTML that is in the __DATA__
# section at the bottom of this script
my $example_html_from_DATA = do { local $/; <DATA> };

note "Test that when asked NOT to Restrict anything the Filter DIEs";
throws_ok {
        my $filter = NAP::Template::Plugin::URLRoleFilter->new;
        $filter->filter( '<span></span>', [ _get_acl_with_roles() ] );
    }
    qr/wasn't asked to restrict anything/i,
    "When asked to Restrict nothing the Filter DIEs"
;
throws_ok {
        my $filter = NAP::Template::Plugin::URLRoleFilter->new;
        $filter->filter( '<span></span>', [ _get_acl_with_roles() ], {
            # 'restrict_classes' doesn't mean anything to the Filter
            restrict_classes => {
                aclprotect_data => [ qw( app_can_see_some_stuff ) ],
            },
        } );
    }
    qr/don't know how to restrict '.*'/i,
    "When asked to Restrict using an unknown Category then the Filter DIEs"
;

my %tests = (
    "<li> not removed with full role set" => {
        html    => <<EOF,
    <ul>
        <li><a href="/Restricted/Link">Secret Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_can_see_secrets app_this_also_works ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<li> TAG still present" => { look_for => [ '_tag', 'li' ], count => 1 },
        },
    },
    "<li> removed without roles" => {
        html    => <<EOF,
    <ul>
        <li><a href="/Restricted/Link">Secret Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<li> TAG not present" => { look_for => [ '_tag', 'li' ], count => 0 },
            "<ul> parent TAG not present either because it's now empty" => { look_for => [ '_tag', 'ul' ], count => 0 },
        },
    },
    "<li> removed without roles but '<ul>' still present as list is not empty" => {
        html    => <<EOF,
    <ul>
        <li><a href="/Restricted/Link">Secret Things</a></li>
        <li><a href="/Pulbic/Link">Public Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<li> only one TAG present"     => { look_for => [ '_tag', 'li' ], count => 1 },
            "<ul> parent TAG still present" => { look_for => [ '_tag', 'ul' ], count => 1 },
        },
    },
    "<li> not removed when haven't been asked to" => {
        html    => <<EOF,
    <ul>
        <li><a href="/Restricted/Link">Secret Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( form ) ],
        },
        expect => {
            "<li> TAG still present" => { look_for => [ '_tag', 'li' ], count => 1 },
        },
    },
    "<li> removed without roles and the URL has a Query String part" => {
        html    => <<EOF,
    <ul>
        <li><a href="/Restricted/Link?foo=bar">Secret Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<li> TAG not present"                                      => { look_for => [ '_tag', 'li' ], count => 0 },
            "<ul> parent TAG not present either because it's now empty" => { look_for => [ '_tag', 'ul' ], count => 0 },
        },
    },
    "with multiple <ul> tags the only the empty one is removed" => {
        html    => <<EOF,
    <ul>
        <li><a class="keep" href="/Link/To/Secrets">Secret Things</a></li>
    </ul>
    <ul>
        <li><a class="remove" href="/Restricted/Link?foo=bar">Secret Things</a></li>
    </ul>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Link/To/Somewhere ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_can_see_secrets ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "One <li> TAG present" => { look_for => [ '_tag', 'li' ],    count => 1 },
            "One <ul> TAG present" => { look_for => [ '_tag', 'ul' ],    count => 1 },
            "One <a> TAG present"  => { look_for => [ 'class', 'keep' ], count => 1 },
        },
    },
    "<a> removed without roles but NOT its parent as that isn't an <li> tag" => {
        html    => <<EOF,
    <span>please click to see <a href="/Restricted/Link?foo=bar">Secret Things</a></span>
EOF
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<a> TAG has been removed"        => { look_for => [ '_tag', 'a' ],    count => 0 },
            "<span> parent TAG still present" => { look_for => [ '_tag', 'span' ], count => 1 },
        },
    },
    "<a> removed ok when it's the only tag and has no parent" => {
        html => '<a href="/Restricted/Link?foo=bar">Secret Things</a>',
        role_to_url_map => {
            app_can_see_secrets => [ qw( /Restricted/Link ) ],
            app_this_also_works => [ qw( /Restricted/Link ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<a> TAG has been removed" => { look_for => [ '_tag', 'a' ], count => 0 },
        },
    },
    "<form> with restricted action URL is not removed with Roles" => {
        html => <<EOF,
    <form name="secret_form" action="/Restricted/Action" method="post">
        <input type="submit" class="linkbutton" value="Do Something"></input>
    </form>
EOF
        role_to_url_map => {
            app_can_submit_form => [ qw( /Restricted/Action ) ],
        },
        roles_for_operator  => [ qw( app_can_submit_form ) ],
        restrictions        => {
            restrict_url => [ qw( form ) ],
        },
        expect => {
            "<form> TAG still present" => { look_for => [ '_tag', 'form' ], count => 1 },
        },
    },
    "<form> with restricted action URL is removed without Roles" => {
        html => <<EOF,
    <form name="secret_form" action="/Restricted/Action" method="post">
        <input type="submit" class="linkbutton" value="Do Something"></input>
    </form>
EOF
        role_to_url_map => {
            app_can_submit_form => [ qw( /Restricted/Action ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( form ) ],
        },
        expect => {
            "<form> TAG not present" => { look_for => [ '_tag', 'form' ], count => 0 },
        },
    },
    "<form> with restricted action URL is not removed when hasn't been asked to" => {
        html => <<EOF,
    <form name="secret_form" action="/Restricted/Action" method="post">
        <input type="submit" class="linkbutton" value="Do Something"></input>
    </form>
EOF
        role_to_url_map => {
            app_can_submit_form => [ qw( /Restricted/Action ) ],
        },
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<form> TAG still present" => { look_for => [ '_tag', 'form' ], count => 1 },
        },
    },
    "CSS Class is removed with required roles present" => {
        html => <<EOF,
    <div class="sensative_data">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_can_see_stuff ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG still present" => { look_for => [ '_tag', 'div' ], count => 1 },
        },
    },
    "CSS Class is removed when required roles are not present" => {
        html => <<EOF,
    <div class="sensative_data">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG not present"             => { look_for => [ '_tag', 'div' ],  count => 0 },
            "<span> child TAG also not present" => { look_for => [ '_tag', 'span' ], count => 0 },
        },
    },
    "CSS Class not removed when is hasn't been asked to be" => {
        html => <<EOF,
    <div class="sensative_data">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_url => [ qw( form link ) ],
        },
        expect => {
            "<div> TAG still present" => { look_for => [ '_tag', 'div' ], count => 1 },
        },
    },
    "CSS Class is removed when the class name is the first in the class attribute" => {
        html => <<EOF,
    <div class="sensative_data css_class">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG not present"             => { look_for => [ '_tag', 'div' ],  count => 0 },
            "<span> child TAG also not present" => { look_for => [ '_tag', 'span' ], count => 0 },
        },
    },
    "CSS Class is removed when the class name is in the middle in the class attribute" => {
        html => <<EOF,
    <div class="bold sensative_data css_class">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG not present"             => { look_for => [ '_tag', 'div' ],  count => 0 },
            "<span> child TAG also not present" => { look_for => [ '_tag', 'span' ], count => 0 },
        },
    },
    "CSS Class is removed when the class name is at the end of the class attribute" => {
        html => <<EOF,
    <div class="bold sensative_data">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG not present"             => { look_for => [ '_tag', 'div' ],  count => 0 },
            "<span> child TAG also not present" => { look_for => [ '_tag', 'span' ], count => 0 },
        },
    },
    "CSS Class not removed when the restricted class name just happens to match the beginning of a class name used" => {
        html => <<EOF,
    <div class="sensative_data_bold">
        <span>Credit Card Number: 1231313</span>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_role ) ],
        restrictions        => {
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG still present" => { look_for => [ '_tag', 'div' ], count => 1 },
        },
    },
    "Empty a CSS Class by setting the 'default_action' to 'empty'" => {
        html => <<EOF,
    <div class="sensative_data">
        Credit Card Number: <span class="sensative_cc_number">1231313</span>
        <div class="personal_details">
            DOB: <span>01/01/2000</span>
        </div>
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_roll ) ],
        restrictions        => {
            default_action => 'empty',
            restrict_class => {
                sensative_cc_number => [ qw( app_can_see_stuff ) ],
                personal_details    => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAGs still present"                   => { look_for => [ '_tag', 'div' ],  count => 2 },
            "only one <span> TAG should be found"        => { look_for => [ '_tag', 'span' ], count => 1 },
            "<span> TAG with class name should be found" => { look_for => [ 'class', 'sensative_cc_number' ], count => 1, content => qr/^$/ },
            "<div> TAG with class name should be found"  => { look_for => [ 'class', 'personal_details' ],    count => 1, content => qr/^$/ },
        },
    },
    "Disable a Link by setting the 'default_action' to 'disable'" => {
        html => <<EOF,
    <div class="sensative_data">
        <a href="/Some/URL">click to see stuff</a>
    </div>
EOF
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
        },
        roles_for_operator  => [ qw( app_useless_roll ) ],
        restrictions        => {
            default_action => 'disable',
            restrict_url => [ qw( link ) ],
        },
        expect => {
            "<div> TAG still present"                 => { look_for => [ '_tag', 'div' ],  count => 1 },
            "<a> TAG should be found"                 => { look_for => [ '_tag', 'a' ],    count => 1 },
            "<a> TAG with 'href' should not be found" => { look_for => [ 'href', qr/.*/ ], count => 0 },
        },
    },
    "Disable a Form by setting the 'default_action' to 'disable'" => {
        html => <<EOF,
    <div>
        <input name="thing1" type="text" value="shouldn't be disabled" />
        <form action="/Some/URL">
            <fieldset>
                DOB <input type="text" name="dob" value="" />
            </fieldset>
            <input type="text" name="name" value="" />
            <textarea name="message"></textarea>
            <select name="item">
                <optgroup label="items">
                    <option value="1">Item 1</option>
                </optgroup>
                <option value="2">Item 2</option>
            </select>
            <button type="submit" name="submit">Submit Form</button>
        </form>
        <input name="thing2" type="text" value="shouldn't be disabled either" />
    </div>
EOF
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
        },
        roles_for_operator  => [ qw( app_useless_roll ) ],
        restrictions        => {
            default_action => 'disable',
            restrict_url => [ qw( form ) ],
        },
        expect => {
            "<form> TAG still present"        => { look_for => [ '_tag', 'form' ],     count => 1 },
            "should be 9 disabled tags found" => { look_for => [ 'disabled', qr/.*/ ], count => 9 },
        },
    },
    "Disable a Form & Link by using specific Class Names and setting the 'default_action' to 'disable'" => {
        html => <<EOF,
    <div>
        <form action="/Some/URL">
            <input name="thing1" type="text" value="shouldn't be disabled" />
            <input name="thing2" type="text" value="shouldn't be disabled either" />
        </form>
        <form class="aclprotect_data" action="/Some/URL">
            <fieldset>
                DOB <input type="text" name="dob" value="" />
            </fieldset>
            <input type="text" name="name" value="" />
            <textarea name="message"></textarea>
            <select name="item">
                <optgroup label="items">
                    <option value="1">Item 1</option>
                </optgroup>
                <option value="2">Item 2</option>
            </select>
            <button type="submit" name="submit">Submit Form</button>
        </form>
        <a href="/Some/Other/URL">shouldn't be disabled</a>
        <a class="aclprotect_more_data" href="/Some/Other/URL">should be disabled</a>
    </div>
EOF
        role_to_url_map => {
            # because we are not restricting by 'url' these should be
            # ignored even though the Operator has the required Role
            app_role1 => [ qw( /Some/URL /Some/Other/URL ) ],
        },
        roles_for_operator  => [ qw( app_role1 ) ],
        restrictions        => {
            default_action => 'disable',
            restrict_class => {
                aclprotect_data      => [ qw( app_role2 ) ],
                aclprotect_more_data => [ qw( app_role3 ) ],
            },
        },
        expect => {
            "<form> TAGs still present"            => { look_for => [ '_tag', 'form' ],     count => 2 },
            "should be 9 disabled tags found"      => { look_for => [ 'disabled', qr/.*/ ], count => 9 },
            "should be 2 <a> tags found"           => { look_for => [ '_tag', 'a' ],        count => 2 },
            "only 1 <a> tag should have an 'href'" => { look_for => [ 'href', qr/.*/ ],     count => 1 },
        },
    },
    "Disable a TAG by Class Name and by setting the 'default_action' to 'disable'" => {
        html => <<EOF,
    <div>
        CC Number: <input type="text" class="sensative_data" value="234324234" />
    </div>
EOF
        roles_for_operator  => [ qw( app_useless_roll ) ],
        restrictions        => {
            default_action => 'disable',
            restrict_class => {
                sensative_data => [ qw( app_can_see_stuff ) ],
            },
        },
        expect => {
            "<div> TAG still present"        => { look_for => [ '_tag', 'div' ],      count => 1 },
            "should be a disabled tag found" => { look_for => [ 'disabled', qr/.*/ ], count => 1 },
        },
    },
    "Removing various TAGs" => {
        html => $example_html_from_DATA,
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role3 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_role1 app_role2 ) ],
        restrictions => {
            restrict_url   => [ qw( form link ) ],
            restrict_class => {
                aclprotect_data => [ qw( app_role3 ) ],
            },
        },
        expect => {
            "<ul> tag has been removed"     => { look_for => [ '_tag', 'ul' ],   count => 0 },
            "<p> tag has have been removed" => { look_for => [ '_tag', 'p' ],    count => 2 },
            "<form> tag still present"      => { look_for => [ '_tag', 'form' ], count => 1 },
        },
    },
    "Removing more various TAGs" => {
        html => $example_html_from_DATA,
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role3 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_role3 app_role2 ) ],
        restrictions => {
            restrict_url   => [ qw( form link ) ],
            restrict_class => {
                aclprotect_data      => [ qw( app_role3 ) ],
                aclprotect_more_data => [ qw( app_role1 ) ],
            },
        },
        expect => {
            "<ul> tag has not been removed"    => { look_for => [ '_tag', 'ul' ],   count => 1 },
            "<p> tag has have been removed"    => { look_for => [ '_tag', 'p' ],    count => 2 },
            "<form> tag has also been removed" => { look_for => [ '_tag', 'form' ], count => 0 },
        },
    },
    "Restrict a TAG by 'class' which the Operator can't see which contains other TAGs that the Operator can see" => {
        html => $example_html_from_DATA,
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_role1 app_role2 ) ],
        restrictions => {
            restrict_url   => [ qw( form link ) ],
            restrict_class => {
                aclprotect_data      => [ qw( app_role1 ) ],
                aclprotect_more_data => [ qw( app_role2 ) ],
                aclprotect_everything=> [ qw( app_rolex ) ],
            },
        },
        expect => {
            "<ul> tag has been removed"   => { look_for => [ '_tag', 'ul' ],   count => 0 },
            "<p> tag has been removed"    => { look_for => [ '_tag', 'p' ],    count => 0 },
            "<form> tag has been removed" => { look_for => [ '_tag', 'form' ], count => 0 },
            "<div> tag has been removed"  => { look_for => [ '_tag', 'div' ],  count => 0 },
        },
    },
    "Override default 'remove' action by Disabling Forms and Emptying one of the Classes" => {
        html => $example_html_from_DATA,
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_useless_role ) ],
        restrictions => {
            restrict_url   => [
                [ 'form', 'disable' ],
                'link',
            ],
            restrict_class => {
                aclprotect_data      => { roles => [ qw( app_role1 ) ], action => 'empty' },
                aclprotect_more_data => [ qw( app_role2 ) ],
            },
        },
        expect => {
            "<ul> tag has been removed"          => { look_for => [ '_tag', 'ul' ],               count => 0 },
            "should be 2 <p> tags remaining"     => { look_for => [ '_tag', 'p' ],                count => 2 },
            "should be 1 <input> tag remaining"  => { look_for => [ '_tag', 'input' ],            count => 1 },
            "should be 1 <button> tag remaining" => { look_for => [ '_tag', 'button' ],           count => 1 },
            "one <p> tag should be empty"        => { look_for => [ 'class', 'aclprotect_data' ], count => 1, content => qr/^$/ },
            "should be 2 disable TAGs"           => { look_for => [ 'disabled', 'disabled' ],     count => 2 },
        },
    },
    "Set default action to be 'disable' but override to remove Forms and a Class" => {
        html => $example_html_from_DATA,
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_useless_role ) ],
        restrictions => {
            default_action => 'disable',
            restrict_url   => [
                [ 'form', 'remove' ],
                'link',
            ],
            restrict_class => {
                aclprotect_data      => { roles => [ qw( app_role1 ) ], action => 'remove' },
                aclprotect_more_data => [ qw( app_role2 ) ],
            },
        },
        expect => {
            "<ul> tag should be still present"       => { look_for => [ '_tag', 'ul' ],               count => 1 },
            "should be 2 <p> tags remaining"         => { look_for => [ '_tag', 'p' ],                count => 2 },
            "should be an <a> tag present"           => { look_for => [ '_tag', 'a' ],                count => 1 },
            "should be no <a> tag with 'href'"       => { look_for => [ 'href', qr/.*/ ],             count => 0 },
            "one <p> tag should be disabled"         => { look_for => [ 'disabled', 'disabled' ],     count => 1, content => qr/Bank Account/ },
            "<p> tag with class shound't be present" => { look_for => [ 'class', 'aclprotect_data' ], count => 0 },
        },
    },
    "Remove Sidenav Headings when all of their Options are Removed" => {
        html => <<EOF,
<ul>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><span>Heading 1</span></li>
    <li><a href="/Some/Link">Some Link</a></li>
    <li><span>Heading 2</span></li>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
    <li><span>Heading 3</span></li>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Unprotected/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
</ul>
EOF
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_useless_role ) ],
        restrictions => {
            restrict_url   => [ 'sidenav' ],
        },
        expect => {
            "<ul> tag should be still present"  => { look_for => [ '_tag', 'ul' ],   count => 1 },
            "should be 4 <li> tags remaining"   => { look_for => [ '_tag', 'li' ],   count => 4 },
            "should be 2 <span> tags remaining" => { look_for => [ '_tag', 'span' ], count => 2 },
        },
    },
    "Protect Sidenav without any Headings" => {
        html => <<EOF,
<ul>
    <li><a href="/Some/Link">Some Link</a></li>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Unprotected/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
</ul>
EOF
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_useless_role ) ],
        restrictions => {
            restrict_url   => [ 'sidenav' ],
        },
        expect => {
            "<ul> tag should be still present" => { look_for => [ '_tag', 'ul' ], count => 1 },
            "should be 2 <li> tags remaining"  => { look_for => [ '_tag', 'li' ], count => 2 },
        },
    },
    "Protect Sidenav when all Options should be Protected which should Remove everything" => {
        html => <<EOF,
<ul>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
    <li><a href="/Some/URL">Some Link</a></li>
    <li><a href="/Some/Other/URL">Some Link</a></li>
</ul>
EOF
        role_to_url_map => {
            app_role1 => [ qw( /Some/URL ) ],
            app_role2 => [ qw( /Some/Other/URL ) ],
        },
        roles_for_operator => [ qw( app_useless_role ) ],
        restrictions => {
            restrict_url   => [ 'sidenav' ],
        },
        expect => {
            "<ul> tag should have been removed" => { look_for => [ '_tag', 'ul' ], count => 0 },
            "should be 0 <li> tags remaining"   => { look_for => [ '_tag', 'li' ], count => 0 },
        },
    },
);

my $filter_plugin = NAP::Template::Plugin::URLRoleFilter->new;

foreach my $label ( keys %tests ) {
    note "Testing: ${label}";
    my $test    = $tests{ $label };
    my $expect  = $test->{expect};

    if ( my $role_url_map = $test->{role_to_url_map} ) {
        Test::XTracker::Data::AccessControls->set_url_path_roles( $role_url_map );
    }

    my $acl     = _get_acl_with_roles( $test->{roles_for_operator} );
    my $output  = $filter_plugin->filter(
        $test->{html},
        [ $acl ],
        $test->{restrictions},
    );
    my $tree    = HTML::TreeBuilder->new_from_content( $output );

    foreach my $check_msg ( keys %{ $expect } ) {
        my $check   = $expect->{ $check_msg };
        my @got     = $tree->look_down( @{ $check->{look_for} } );
        cmp_ok( @got, '==', $check->{count}, $check_msg )       if ( exists $check->{count} );
        like( $got[0]->as_trimmed_text, qr/$check->{content}/, $check_msg . ' with expected content' )
                                                                if ( exists $check->{content} );
    }
}


$schema->txn_rollback;

done_testing;

#------------------------------------------------------------------------

sub _get_acl_with_roles {
    my $roles = shift;

    return Test::XTracker::Data::AccessControls->get_acl_obj( {
        roles => $roles,
    } );
}

__DATA__
<div class="aclprotect_everything">
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
</div>
