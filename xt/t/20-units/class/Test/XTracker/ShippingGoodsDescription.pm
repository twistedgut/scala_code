package Test::XTracker::ShippingGoodsDescription;

use NAP::policy "tt", 'test';
use parent 'NAP::Test::Class';
use XTracker::ShippingGoodsDescription qw( description_of_goods );


sub startup : Test(startup) {
    my ( $self ) = @_;
    $self->SUPER::startup;
}


sub test_description_of_goods : Tests {
    my ( $self ) = @_;

    my $text_docs = 'Documents';
    my $text_normal = 'Not restricted for transport';
    my $text_hazmat = 'DG in LQ';
    my $hscodes = [ 123456, 123457, 123458, 123458 ];
    my $hstext = '123458x2, 123456, 123457';
    my $hstext_reduced = '123458x2, 123456';
    my $big_hscodes = [ 123001 .. 123024 ];
    my $delim = ', ';
    my $unlimited = 999;


    my $desc = description_of_goods({
                   docs_only => 1,
                   hazmat => 0,
                   line_len => $unlimited });
    is( $desc, $text_docs, 'documents only' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 1,
                   hazmat => 0,
                   line_len => $unlimited });
    is( $desc, $text_docs, 'documents only when HS codes passed' );


    $desc = description_of_goods({
                   docs_only => 0,
                   hazmat => 0,
                   line_len => $unlimited });
    is( $desc, $text_normal, 'normal shipment with no HS codes' );


    $desc = description_of_goods({
                   docs_only => 0,
                   hazmat => 1,
                   line_len => $unlimited });
    is( $desc, $text_hazmat, 'hazmat shipment with no HS codes' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => $unlimited });
    is( $desc, $text_normal . $delim . $hstext, 'normal shipment with HS codes' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 0,
                   hazmat => 1,
                   line_len => $unlimited });
    is( $desc, $text_hazmat . $delim . $hstext, 'hazmat shipment with HS codes' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => (length($hstext) * 2 ) + 6 });
    is( $desc, $text_normal . $delim . $hstext, 'normal shipment with HS codes limiting to allow only the codes' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => (length($hstext) * 2 ) + 5 });
    is( $desc, $text_normal . $delim . $hstext_reduced, 'normal shipment with HS codes limiting to allow only two codes' );


    $desc = description_of_goods({
                   hs_codes => $hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => 5});
    is( $desc, '', 'normal shipment with HS codes limiting length to allow nothing' );


    my @str = ( 'Not restricted for transport',
                '123001, 123002, 123003, 123004',
                '123005, 123006, 123007, 123008',
                '123009, 123010, 123011, 123012',
                '123013, 123014, 123015, 123016');
    my @desc = description_of_goods({
                   hs_codes => $big_hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => 34,
                   lines => 5 });
    is_deeply( \@desc, \@str, 'multiline output with description text on separate line' );


    @str = ( 'Not restricted for transport, 123001, 123002, 123003, 123004, 123005, 123006',
             '123007, 123008, 123009, 123010, 123011, 123012, 123013, 123014, 123015, 123016',
             '123017, 123018, 123019, 123020, 123021, 123022, 123023, 123024' );
    @desc = description_of_goods({
                   hs_codes => $big_hscodes,
                   docs_only => 0,
                   hazmat => 0,
                   line_len => 80,
                   lines => 3 });
    is_deeply( \@desc, \@str, 'multiline output with description text on line with codes' );
}
