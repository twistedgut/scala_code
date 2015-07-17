-- DCOP-578: Bulk cleanup of transfer pending items
-- See DCOP-462 for investigation details. Basically Andy came up with a way
-- of identifying items in Transfer Pending that shouldn't be there, and this
-- deletes them and logs it. The variant id and shipment_item id restrictions
-- in here are to make sure the BAU doesn't take forever to run on production,
-- while still coping with changes that might have happened between the time
-- we ran the query on the slave to get the list of variant ids and the time
-- the BAU actually gets run.

BEGIN;

insert into log_sample_adjustment (
    sku, location_name, operator_name, channel_id, notes, delta, balance
)
select v.product_id || '-' || sku_padding(v.size_id), l.location, 'Application', q.channel_id,
    'Adjusted by BAU to fix error - DCOP-462', (-1*q.quantity), 0
from quantity q join variant v on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location='Transfer Pending'
and q.variant_id in (
1091382, 1087449, 1091084, 1072842, 1100228, 2201659, 2300035, 2300570, 787324,
948231, 1156321, 3032907, 3077640, 3083495, 3141439, 3201809, 3157533, 3185402,
3202689, 3288406, 3311042, 3387810, 3321636, 3345655, 3350310, 3350315, 3429200,
3512009, 3428868, 3554650, 3492153, 3556174, 3556173, 3482812, 3527733, 3528772,
3548636, 3561492, 3576454, 3591362, 3597579, 3597586, 3605175, 3604641, 3614096,
3685822, 3685831, 3685838, 3617009, 3623680, 3653645, 3624607, 3653512, 3696269,
3661019, 3676387, 3690965, 3666594, 3709408, 3726357, 3784280, 3685701, 3755654,
3722377, 3702055, 3710243, 3780015, 3706999, 3711746, 3792263, 3813739, 3859330,
3790409, 3727177, 3860787, 3751325, 3742910, 3742953, 3745823, 3746998, 3746994,
3831578, 3996759, 4063570, 3778376, 3779646, 3757742, 3757851, 3757868, 3893338,
3831742, 3761230, 3773029, 3767699, 3793908, 3770591, 3788768, 3771907, 3771926,
3772283, 3772279, 3772367, 3912683, 3787950, 3892176, 3791565, 3775572, 3777154,
3779651, 3775807, 3775941, 3894480, 3894467, 3831479, 3778609, 4147073, 3831511,
3831482, 3780269, 3796753, 3884828, 3780161, 3794215, 3831611, 3896001, 3895703,
3895640, 3895669, 3786708, 3783367, 3896486, 3904318, 3785241, 3785144, 3831609,
3831603, 3831608, 3831170, 3786106, 3786105, 3831727, 3829010, 3861076, 3812112,
3812127, 3797415, 3804007, 3796493, 3797164, 3797271, 3797251, 3882028, 3853584,
3804903, 3803637, 3831518, 3877208, 3804607, 3806488, 3872406, 3832095, 3813393,
3909558, 3909412, 3822479, 3822501, 3827137, 3827937, 3843851, 3903832, 3919634,
3891382, 3831661, 3831686, 3903661, 3840200, 3846715, 3912446, 3902985, 3903377,
3877268, 3876783, 3845950, 3845951, 3839735, 3839750, 3860927, 3909627, 3984570,
3984577, 3989104, 3847539, 3841838, 3841837, 3857431, 3848463, 3845743, 3847512,
3844760, 3866867, 3881332, 3847655, 3848691, 3858766, 3857742, 3862693, 3912835,
3853127, 3895236, 3902143, 3855496, 3855518, 3871278, 3856784, 3856796, 3859385,
3990055, 3990103, 3867551, 4271263, 3965441, 3927136, 3912843, 3980683, 3908879,
3908881, 3908935, 3911800, 3932054, 4002267, 3960673, 3988205, 3932233, 3948528,
3937167, 3971923, 3949395, 4116146, 4086530, 4086513, 4086553, 3962285, 3980642,
3967256, 3985271, 3985339, 4131611, 4000973, 4001435, 3993858, 3997589, 4355806,
3999707, 3997484, 4083978, 4071026, 3999823, 4063121, 4040212, 4084199, 4054101,
4066361, 4053634, 4053631, 4007561, 4107647, 4084285, 4059307, 4096223, 4054224,
4054150, 4108651, 4354842, 4053130, 4165679, 4074232, 4063432, 4063370, 4094767,
4094955, 4095039, 4095073, 4061320, 4079220, 4125536, 4068366, 4112482, 4066650,
4066718, 4065134, 4065081, 4066227, 4067121, 4074781, 4085705, 4096185, 4073902,
4073922, 4073201, 4074656, 4088379, 4083121, 4090361, 4082036, 4094407, 4095716,
4103363, 4084489, 4096028, 4097670, 4106321, 4127931, 4127920, 4117413, 4281470,
4142768, 4108402, 4108427, 4110133, 4118416, 4117518, 4117530, 4117652, 4185047,
4237989, 4124096, 4133739, 4135644, 4136689, 4138148, 4138204, 4225796, 4156901,
4155674, 4151008, 4161947, 4161945, 4161887, 4161911, 4161922, 4161935, 4161959,
4161845, 4168233, 4168353, 4168257, 4168256, 4168245, 4179692, 4157478, 4228646,
4165877, 4163454, 4398905, 4169966, 4169994, 4170016, 4170007, 4170010, 4170036,
4170037, 4190676, 4190403, 4238175, 4217899, 4217737, 4215050, 4217172, 4216796,
4217363, 4216984, 4217216, 4201755, 4201355, 4201379, 4201392, 4201413, 4201464,
4201487, 4201499, 4201522, 4201535, 4200833, 4200857, 4201007, 4201163, 4193062,
4193554, 4193578, 4193697, 4193710, 4193770, 4193782, 4193866, 4193980, 4194077,
4194063, 4346904, 4259583, 4244206, 4263505, 4369583, 4258841, 4258957, 4259299,
4263707, 4309736, 4351583, 4431316, 4453020, 4467057, 4512231, 4539301, 4564236,
4593390, 4577618, 1091382, 1087449, 1091084, 1072842, 1100228, 2201659, 2300035,
2300570, 787324, 948231, 1156321, 3032907, 3077640, 3083495, 3141439, 3201809,
3157533, 3185402, 3202689, 3288406, 3311042, 3387810, 3321636, 3345655, 3350310,
3350315, 3429200, 3512009, 3428868, 3554650, 3492153, 3556174, 3556173, 3482812,
3527733, 3528772, 3548636, 3561492, 3576454, 3591362, 3597579, 3597586, 3605175,
3604641, 3614096, 3685822, 3685831, 3685838, 3617009, 3623680, 3653645, 3624607,
3653512, 3696269, 3661019, 3676387, 3690965, 3666594, 3709408, 3726357, 3784280,
3685701, 3755654, 3722377, 3702055, 3710243, 3780015, 3706999, 3711746, 3792263,
3813739, 3859330, 3790409, 3727177, 3860787, 3751325, 3742910, 3742953, 3745823,
3746998, 3746994, 3831578, 3996759, 4063570, 3778376, 3779646, 3757742, 3757851,
3757868, 3893338, 3831742, 3761230, 3773029, 3767699, 3793908, 3770591, 3788768,
3771907, 3771926, 3772283, 3772279, 3772367, 3912683, 3787950, 3892176, 3791565,
3775572, 3777154, 3779651, 3775807, 3775941, 3894480, 3894467, 3831479, 3778609,
4147073, 3831511, 3831482, 3780269, 3796753, 3884828, 3780161, 3794215, 3831611,
3896001, 3895703, 3895640, 3895669, 3786708, 3783367, 3896486, 3904318, 3785241,
3785144, 3831609, 3831603, 3831608, 3831170, 3786106, 3786105, 3831727, 3829010,
3861076, 3812112, 3812127, 3797415, 3804007, 3796493, 3797164, 3797271, 3797251,
3882028, 3853584, 3804903, 3803637, 3831518, 3877208, 3804607, 3806488, 3872406,
3832095, 3813393, 3909558, 3909412, 3822479, 3822501, 3827137, 3827937, 3843851,
3903832, 3919634, 3891382, 3831661, 3831686, 3903661, 3840200, 3846715, 3912446,
3902985, 3903377, 3877268, 3876783, 3845950, 3845951, 3839735, 3839750, 3860927,
3909627, 3984570, 3984577, 3989104, 3847539, 3841838, 3841837, 3857431, 3848463,
3845743, 3847512, 3844760, 3866867, 3881332, 3847655, 3848691, 3858766, 3857742,
3862693, 3912835, 3853127, 3895236, 3902143, 3855496, 3855518, 3871278, 3856784,
3856796, 3859385, 3990055, 3990103, 3867551, 4271263, 3965441, 3927136, 3912843,
3980683, 3908879, 3908881, 3908935, 3911800, 3932054, 4002267, 3960673, 3988205,
3932233, 3948528, 3937167, 3971923, 3949395, 4116146, 4086530, 4086513, 4086553,
3962285, 3980642, 3967256, 3985271, 3985339, 4131611, 4000973, 4001435, 3993858,
3997589, 4355806, 3999707, 3997484, 4083978, 4071026, 3999823, 4063121, 4040212,
4084199, 4054101, 4066361, 4053634, 4053631, 4007561, 4107647, 4084285, 4059307,
4096223, 4054224, 4054150, 4108651, 4354842, 4053130, 4165679, 4074232, 4063432,
4063370, 4094767, 4094955, 4095039, 4095073, 4061320, 4079220, 4125536, 4068366,
4112482, 4066650, 4066718, 4065134, 4065081, 4066227, 4067121, 4074781, 4085705,
4096185, 4073902, 4073922, 4073201, 4074656, 4088379, 4083121, 4090361, 4082036,
4094407, 4095716, 4103363, 4084489, 4096028, 4097670, 4106321, 4127931, 4127920,
4117413, 4281470, 4142768, 4108402, 4108427, 4110133, 4118416, 4117518, 4117530,
4117652, 4185047, 4237989, 4124096, 4133739, 4135644, 4136689, 4138148, 4138204,
4225796, 4156901, 4155674, 4151008, 4161947, 4161945, 4161887, 4161911, 4161922,
4161935, 4161959, 4161845, 4168233, 4168353, 4168257, 4168256, 4168245, 4179692,
4157478, 4228646, 4165877, 4163454, 4398905, 4169966, 4169994, 4170016, 4170007,
4170010, 4170036, 4170037, 4190676, 4190403, 4238175, 4217899, 4217737, 4215050,
4217172, 4216796, 4217363, 4216984, 4217216, 4201755, 4201355, 4201379, 4201392,
4201413, 4201464, 4201487, 4201499, 4201522, 4201535, 4200833, 4200857, 4201007,
4201163, 4193062, 4193554, 4193578, 4193697, 4193710, 4193770, 4193782, 4193866,
4193980, 4194077, 4194063, 4346904, 4259583, 4244206, 4263505, 4369583, 4258841,
4258957, 4259299, 4263707, 4309736, 4351583, 4431316, 4453020, 4467057, 4512231,
4539301, 4564236, 4593390, 4577618
)
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    where si.shipment_item_status_id != 8 -- not Returned
    and si.id > 6000000 -- we can assume nothing has changed with anything older
                        -- than this since the variant id list was built
)
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    join return_item ri on ri.shipment_item_id=si.id
    where ri.return_item_status_id != 7 -- not Put Away
    and si.id > 6000000
);

delete from quantity where id in (
select q.id
from quantity q join variant v on v.id=q.variant_id
join location l on q.location_id=l.id
where l.location='Transfer Pending'
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    where si.shipment_item_status_id != 8 -- not Returned
    and si.id > 6000000
)
and v.id not in (
    select si.variant_id
    from shipment_item si join shipment s on s.id=si.shipment_id
    join link_stock_transfer__shipment lsts on lsts.shipment_id=s.id
    join stock_transfer st on lsts.stock_transfer_id=st.id
    join return_item ri on ri.shipment_item_id=si.id
    where ri.return_item_status_id != 7 -- not Put Away
    and si.id > 6000000
)
)
and variant_id in (
1091382, 1087449, 1091084, 1072842, 1100228, 2201659, 2300035, 2300570, 787324,
948231, 1156321, 3032907, 3077640, 3083495, 3141439, 3201809, 3157533, 3185402,
3202689, 3288406, 3311042, 3387810, 3321636, 3345655, 3350310, 3350315, 3429200,
3512009, 3428868, 3554650, 3492153, 3556174, 3556173, 3482812, 3527733, 3528772,
3548636, 3561492, 3576454, 3591362, 3597579, 3597586, 3605175, 3604641, 3614096,
3685822, 3685831, 3685838, 3617009, 3623680, 3653645, 3624607, 3653512, 3696269,
3661019, 3676387, 3690965, 3666594, 3709408, 3726357, 3784280, 3685701, 3755654,
3722377, 3702055, 3710243, 3780015, 3706999, 3711746, 3792263, 3813739, 3859330,
3790409, 3727177, 3860787, 3751325, 3742910, 3742953, 3745823, 3746998, 3746994,
3831578, 3996759, 4063570, 3778376, 3779646, 3757742, 3757851, 3757868, 3893338,
3831742, 3761230, 3773029, 3767699, 3793908, 3770591, 3788768, 3771907, 3771926,
3772283, 3772279, 3772367, 3912683, 3787950, 3892176, 3791565, 3775572, 3777154,
3779651, 3775807, 3775941, 3894480, 3894467, 3831479, 3778609, 4147073, 3831511,
3831482, 3780269, 3796753, 3884828, 3780161, 3794215, 3831611, 3896001, 3895703,
3895640, 3895669, 3786708, 3783367, 3896486, 3904318, 3785241, 3785144, 3831609,
3831603, 3831608, 3831170, 3786106, 3786105, 3831727, 3829010, 3861076, 3812112,
3812127, 3797415, 3804007, 3796493, 3797164, 3797271, 3797251, 3882028, 3853584,
3804903, 3803637, 3831518, 3877208, 3804607, 3806488, 3872406, 3832095, 3813393,
3909558, 3909412, 3822479, 3822501, 3827137, 3827937, 3843851, 3903832, 3919634,
3891382, 3831661, 3831686, 3903661, 3840200, 3846715, 3912446, 3902985, 3903377,
3877268, 3876783, 3845950, 3845951, 3839735, 3839750, 3860927, 3909627, 3984570,
3984577, 3989104, 3847539, 3841838, 3841837, 3857431, 3848463, 3845743, 3847512,
3844760, 3866867, 3881332, 3847655, 3848691, 3858766, 3857742, 3862693, 3912835,
3853127, 3895236, 3902143, 3855496, 3855518, 3871278, 3856784, 3856796, 3859385,
3990055, 3990103, 3867551, 4271263, 3965441, 3927136, 3912843, 3980683, 3908879,
3908881, 3908935, 3911800, 3932054, 4002267, 3960673, 3988205, 3932233, 3948528,
3937167, 3971923, 3949395, 4116146, 4086530, 4086513, 4086553, 3962285, 3980642,
3967256, 3985271, 3985339, 4131611, 4000973, 4001435, 3993858, 3997589, 4355806,
3999707, 3997484, 4083978, 4071026, 3999823, 4063121, 4040212, 4084199, 4054101,
4066361, 4053634, 4053631, 4007561, 4107647, 4084285, 4059307, 4096223, 4054224,
4054150, 4108651, 4354842, 4053130, 4165679, 4074232, 4063432, 4063370, 4094767,
4094955, 4095039, 4095073, 4061320, 4079220, 4125536, 4068366, 4112482, 4066650,
4066718, 4065134, 4065081, 4066227, 4067121, 4074781, 4085705, 4096185, 4073902,
4073922, 4073201, 4074656, 4088379, 4083121, 4090361, 4082036, 4094407, 4095716,
4103363, 4084489, 4096028, 4097670, 4106321, 4127931, 4127920, 4117413, 4281470,
4142768, 4108402, 4108427, 4110133, 4118416, 4117518, 4117530, 4117652, 4185047,
4237989, 4124096, 4133739, 4135644, 4136689, 4138148, 4138204, 4225796, 4156901,
4155674, 4151008, 4161947, 4161945, 4161887, 4161911, 4161922, 4161935, 4161959,
4161845, 4168233, 4168353, 4168257, 4168256, 4168245, 4179692, 4157478, 4228646,
4165877, 4163454, 4398905, 4169966, 4169994, 4170016, 4170007, 4170010, 4170036,
4170037, 4190676, 4190403, 4238175, 4217899, 4217737, 4215050, 4217172, 4216796,
4217363, 4216984, 4217216, 4201755, 4201355, 4201379, 4201392, 4201413, 4201464,
4201487, 4201499, 4201522, 4201535, 4200833, 4200857, 4201007, 4201163, 4193062,
4193554, 4193578, 4193697, 4193710, 4193770, 4193782, 4193866, 4193980, 4194077,
4194063, 4346904, 4259583, 4244206, 4263505, 4369583, 4258841, 4258957, 4259299,
4263707, 4309736, 4351583, 4431316, 4453020, 4467057, 4512231, 4539301, 4564236,
4593390, 4577618, 1091382, 1087449, 1091084, 1072842, 1100228, 2201659, 2300035,
2300570, 787324, 948231, 1156321, 3032907, 3077640, 3083495, 3141439, 3201809,
3157533, 3185402, 3202689, 3288406, 3311042, 3387810, 3321636, 3345655, 3350310,
3350315, 3429200, 3512009, 3428868, 3554650, 3492153, 3556174, 3556173, 3482812,
3527733, 3528772, 3548636, 3561492, 3576454, 3591362, 3597579, 3597586, 3605175,
3604641, 3614096, 3685822, 3685831, 3685838, 3617009, 3623680, 3653645, 3624607,
3653512, 3696269, 3661019, 3676387, 3690965, 3666594, 3709408, 3726357, 3784280,
3685701, 3755654, 3722377, 3702055, 3710243, 3780015, 3706999, 3711746, 3792263,
3813739, 3859330, 3790409, 3727177, 3860787, 3751325, 3742910, 3742953, 3745823,
3746998, 3746994, 3831578, 3996759, 4063570, 3778376, 3779646, 3757742, 3757851,
3757868, 3893338, 3831742, 3761230, 3773029, 3767699, 3793908, 3770591, 3788768,
3771907, 3771926, 3772283, 3772279, 3772367, 3912683, 3787950, 3892176, 3791565,
3775572, 3777154, 3779651, 3775807, 3775941, 3894480, 3894467, 3831479, 3778609,
4147073, 3831511, 3831482, 3780269, 3796753, 3884828, 3780161, 3794215, 3831611,
3896001, 3895703, 3895640, 3895669, 3786708, 3783367, 3896486, 3904318, 3785241,
3785144, 3831609, 3831603, 3831608, 3831170, 3786106, 3786105, 3831727, 3829010,
3861076, 3812112, 3812127, 3797415, 3804007, 3796493, 3797164, 3797271, 3797251,
3882028, 3853584, 3804903, 3803637, 3831518, 3877208, 3804607, 3806488, 3872406,
3832095, 3813393, 3909558, 3909412, 3822479, 3822501, 3827137, 3827937, 3843851,
3903832, 3919634, 3891382, 3831661, 3831686, 3903661, 3840200, 3846715, 3912446,
3902985, 3903377, 3877268, 3876783, 3845950, 3845951, 3839735, 3839750, 3860927,
3909627, 3984570, 3984577, 3989104, 3847539, 3841838, 3841837, 3857431, 3848463,
3845743, 3847512, 3844760, 3866867, 3881332, 3847655, 3848691, 3858766, 3857742,
3862693, 3912835, 3853127, 3895236, 3902143, 3855496, 3855518, 3871278, 3856784,
3856796, 3859385, 3990055, 3990103, 3867551, 4271263, 3965441, 3927136, 3912843,
3980683, 3908879, 3908881, 3908935, 3911800, 3932054, 4002267, 3960673, 3988205,
3932233, 3948528, 3937167, 3971923, 3949395, 4116146, 4086530, 4086513, 4086553,
3962285, 3980642, 3967256, 3985271, 3985339, 4131611, 4000973, 4001435, 3993858,
3997589, 4355806, 3999707, 3997484, 4083978, 4071026, 3999823, 4063121, 4040212,
4084199, 4054101, 4066361, 4053634, 4053631, 4007561, 4107647, 4084285, 4059307,
4096223, 4054224, 4054150, 4108651, 4354842, 4053130, 4165679, 4074232, 4063432,
4063370, 4094767, 4094955, 4095039, 4095073, 4061320, 4079220, 4125536, 4068366,
4112482, 4066650, 4066718, 4065134, 4065081, 4066227, 4067121, 4074781, 4085705,
4096185, 4073902, 4073922, 4073201, 4074656, 4088379, 4083121, 4090361, 4082036,
4094407, 4095716, 4103363, 4084489, 4096028, 4097670, 4106321, 4127931, 4127920,
4117413, 4281470, 4142768, 4108402, 4108427, 4110133, 4118416, 4117518, 4117530,
4117652, 4185047, 4237989, 4124096, 4133739, 4135644, 4136689, 4138148, 4138204,
4225796, 4156901, 4155674, 4151008, 4161947, 4161945, 4161887, 4161911, 4161922,
4161935, 4161959, 4161845, 4168233, 4168353, 4168257, 4168256, 4168245, 4179692,
4157478, 4228646, 4165877, 4163454, 4398905, 4169966, 4169994, 4170016, 4170007,
4170010, 4170036, 4170037, 4190676, 4190403, 4238175, 4217899, 4217737, 4215050,
4217172, 4216796, 4217363, 4216984, 4217216, 4201755, 4201355, 4201379, 4201392,
4201413, 4201464, 4201487, 4201499, 4201522, 4201535, 4200833, 4200857, 4201007,
4201163, 4193062, 4193554, 4193578, 4193697, 4193710, 4193770, 4193782, 4193866,
4193980, 4194077, 4194063, 4346904, 4259583, 4244206, 4263505, 4369583, 4258841,
4258957, 4259299, 4263707, 4309736, 4351583, 4431316, 4453020, 4467057, 4512231,
4539301, 4564236, 4593390, 4577618
);
COMMIT;