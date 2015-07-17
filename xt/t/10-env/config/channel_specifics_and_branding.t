#!/usr/bin/env perl

use NAP::policy "tt", 'test';
use FindBin::libs;

=head2 Tests that Sales Channel Branding and other Channel Specific Details are Correct

This test will check that the Sales Channel branding has the correct values. It will also check other Channel specific details such as some email addresses and Contact Hours and Premier Phone Numbers.

Please add more as you see fit.


Originally done for CANDO-345.

=cut

use Data::Dump qw( pp );


use Test::XTracker::Data;
use Test::XTracker::RunCondition    export => [ qw( $distribution_centre ) ];

use XTracker::Constants::FromDB     qw(
                                        :branding
                                    );
use XTracker::Config::Local         qw(
                                        config_var
                                    );
use XTracker::EmailFunctions        qw( localised_email_address );


my $schema  = Test::XTracker::Data->get_schema();
isa_ok( $schema, 'XTracker::Schema', 'Schema sanity check' );

# set-up the expected Branding for each Sales
# Channel, currently it's the same for each
# DC, but this could change in the future
my %expected_branding   = (
        DC1 => {
            'NAP'   => {
                $BRANDING__PF_NAME  => 'NET-A-PORTER.COM',
                $BRANDING__DOC_HEADING  => 'NET-A-PORTER.COM',
                $BRANDING__PREM_NAME  => 'NET-A-PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Kind regards',
                $BRANDING__PLAIN_NAME => 'NET-A-PORTER',
                $BRANDING__SMS_SENDER_ID => 'NETAPORTER',
            },
            'OUTNET'=> {
                $BRANDING__PF_NAME  => 'theOutnet.com',
                $BRANDING__DOC_HEADING  => 'theOutnet.com',
                $BRANDING__EMAIL_SIGNOFF => 'Kind regards',
                $BRANDING__PLAIN_NAME => 'THE OUTNET',
                $BRANDING__SMS_SENDER_ID => 'THEOUTNET',
                $BRANDING__PREM_NAME  => 'THE OUTNET Premier',
            },
            'MRP'   => {
                $BRANDING__PF_NAME  => 'MRPORTER.COM',
                $BRANDING__DOC_HEADING  => 'MRPORTER.COM',
                $BRANDING__PREM_NAME  => 'MR PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Yours sincerely',
                $BRANDING__PLAIN_NAME => 'MR PORTER',
                $BRANDING__SMS_SENDER_ID => 'MRPORTER',
            },
            'JC'    => {
                $BRANDING__PF_NAME  => 'JIMMYCHOO.COM',
                $BRANDING__DOC_HEADING  => 'J.CHOO (OS) Limited',
                $BRANDING__PLAIN_NAME => 'JIMMY CHOO',
                $BRANDING__SMS_SENDER_ID => 'JIMMYCHOO',
                $BRANDING__PREM_NAME  => 'London Premier',
            },
        },
        DC2 => {
            'NAP'   => {
                $BRANDING__PF_NAME  => 'NET-A-PORTER.COM',
                $BRANDING__DOC_HEADING  => 'NET-A-PORTER.COM',
                $BRANDING__PREM_NAME  => 'NET-A-PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Best regards',
                $BRANDING__PLAIN_NAME => 'NET-A-PORTER',
                $BRANDING__SMS_SENDER_ID => 'NETAPORTER',
            },
            'OUTNET'=> {
                $BRANDING__PF_NAME  => 'theOutnet.com',
                $BRANDING__DOC_HEADING  => 'theOutnet.com',
                $BRANDING__EMAIL_SIGNOFF => 'Kind regards',
                $BRANDING__PLAIN_NAME => 'THE OUTNET',
                $BRANDING__SMS_SENDER_ID => 'THEOUTNET',
                $BRANDING__PREM_NAME  => 'THE OUTNET Premier',
            },
            'MRP'   => {
                $BRANDING__PF_NAME  => 'MRPORTER.COM',
                $BRANDING__DOC_HEADING  => 'MRPORTER.COM',
                $BRANDING__PREM_NAME  => 'MR PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Yours sincerely',
                $BRANDING__PLAIN_NAME => 'MR PORTER',
                $BRANDING__SMS_SENDER_ID => 'MRPORTER',
            },
            'JC'    => {
                $BRANDING__PF_NAME  => 'JIMMYCHOO.COM',
                $BRANDING__DOC_HEADING  => 'J.CHOO (OS) Limited',
                $BRANDING__PLAIN_NAME => 'JIMMY CHOO',
                $BRANDING__SMS_SENDER_ID => 'JIMMYCHOO',
                $BRANDING__PREM_NAME  => 'New York Premier',
            },
        },
        DC3 => {
            'NAP'   => {
                $BRANDING__PF_NAME  => 'NET-A-PORTER.COM',
                $BRANDING__DOC_HEADING  => 'NET-A-PORTER.COM',
                $BRANDING__PREM_NAME  => 'NET-A-PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Best regards',
                $BRANDING__PLAIN_NAME => 'NET-A-PORTER',
                $BRANDING__SMS_SENDER_ID => 'NETAPORTER',
            },
            'OUTNET'=> {
                $BRANDING__PF_NAME  => 'theOutnet.com',
                $BRANDING__DOC_HEADING  => 'theOutnet.com',
                $BRANDING__EMAIL_SIGNOFF => 'Kind regards',
                $BRANDING__PLAIN_NAME => 'THE OUTNET',
                $BRANDING__SMS_SENDER_ID => 'THEOUTNET',
                $BRANDING__PREM_NAME  => 'THE OUTNET Premier',
            },
            'MRP'   => {
                $BRANDING__PF_NAME  => 'MRPORTER.COM',
                $BRANDING__DOC_HEADING  => 'MRPORTER.COM',
                $BRANDING__PREM_NAME  => 'MR PORTER Premier',
                $BRANDING__EMAIL_SIGNOFF => 'Yours sincerely',
                $BRANDING__PLAIN_NAME => 'MR PORTER',
                $BRANDING__SMS_SENDER_ID => 'MRPORTER',
            },
            'JC'    => {
                $BRANDING__PF_NAME  => 'JIMMYCHOO.COM',
                $BRANDING__DOC_HEADING  => 'J.CHOO (OS) Limited',
                $BRANDING__PLAIN_NAME => 'JIMMY CHOO',
                $BRANDING__SMS_SENDER_ID => 'JIMMYCHOO',
                $BRANDING__PREM_NAME  => 'New York Premier',
            },
        },
    );
# set-up expected email addresses and other details
my %expected_details    = (
        DC1 => {
            'NAP'   => {
                email   => {
                    shipping_email      => 'shipping.DAVE@net-a-porter.com',
                    customercare_email  => 'customercare.DAVE@net-a-porter.com',
                    localreturns_email  => 'premier.DAVE@net-a-porter.com',
                    returns_email       => 'returns.DAVE@net-a-porter.com',
                    fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    personalshopping_email=> 'MyShop.DAVE@net-a-porter.com',
                    premier_email       => 'premier.DAVE@net-a-porter.com',
                    shipping_email      => 'shipping.DAVE@net-a-porter.com',
                    dispatch_email      => 'dispatch.DAVE@net-a-porter.com',
                    samples_email       => 'samples.DAVE@net-a-porter.com',
                    'dc-returns_email'  => 'DC1-RETURNS.DAVE@net-a-porter.com',
                    fulfilment_email    => 'fulfilment.DAVE@net-a-porter.com',
                    goodsin_email       => 'GoodsInUK.DAVE@net-a-porter.com',
                    sample_arrival_email=> 'DC1-Samples.DAVE@net-a-porter.com',
                },
                company => {
                    tel => '+44 (0) 20 3471 4510',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '0800 044 5703',
                    premier_tel_mobile_friendly => '0330 022 5703',
                    premier_contact_hours => '8am-9pm weekdays, 9am-5pm weekends',
                },
                localised_email => {
                    'fr_FR' => {
                        customercare_email  => 'customercare.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'de_DE' => {
                        customercare_email  => 'customercare.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'zh_CN' => {
                        customercare_email  => 'customercare.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                },
            },
            'OUTNET'=> {
                email   => {
                    shipping_email      => 'shipping.DAVE@theoutnet.com',
                    customercare_email  => 'customercare.DAVE@theoutnet.com',
                    localreturns_email  => 'premier.DAVE@theoutnet.com',
                    returns_email       => 'customercare.DAVE@theoutnet.com',
                    fashionadvisor_email=> 'customercare.DAVE@theoutnet.com',
                    personalshopping_email=> 'customercare.DAVE@theoutnet.com',
                    premier_email       => 'premier.DAVE@theoutnet.com',
                    shipping_email      => 'shipping.DAVE@theoutnet.com',
                    dispatch_email      => 'dispatch.DAVE@theoutnet.com',
                    samples_email       => 'samples.DAVE@theoutnet.com',
                    'dc-returns_email'  => 'DC1-RETURNS.DAVE@theoutnet.com',
                    fulfilment_email    => 'fulfilment.DAVE@theoutnet.com',
                    goodsin_email       => 'GoodsInUK.DAVE@theoutnet.com',
                    sample_arrival_email=> 'DC1-Samples.DAVE@theoutnet.com',
                },
                company => {
                    tel => '+44 (0) 20 3471 4777',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel     => '0800 044 5710',
                    premier_tel_mobile_friendly => '0330 022 5710',
                    premier_contact_hours => '8am-9pm weekdays, 9am-5pm weekends',
                },
            },
            'MRP'   => {
                email   => {
                    shipping_email      => 'shipping.DAVE@mrporter.com',
                    customercare_email  => 'customercare.DAVE@mrporter.com',
                    localreturns_email  => 'premier.DAVE@mrporter.com',
                    returns_email       => 'returns.DAVE@mrporter.com',
                    fashionadvisor_email=> 'customercare.DAVE@mrporter.com',
                    personalshopping_email=> 'personalshopping.DAVE@mrporter.com',
                    premier_email       => 'premier.DAVE@mrporter.com',
                    shipping_email      => 'shipping.DAVE@mrporter.com',
                    dispatch_email      => 'dispatch.DAVE@mrporter.com',
                    samples_email       => 'samples.DAVE@mrporter.com',
                    'dc-returns_email'  => 'DC1-RETURNS.DAVE@mrporter.com',
                    fulfilment_email    => 'fulfilment.DAVE@mrporter.com',
                    goodsin_email       => 'GoodsInUK.DAVE@mrporter.com',
                    sample_arrival_email=> 'DC1-Samples.DAVE@mrporter.com',
                },
                company => {
                    tel => '+44 (0) 20 3471 4090',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '0800 044 5708',
                    premier_tel_mobile_friendly => '0330 022 5708',
                    premier_contact_hours => '8am-9pm weekdays, 9am-5pm weekends',
                },
            },
            'JC'    => {
                email   => {
                    shipping_email      => 'shipping.DAVE@jimmychooonline.com',
                    customercare_email  => 'customercare.DAVE@jimmychooonline.com',
                    localreturns_email  => 'londonpremier.DAVE@jimmychooonline.com',
                    returns_email       => 'customercare.DAVE@jimmychooonline.com',
                    fashionadvisor_email=> 'customercare.DAVE@jimmychooonline.com',
                    personalshopping_email=> 'customercare.DAVE@jimmychooonline.com',
                    premier_email       => 'londonpremier.DAVE@jimmychooonline.com',
                    shipping_email      => 'shipping.DAVE@jimmychooonline.com',
                    dispatch_email      => 'shipping.DAVE@jimmychooonline.com',
                    samples_email       => 'JCDistribution.DAVE@jimmychooonline.com',
                    'dc-returns_email'  => 'JCDistributionUK.DAVE@jimmychooonline.com',
                    fulfilment_email    => 'JCDistribution.DAVE@jimmychooonline.com',
                    goodsin_email       => 'JCDistribution.DAVE@jimmychooonline.com',
                    sample_arrival_email=> 'JCDistribution.DAVE@jimmychooonline.com',
                },
                company => {
                    tel => '+44 (0)20 3471 4799',
                    contact_hours   => '24 hours a day, seven days a week',
                },
            },
        },
        DC2 => {
            'NAP'   => {
                email   => {
                    shipping_email      => 'shipping.usa.DAVE@net-a-porter.com',
                    customercare_email  => 'customercare.usa.DAVE@net-a-porter.com',
                    localreturns_email  => 'premier.usa.DAVE@net-a-porter.com',
                    returns_email       => 'returns.usa.DAVE@net-a-porter.com',
                    fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    personalshopping_email=> 'MyShop.usa.DAVE@net-a-porter.com',
                    premier_email       => 'premier.usa.DAVE@net-a-porter.com',
                    shipping_email      => 'shipping.usa.DAVE@net-a-porter.com',
                    dispatch_email      => 'dispatch.usa.DAVE@net-a-porter.com',
                    samples_email       => 'SamplesUS.DAVE@net-a-porter.com',
                    'dc-returns_email'  => 'DC2-Returns.DAVE@net-a-porter.com',
                    fulfilment_email    => 'DistributionUSA.DAVE@net-a-porter.com',
                    goodsin_email       => 'DistributionUSA.DAVE@net-a-porter.com',
                    sample_arrival_email=> 'DC2-Samples.DAVE@net-a-porter.com',
                },
                company => {
                    tel => '1 877 6789 NAP (627)',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '1 877 5060 NYP (697)',
                    premier_tel_mobile_friendly => '1 877 5060 NYP (697)',
                    premier_contact_hours => '8.30am-8pm weekdays, 9am-5.30pm weekends',
                },
                localised_email => {
                    'fr_FR' => {
                        customercare_email  => 'customercare.usa.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'de_DE' => {
                        customercare_email  => 'customercare.usa.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'zh_CN' => {
                        customercare_email  => 'customercare.usa.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                },
            },
            'OUTNET'=> {
                email   => {
                    shipping_email      => 'shipping.usa.DAVE@theoutnet.com',
                    customercare_email  => 'customercare.usa.DAVE@theoutnet.com',
                    localreturns_email  => 'premier.usa.DAVE@theoutnet.com',
                    returns_email       => 'customercare.usa.DAVE@theoutnet.com',
                    fashionadvisor_email=> 'customercare.usa.DAVE@theoutnet.com',
                    personalshopping_email=> 'customercare.usa.DAVE@theoutnet.com',
                    premier_email       => 'premier.usa.DAVE@theoutnet.com',
                    shipping_email      => 'shipping.usa.DAVE@theoutnet.com',
                    dispatch_email      => 'dispatch.usa.DAVE@theoutnet.com',
                    samples_email       => 'SamplesUS.DAVE@theoutnet.com',
                    'dc-returns_email'  => 'DC2-Returns.DAVE@theoutnet.com',
                    fulfilment_email    => 'DistributionUSA.DAVE@theoutnet.com',
                    goodsin_email       => 'DistributionUSA.DAVE@theoutnet.com',
                    sample_arrival_email=> 'DC2-Samples.DAVE@theoutnet.com',
                },
                company => {
                    tel => '1 888 9 OUTNET (688638)',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel     => '1 855 688 7736',
                    premier_tel_mobile_friendly => '1 855 688 7736',
                    premier_contact_hours => '8.30am-8pm weekdays, 9am-5.30pm weekends',
                },
            },
            'MRP'   => {
                email   => {
                    shipping_email      => 'shipping.usa.DAVE@mrporter.com',
                    customercare_email  => 'customercare.usa.DAVE@mrporter.com',
                    localreturns_email  => 'premier.usa.DAVE@mrporter.com',
                    returns_email       => 'customercare.usa.DAVE@mrporter.com',
                    fashionadvisor_email=> 'customercare.usa.DAVE@mrporter.com',
                    personalshopping_email=> 'personalshopping.usa.DAVE@mrporter.com',
                    premier_email       => 'premier.usa.DAVE@mrporter.com',
                    shipping_email      => 'shipping.usa.DAVE@mrporter.com',
                    dispatch_email      => 'dispatch.usa.DAVE@mrporter.com',
                    samples_email       => 'samples.DAVE@mrporter.com',
                    'dc-returns_email'  => 'DC2-Returns.DAVE@mrporter.com',
                    fulfilment_email    => 'DistributionUSA.DAVE@mrporter.com',
                    goodsin_email       => 'DistributionUSA.DAVE@mrporter.com',
                    sample_arrival_email=> 'DC2-Samples.DAVE@mrporter.com',
                },
                company => {
                    tel => '1-877-5353-MRP (677)',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '1 877 93 NY MRP (69677)',
                    premier_tel_mobile_friendly => '1 877 93 NY MRP (69677)',
                    premier_contact_hours => '8.30am-8pm weekdays, 9am-5.30pm weekends',
                },
            },
            'JC'    => {
                email   => {
                    shipping_email      => 'shipping.usa.DAVE@jimmychooonline.com',
                    customercare_email  => 'customercare.usa.DAVE@jimmychooonline.com',
                    localreturns_email  => 'newyorkpremier.DAVE@jimmychooonline.com',
                    returns_email       => 'customercare.usa.DAVE@jimmychooonline.com',
                    fashionadvisor_email=> 'customercare.usa.DAVE@jimmychooonline.com',
                    personalshopping_email=> 'customercare.usa.DAVE@jimmychooonline.com',
                    premier_email       => 'newyorkpremier.DAVE@jimmychooonline.com',
                    shipping_email      => 'shipping.usa.DAVE@jimmychooonline.com',
                    dispatch_email      => 'shipping.usa.DAVE@jimmychooonline.com',
                    samples_email       => 'JCDistribution.usa.DAVE@jimmychooonline.com',
                    'dc-returns_email'  => 'JCDistributionUSA.DAVE@jimmychooonline.com',
                    fulfilment_email    => 'JCDistribution.usa.DAVE@jimmychooonline.com',
                    goodsin_email       => 'JCDistribution.usa.DAVE@jimmychooonline.com',
                    sample_arrival_email=> 'JCDistribution.usa.DAVE@jimmychooonline.com',
                },
                company => {
                    tel => '1877 95 JCHOO (52466)',
                    contact_hours   => '24 hours a day, seven days a week',
                },
            },
        },
        DC3 => {
            'NAP'   => {
                email   => {
                    customercare_email  => 'customercareapac.DAVE@net-a-porter.com',
                    localreturns_email  => 'premier.hk.DAVE@net-a-porter.com',
                    returns_email       => 'returns.apac.DAVE@net-a-porter.com',
                    fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    personalshopping_email=> 'myshop.cn.DAVE@net-a-porter.com',
                    premier_email       => 'premier.hk.DAVE@net-a-porter.com',
                    shipping_email      => 'shipping.hk.DAVE@net-a-porter.com',
                    dispatch_email      => 'dispatch.hk.DAVE@net-a-porter.com',
                    samples_email       => 'samples.hk.DAVE@net-a-porter.com',
                    'dc-returns_email'  => 'DC3-RETURNS.DAVE@net-a-porter.com',
                    fulfilment_email    => 'fulfilment.hk.DAVE@net-a-porter.com',
                    goodsin_email       => 'GoodsInHK.DAVE@net-a-porter.com',
                    sample_arrival_email=> 'DC3-Samples.DAVE@net-a-porter.com',
                },
                company => {
                    tel => '+44 (0) 330 022 5700',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '3018 6813',
                    premier_tel_mobile_friendly => '+(852) 3018 6813',
                    premier_contact_hours => '9am-9pm weekdays, 9am-5.30pm weekends',
                },
                localised_email => {
                    'fr_FR' => {
                        customercare_email  => 'customercareapac.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'de_DE' => {
                        customercare_email  => 'customercareapac.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                    'zh_CN' => {
                        customercare_email  => 'customercareapac.DAVE@net-a-porter.com',
                        fashionadvisor_email=> 'fashionconsultant.DAVE@net-a-porter.com',
                    },
                },
            },
            'OUTNET'=> {
                email   => {
                    customercare_email  => 'customercare.cn.DAVE@theoutnet.com',
                    localreturns_email  => 'premier.cn.DAVE@theoutnet.com',
                    returns_email       => 'returns.cn.DAVE@theoutnet.com',
                    fashionadvisor_email=> 'customercare.cn.DAVE@theoutnet.com',
                    personalshopping_email=> 'customercare.cn.DAVE@theoutnet.com',
                    premier_email       => 'premier.cn.DAVE@theoutnet.com',
                    shipping_email      => 'shipping.hk.DAVE@theoutnet.com',
                    dispatch_email      => 'dispatch.hk.DAVE@theoutnet.com',
                    samples_email       => 'samples.hk.DAVE@theoutnet.com',
                    'dc-returns_email'  => 'DC3-RETURNS.DAVE@theoutnet.com',
                    fulfilment_email    => 'fulfilment.hk.DAVE@theoutnet.com',
                    goodsin_email       => 'GoodsInHK.DAVE@theoutnet.com',
                    sample_arrival_email=> 'DC3-Samples.DAVE@theoutnet.com',
                },
                company => {
                    tel => '+44 (0) 330 022 5700',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel     => '+44 (0) 330 022 5700',
                    premier_tel_mobile_friendly => '+44 (0) 330 022 5700',
                    premier_contact_hours => '8.30am-8pm weekdays, 9am-5.30pm weekends',
                },
            },
            'MRP'   => {
                email   => {
                    customercare_email  => 'customercare.cn.DAVE@mrporter.com',
                    localreturns_email  => 'premier.cn.DAVE@mrporter.com',
                    returns_email       => 'returns.cn.DAVE@mrporter.com',
                    fashionadvisor_email=> 'customercare.cn.DAVE@mrporter.com',
                    personalshopping_email=> 'personalshopping.cn.DAVE@mrporter.com',
                    premier_email       => 'premier.cn.DAVE@mrporter.com',
                    shipping_email      => 'shipping.hk.DAVE@mrporter.com',
                    dispatch_email      => 'dispatch.hk.DAVE@mrporter.com',
                    samples_email       => 'samples.hk.DAVE@mrporter.com',
                    'dc-returns_email'  => 'DC3-RETURNS.DAVE@mrporter.com',
                    fulfilment_email    => 'fulfilment.hk.DAVE@mrporter.com',
                    goodsin_email       => 'GoodsInHK.DAVE@mrporter.com',
                    sample_arrival_email=> 'DC3-Samples.DAVE@mrporter.com',
                },
                company => {
                    tel => '+44 (0) 330 022 5700',
                    contact_hours   => '24 hours a day, seven days a week',
                    premier_tel => '+44 (0) 330 022 5700',
                    premier_tel_mobile_friendly => '+44 (0) 330 022 5700',
                    premier_contact_hours => '8.30am-8pm weekdays, 9am-5.30pm weekends',
                },
            },
            'JC'    => {
                email   => {
                    customercare_email  => 'customercare.cn.DAVE@jimmychooonline.com',
                    localreturns_email  => 'hkpremier.DAVE@jimmychooonline.com',
                    returns_email       => 'customercare.cn.DAVE@jimmychooonline.com',
                    fashionadvisor_email=> 'customercare.cn.DAVE@jimmychooonline.com',
                    personalshopping_email=> 'customercare.cn.DAVE@jimmychooonline.com',
                    premier_email       => 'hkpremier.DAVE@jimmychooonline.com',
                    shipping_email      => 'shipping.hk.DAVE@jimmychooonline.com',
                    dispatch_email      => 'shipping.hk.DAVE@jimmychooonline.com',
                    samples_email       => 'JCDistribution.hk.DAVE@jimmychooonline.com',
                    'dc-returns_email'  => 'JCDistribution.hk.DAVE@jimmychooonline.com',
                    fulfilment_email    => 'JCDistribution.hk.DAVE@jimmychooonline.com',
                    goodsin_email       => 'JCDistribution.hk.DAVE@jimmychooonline.com',
                    sample_arrival_email=> 'JCDistribution.hk.DAVE@jimmychooonline.com',
                },
                company => {
                    tel => '1877 95 JCHOO (52466)',
                    contact_hours   => '24 hours a day, seven days a week',
                },
            },
        },
    );

if ( !exists( $expected_details{ $distribution_centre } ) ) {
    fail( "Can't find any Expected Details for the DC: $distribution_centre" );
}

# get the relevent DC's details to expect
my $expected_dc = $expected_details{ $distribution_centre };
my $branding_dc = $expected_branding{ $distribution_centre };

# get the Sales Channels
my @channels    = $schema->resultset('Public::Channel')->all;

foreach my $channel ( @channels ) {
    note "TESTING Sales Channel: " . $channel->id . " - " . $channel->name;

    # get the Conf Section for the Channel to use as an Index for the Expected results
    my $conf_section    = $channel->business->config_section;

    my $expected        = $expected_dc->{ $conf_section };
    my $email_section   = 'Email_' . $conf_section;
    my $comp_section    = 'Company_' . $conf_section;

    my $branding    = $channel->branding;
    is_deeply( $branding, $branding_dc->{ $conf_section }, "Channel Branding is as Expected" );

    foreach my $setting ( keys %{ $expected->{company} } ) {
        is( config_var( $comp_section, $setting ), $expected->{company}{ $setting }, "Company '$setting' as Expected" );
    }

    foreach my $email ( keys %{ $expected->{email} } ) {
        is( config_var( $email_section, $email ), $expected->{email}{ $email }, "Email Address for '$email' as Expected" );
    }

    foreach my $locale ( keys %{ $expected->{localised_email} } ) {
        foreach my $email ( keys %{ $expected->{localised_email}{ $locale } } ) {
            my $got = localised_email_address( $schema, $locale, config_var( "Email_${conf_section}", $email ) );
            is( $got, $expected->{localised_email}{ $locale }{ $email },
                        "Localised Email Address for Locale: '${locale}', Email: '${email}' as Expected" );
        }
    }
}


done_testing;
