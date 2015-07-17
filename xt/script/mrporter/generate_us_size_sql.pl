#!/opt/xt/xt-perl/bin/perl
use warnings;
use strict;


make_sql (
    'M Shoes - FR full size',
    'Shoes',
    [40,    41,     42,     43,     44,     45,     46],
    [7,     8,      9,      10,     11,     12,     13] 
);
make_sql (
    'M Shoes - EU full size',
    'Shoes',
    [40,    41,     42,     43,     44,     45,     46],
    [7,     8,      9,      10,     11,     12,     13] 
);
make_sql (
    'M Shoes - EU half size',
    'Shoes',
    [39,39.5,40,40.5,41,41.5,42,42.5,43,43.5,44,44.5,45,45.5,46,46.5],
    [6,6.5,7,7.5,8,8.5,9,9.5,10,10.5,11,11.5,12,12.5,13,13.5] 
);
make_sql (
    'M Shoes - UK full size',
    'Shoes',
    [5,6,7,8,9,10,11,12,13],
    [5.5,6.5,7.5,8.5,9.5,10.5,11.5,12.5,13.5] 
);
make_sql (
    'M Shoes - UK half size',
    'Shoes',
    [5,5.5,6,6.5,7,7.5,8,8.5,9,9.5,10,10.5,11,11.5,12,12.5,13],
    [5.5,6,6.5,7,7.5,8,8.5,9,9.5,10,10.5,11,11.5,12,12.5,13,13.5] 
);
make_sql (
    'M Shirts EU',
    'Shirts',
    [37,38,39,40,41,42,43,44,45,46],
    [36,37,38,39,40,41,42,43,44,45]
);
make_sql (
    'M Shirts UK',
    'Shirts',
    [14,14.5,15,15.5,16,16.5,17,17.5,18,18.5],
    [36,37,38,39,40,41,42,43,44,45],
);
make_sql (
    'M Shirts UK sleeves size',
    'Shirts',
    ['14/33','14.5/33','15/33','15.5/33','16/33','16.5/33','17/33','17.5/33','18/33','18.5/33'],
    [36,37,38,39,40,41,42,43,44,45],
);
make_sql (
    'M Shirts UK sleeves size',
    'Shirts',
    ['14/34','14.5/34','15/34','15.5/34','16/34','16.5/34','17/34','17.5/34','18/34','18.5/34'],
    [36,37,38,39,40,41,42,43,44,45],
);
make_sql (
    'M Shirts UK sleeves size',
    'Shirts',
    ['14/35','14.5/35','15/35','15.5/35','16/35','16.5/35','17/35','17.5/35','18/35','18.5/35'],
    [36,37,38,39,40,41,42,43,44,45],
);
make_sql (
    'M Shirts 38R-44L',
    'Shirts',
    ['38R','38L','39R','39L','40R','40L','41R','41L','42R','42L','43R','43L','44R','44L','45R','45L'],
    [37,37,38,38,39,39,40,40,41,41,42,42,43,43,44,44],
);
make_sql (
    'M RTW - FRANCE',
    'Clothing',
    [46,48,50,52,54,56,58,60,62],
    [36,38,40,42,44,46,48,50,52] 
);
make_sql (
    'M RTW - ITALY',
    'Clothing',
    [46,48,50,52,54,56,58,60,62],
    [36,38,40,42,44,46,48,50,52] 
);
make_sql (
    'M RTW - UK',
    'Clothing',
    [36,38,40,42,44,46,48,50],
    [36,38,40,42,44,46,48,50] 
);


sub make_sql {
    my ($scheme_name, $group, $sizes, $us_names) = @_;
    die "wrong number of things for $scheme_name" unless (scalar @$sizes == scalar @$us_names);

    while (my $size = shift @$sizes) {
        my $us_name = shift @$us_names;

        print "
    INSERT INTO us_size_mapping (size_scheme_id, size_id, us_size_id)
        SELECT ss.id, ssvs.size_id, us.id
        FROM size_scheme ss, size_scheme_variant_size ssvs, size s, us_size us, std_group sg
        WHERE ss.id=ssvs.size_scheme_id AND ssvs.size_id=s.id and sg.id=us.std_group_id
        AND ss.name='$scheme_name' AND s.size='$size' AND us.name='$us_name' AND sg.name='$group'; 
    ";

    }

}
