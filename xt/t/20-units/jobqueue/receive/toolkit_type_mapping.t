#!/usr/bin/env perl

use NAP::policy "tt", 'test';

use Test::XTracker::Data;
use Test::XT::DC::JQ;
use Data::Dumper;

=head2 CANDO -1262

Testing options passed to generate PDF gets translated correctly to respective toolkit
type used. namely ( HTMLDoc or Webkit)


=cut
BEGIN {
    use_ok("XT::JQ::DC::Receive::Generate::PDF");
}

#--------------- Run TESTS ---------------

_test_symbol_translator();
_test_options_translator();


#--------------- END TESTS ---------------


done_testing;

#----------------------- Test Functions -----------------------

sub _test_options_translator {

    my $pdf_option = {
        'Input1'=> {
            page => {
                size => 'A4',
            },
            body_font => {
                face => 'Arial',
            },
            header => {
                centre => "HEADER TEXT",
                right  => 'XYZ',
            },
            footer => {
                centre => "FOOTER TEXT",
                right  => { symbol => 'PAGE_NUMBER'},
                left  => 'ABCD',
            },
         },
        'Input2' => {
            footer => {
                'NOT DEFINED' =>  "FOOTER TEXT",
                right  => { symbol => 'NOT DEFINED SYMBOL'} ,
                'INVALID'  => { symbol => 'PAGE_NUMBER' },
            },
         },
        'Input3' => {
            page => {
                size => 'a3',
                color => 'no mapping',
            },
            foterrr => {
                 centre => 'Spelt footer incorrectly',
            },
            centre => {
                'right' => { sybmm => 'spelt symbol incorrectly' },
            },
        },
    };



    my $expected = {
        'webkit' => {
            'Input1' => {
                page_size        => 'A4',
                'header-center'  => 'HEADER TEXT',
                'header-right'   => 'XYZ',
                'footer-center'  =>  'FOOTER TEXT',
                'footer-right'   => '[page]',
                'footer-left'    => 'ABCD',
            },
            'Input2' => {},
            'Input3' => {
                page_size => 'a3',
            }
        },
        'htmldoc' => {
            'Input1' => {
                'set_page_size' => 'A4',
                'set_bodyfont' => 'Arial',
            },
            'Input2' => {},
            'Input3' => {
                'set_page_size' => 'a3',
            },
        },
        'gibberish' => {
            'Input1' => undef,
            'Input2' => undef,
            'Input3' => undef,
        },
    };

    my $html->{content} = '<html>
<head> <title> TITLE TEXT </title></head>
body>
<p><font size=14pt><b>HTML to PDF Document</b></font></p>
<p>Let us see how this will work</p>
<table border=1>
<tr><td>This is a row in a table</td></tr>
<tr><td>This is another row</td></tr>
</table>
<HR>
May be footer text if needed
</body>
</html>
';



    note "***********  Testing _test_options_translator Method ";

    my $got = {};
    foreach my $toolkit ('webkit','htmldoc', 'gibberish') {
        # As reference to the html_content is passed
        my $html_1 = $html->{content};
        my $html_2 = $html->{content};
        my $html_3 = $html->{content};

        $got->{$toolkit}->{Input1} = XT::JQ::DC::Receive::Generate::PDF::_options_translator( $toolkit ,$pdf_option->{'Input1'},\$html_1);
        if( $toolkit eq 'htmldoc' ) {
            like( $html_1, qr/<!-- FOOTER LEFT "ABCD" -->/, "HTML CONTENT gets Appended for Input1:" . $toolkit );
            like( $html_1, qr/<!-- FOOTER RIGHT "\$CHAPTERPAGE\(1\)" -->/, "HTML CONTENT gets Appended for Input1:" . $toolkit );
        } else {
            unlike( $html_1, qr/<!-- FOOTER LEFT "ABCD" -->/, "HTML CONTENT Does NOT get Appended for Input1 :" . $toolkit );
        }
        $got->{$toolkit}->{Input2} = XT::JQ::DC::Receive::Generate::PDF::_options_translator( $toolkit ,$pdf_option->{'Input2'},\$html_2);
        unlike($html_2, qr/<!-- FOOTER LEFT "ABCD" -->/, "HTML CONTENT Does NOT Appended for  Input2:". $toolkit);

        $got->{$toolkit}->{Input3} = XT::JQ::DC::Receive::Generate::PDF::_options_translator( $toolkit ,$pdf_option->{'Input3'},\$html_3);
        unlike($html_3, qr/<!-- FOOTER LEFT "ABCD" -->/, "HTML CONTENT gets Appended for Input3 :". $toolkit);
    }

    is_deeply( $got, $expected, "_test_options_translator Method returns correct Data");

}

sub _test_symbol_translator {
    my $job = shift;

    my $expected = {
        'webkit' => {
            'PAGE_NUMBER' => '[page]',
            'junk'       => undef,
         },
        'htmldoc' => {
            'PAGE_NUMBER' => '$CHAPTERPAGE(1)',
            'junk'       => undef,
         },
        'gibberish' => {
            'PAGE_NUMBER' => undef,
            'junk'       => undef,
         },
    };

    note "***** Testing _symbol_translator Method ";
    my $got = {};
    foreach my $toolkit ('webkit','htmldoc', 'gibberish') {
        $got->{$toolkit}{'PAGE_NUMBER'} = XT::JQ::DC::Receive::Generate::PDF::_symbol_translator('PAGE_NUMBER',$toolkit);
        $got->{$toolkit}{'junk'} = XT::JQ::DC::Receive::Generate::PDF::_symbol_translator('junk',$toolkit);
    }

    is_deeply($got,$expected, "_symbol_translator Method returns Correct data");



}
