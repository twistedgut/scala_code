package Test::XTracker::Markup;
use FindBin::libs;
use parent 'NAP::Test::Class';
use NAP::policy "tt", 'test';

use Test::XTracker::RunCondition dc => [ qw( DC1 DC2 ) ];


use Test::Exception;

use Test::XTracker::Data;
use XTracker::Markup;

sub create_data : Test(startup) {
    my $self = shift;

    $self->{schema} = Test::XTracker::Data->get_schema;

    # Start a transaction, so we can rollback after testing
    $self->{schema}->txn_begin;

    my $size = $self->{schema}->resultset('Public::Size')->search({
        size => 'One size'
    })->single;

    my $prod_type_id = $self->{schema}->resultset('Public::ProductType')->search({
        product_type => 'Bags'
    })->first->id;

    # A one size bag, so we can test measurements later (which only applies to bags)
    my @pids = Test::XTracker::Data->create_test_products({
        how_many => 2,
        designer_id => 2,
        sizes => [ $size ],
        product_type_id => $prod_type_id,
    });

    # Ordinary product
    $self->{product} = $pids[0];
    $self->{product_nl} = $pids[1];

    # Grab the designers
    $self->{designer} = $self->{product}->designer;
    $self->{designer_nl} = $self->{product_nl}->designer;

    # Non-live product
    $pids[1]->get_product_channel->update({
        live => 0,
        visible => 0,
        staging => 0,
    });

};

sub instantiate : Test(setup) {
    my $self = shift;

    $self->{markup} = XTracker::Markup->new({
        product_id => $self->{product}->id,
        schema => $self->{schema},
    });

    $self->{markup_nl} = XTracker::Markup->new({
        product_id => $self->{product_nl}->id,
        schema => $self->{schema},
    });

}

sub destroy : Test(teardown) {
    my $self = shift;

    $self->{markup} = undef;
    $self->{markup_nl} = undef;
}

sub rollback : Test(shutdown) {
    my $self = shift;

    # Don't really create all these new products
    $self->{schema}->txn_rollback;
}

sub editors_comments : Tests() {
    my $self = shift;

    lives_ok {
        $self->{markup}->editors_comments({ editors_comments => 2 })
    } 'lives with args';

    my $product_id    = $self->{product}->id;
    my $designer_name = $self->{designer}->designer;
    my $designer_url  = $self->{designer}->url_key;


    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => 'foo bar baz',
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/am/product/$product_id">product</a></li></ul>},
            site   => 'am',
        },
        {
            input  => "- foo - $designer_name - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => 'intl',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->editors_comments({
            editors_comments => $case->{input},
            site => $case->{site},
        });
        is( $output, $expected, "Output is $expected" );
    };
}

sub long_description : Tests() {
    my $self = shift;

    lives_ok {
        $self->{markup}->long_description({ long_description => 2 })
    } 'lives with args';

    my $product_id    = $self->{product}->id;
    my $designer_name = $self->{designer}->designer;
    my $designer_url  = $self->{designer}->url_key;

    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => 'foo bar baz',
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/am/product/$product_id">product</a></li></ul>},
            site   => 'am',
        },
        {
            input  => "- foo - $designer_name - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => 'intl',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->long_description({
            long_description => $case->{input},
            site => $case->{site},
        });
        is( $output, $expected, "Output is $expected" );
    };
}

sub size_fit : Tests() {
    my $self = shift;

    lives_ok {
        $self->{markup}->size_fit({ size_fit => 2 })
    } 'lives with args';

    my $product_id    = $self->{product}->id;
    my $designer_name = $self->{designer}->designer;
    my $designer_url  = $self->{designer}->url_key;

    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => '<ul>foo bar baz<li> Width 4" / 10cm<li> Height 4" / 10cm<li> Depth 4" / 10cm<li> Handle Drop 4" / 10cm<li> Min. Strap Length 4" / 10cm<li> Max. Strap Length 4" / 10cm</ul>',
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li> foo <li> bar <li> <a href="/product/$product_id">product</a><li> Width 4" / 10cm<li> Height 4" / 10cm<li> Depth 4" / 10cm<li> Handle Drop 4" / 10cm<li> Min. Strap Length 4" / 10cm<li> Max. Strap Length 4" / 10cm</ul>},
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li> foo <li> bar <li> <a href="/am/product/$product_id">product</a><li> Width 4" / 10cm<li> Height 4" / 10cm<li> Depth 4" / 10cm<li> Handle Drop 4" / 10cm<li> Min. Strap Length 4" / 10cm<li> Max. Strap Length 4" / 10cm</ul>},
            site   => 'am',
        },
        {
            input  => "- foo - $designer_name - bar - [ product id$product_id ]",
            output => qq{<ul><li> foo <li> $designer_name <li> bar <li> <a href="/product/$product_id">product</a><li> Width 4" / 10cm<li> Height 4" / 10cm<li> Depth 4" / 10cm<li> Handle Drop 4" / 10cm<li> Min. Strap Length 4" / 10cm<li> Max. Strap Length 4" / 10cm</ul>},
            site   => 'intl',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->size_fit({
            size_fit => $case->{input},
            site => $case->{site},
        });
        is( $output, $expected, "Output is $expected" );
    };
}

sub related_facts : Tests() {
    my $self = shift;

    lives_ok {
        $self->{markup}->related_facts({ related_facts => 2 })
    } 'lives with args';

    my $product_id    = $self->{product}->id;
    my $designer_name = $self->{designer}->designer;
    my $designer_url  = $self->{designer}->url_key;

    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => 'foo bar baz',
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => '',
        },
        {
            input  => "- foo - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - bar - <a href="/am/product/$product_id">product</a></li></ul>},
            site   => 'am',
        },
        {
            input  => "- foo - $designer_name - bar - [ product id$product_id ]",
            output => qq{<ul><li>foo - <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> - bar - <a href="/product/$product_id">product</a></li></ul>},
            site   => 'intl',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->related_facts({
            related_facts => $case->{input},
            site => $case->{site},
        });
        is( $output, $expected, "Output is $expected" );
    };
}

sub _add_lists : Tests() {
    my $self = shift;

    lives_ok { $self->{markup}->_add_lists() } 'lives without args';

    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => "foo bar baz\n",
        },
        {
            input  => "- foo\n- bar\n- baz",
            output => "<ul>\n<li>foo</li>\n<li>bar</li>\n<li>baz</li>\n</ul>\n",
        },
        {
            input  => "- foo\n- bar\n- baz\nqux",
            output => "<ul>\n<li>foo</li>\n<li>bar</li>\n<li>baz</li>\n</ul>\nqux\n",
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->_add_lists({text=>$case->{input}});
        is( $output, $expected, "Output is $expected" );
    };

}

sub _add_list_elements : Tests() {
    my $self = shift;

    lives_ok { $self->{markup}->_add_list_elements() } 'lives without args';

    my $test_cases = [
        {
            input  => '- foo - bar - baz',
            output => '<li> foo <li> bar <li> baz',
        },
        {
            input  => 'foo bar baz',
            output => 'foo bar baz',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->_add_list_elements({text=>$case->{input}});
        is( $output, $expected, "Output is $expected" );
    };

}

sub _add_product_links : Tests() {
    my $self = shift;

    lives_ok { $self->{markup}->_add_product_links() } 'lives wihout args';

    my $product_id    = $self->{product}->id;
    my $product_nl_id = $self->{product_nl}->id;
    my $designer_name = $self->{designer}->designer;
    my $designer_nl_name = $self->{designer_nl}->designer;
    my $designer_nl_url  = $self->{designer_nl}->url_key;

    my $test_cases = [
       {
            input  => '<br>foo bar baz</table>',
            output => '',
            product_id => $product_id,
            instance => 'markup',
        },
        {
            input  => "foo bar [ pid id$product_id ] baz",
            output => qq{foo bar <a href="/product/$product_id">pid</a> baz},
            product_id => $product_id,
            instance => 'markup',
        },
        {
            input  => "[ amazing_link_text id$product_id ]",
            output => qq{<a href="/product/$product_id">amazing_link_text</a>},
            product_id => $product_id,
            instance => 'markup',
        },
        {
            input  => "[ amazing link text id$product_id ]",
            output => qq{<a href="/product/$product_id">amazing link text</a>},
            product_id => $product_id,
            instance => 'markup',
        },
        {
            input  => "[Moschino jacket id166174166174]",
            output => "[Moschino jacket id166174166174]",
            product_id => $product_id,
            instance => 'markup',
        },
        {
            input  => "[ non-live id$product_nl_id ]",
            output => qq{<a href="javascript:ri('$designer_nl_name', '$product_nl_id');">non-live</a>},
            product_id => $product_nl_id,
            instance => 'markup_nl',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{$case->{instance}}->_add_product_links({
            text => $case->{input},
        });
        is( $output, $expected, "Output is $expected" );
    };}

sub _add_designer_links : Tests() {
    my $self = shift;

    dies_ok { $self->{markup}->_add_desinger_links() } 'dies without args';

    my $designer_name = $self->{designer}->designer;
    my $designer_url  = $self->{designer}->url_key;

    my $test_cases = [
        {
            input  => "foo bar $designer_name baz",
            output => qq{foo bar <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> baz},
        },
        {
            input  => "foo $designer_name bar $designer_name [$designer_name] baz [$designer_name] [ $designer_name ] $designer_name foo",
            output => qq{foo <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> bar <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> [$designer_name] baz [$designer_name] [ $designer_name ] <a class="editor-designer" href="/Shop/Designers/$designer_url">$designer_name</a> foo},
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->_add_designer_links({
            text => $case->{input},
        });
        is( $output, $expected, "Output is $expected" );
    };

}

sub _substitute_impromptu_bullet_points : Tests() {
    my $self = shift;

    lives_ok { $self->{markup}->_substitute_impromptu_bullet_points() }
        'lives with args';

    my $test_cases = [
        {
            input  => '- foo - bar - baz',
            output => '- foo - bar - baz',
        },
        {
            input  => '(- foo - bar - baz -)',
            output => '<ul><li> foo - bar - baz </li></ul>',
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->_substitute_impromptu_bullet_points({
            text => $case->{input}
        });
        is( $output, $expected, "Output is $expected" );
    };

}

sub _add_measurements : Tests() {
    my $self = shift;

    lives_ok { $self->{markup}->_add_measurements() } 'lives without args';

    my $test_cases = [
        {
            input  => 'foo bar baz',
            output => qq{foo bar baz<li> Width 4" / 10cm<li> Height 4" / 10cm<li> Depth 4" / 10cm<li> Handle Drop 4" / 10cm<li> Min. Strap Length 4" / 10cm<li> Max. Strap Length 4" / 10cm},
        },
    ];

    for my $case (@$test_cases) {
        my $expected = $case->{output};
        my $output = $self->{markup}->_add_measurements({
            text => $case->{input},
        });
        is( $output, $expected, "Output is $expected" );
    };
}

1;
