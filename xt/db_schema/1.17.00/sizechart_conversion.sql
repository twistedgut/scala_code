BEGIN;
    -- fix up shonky values
    update variant_measurement set value = replace(value, '`', '');
    update variant_measurement set value = replace(value, '-', '');
    update variant_measurement set value = replace(value, ' ', '');
    update variant_measurement set value = replace(value, '..', '.');
    update variant_measurement set value = replace(value, ',', '.');
    update variant_measurement set value = 8.5 where value = '.8.5';
    update variant_measurement set value = 25.5 where value = '.25.5';
    update variant_measurement set value = 0.5 where value like '.5%';

    -- ERROR:  invalid input syntax for type numeric: ""
    update variant_measurement set value = 0 where value = '';

    -- fix "xx/yy" values
    update variant_measurement set value = regexp_replace(value, E'/\\d*', '')
        where value ~ E'\\d+/\\d+';

    -- ERROR:  invalid input syntax for type numeric: "3.5.5"
    update variant_measurement set value = '-1' where value = '3.5.5';
    -- ERROR:  invalid input syntax for type numeric: "5.5.5"
    update variant_measurement set value = '-2' where value = '5.5.5';
    -- ERROR:  invalid input syntax for type numeric: "22.5Skirt/19.5Top"
    update variant_measurement set value = '22.5' where value = '22.5Skirt/19.5Top';
    -- ERROR:  invalid input syntax for type numeric: "41jacket/27skirt"
    update variant_measurement set value = '41' where value = '41jacket/27skirt';
    -- ERROR:  invalid input syntax for type numeric: "40jacket/26skirt"
    update variant_measurement set value = '40' where value = '40jacket/26skirt';
    -- ERROR:  invalid input syntax for type numeric: "42jacket/28skirt"
    update variant_measurement set value = '42' where value = '42jacket/28skirt';
    -- ERROR:  invalid input syntax for type numeric: "38jacket/25skirt"
    update variant_measurement set value = '38' where value = '38jacket/25skirt';

    -- convert inches to centimetres for product measurements
    update variant_measurement
        set value = round(cast(value as decimal) * 2.54, 0)
        where value != '' and value not like '% %'
    ;
COMMIT;
