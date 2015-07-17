package NAP::Locale::Mapping::Country;

use NAP::policy "tt";

use base 'Exporter';

use feature 'unicode_strings';

use Readonly;

Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_EN      => "en ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_A       => "à ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_AU      => "au ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_AL      => "à l’";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA    => "à la ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX     => "aux ";

Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR     => "pour ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L   => "pour l’";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE  => "pour le ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA  => "pour la ";
Readonly our $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES => "pour les ";

Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN      => "in ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IM      => "im ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE  => "in die ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER  => "in der ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN  => "in den ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DAS  => "in das ";

Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH    => "nach ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_NACH => "in nach ";

Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR     => "für ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE => "für die ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DAS => "für das ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DEN => "für den ";

Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN => "auf den ";
Readonly our $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE => "auf die ";


Readonly our $LOCALE_MAPPING__COUNTRY_NAME => {
    'GL' => {
        'fr' => {
            'country_name' => 'Groenland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Grönland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '格陵兰岛' }
    },
    'JM' => {
        'fr' => {
            'country_name' => 'Jamaïque',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Jamaika',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '牙买加' }
    },
    'PG' => {
        'fr' => {
            'country_name' => 'Papouasie-Nouvelle-Guinée',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Papua-Neuguinea',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴布亚新几内亚' }
    },
    'AT' => {
        'fr' => {
            'country_name' => 'Autriche',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Österreich',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '奥地利' }
    },
    'SZ' => {
        'fr' => {
            'country_name' => 'Swaziland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Swasiland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '斯威士兰' }
    },
    'BN' => {
        'fr' => {
            'country_name' => 'Brunei',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Brunei',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '文莱' }
    },
    'BW' => {
        'fr' => {
            'country_name' => 'Botswana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Botswana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '博茨瓦纳' }
    },
    'AO' => {
        'fr' => {
            'country_name' => 'Angola',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AL,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AL,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Angola',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '安哥拉' }
    },
    'VC' => {
        'fr' => {
            'country_name' => 'Saint-Vincent-et-les-Grenadines',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'St. Vincent und die Grenadinen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圣文森特和格林纳丁斯' }
    },
    'PR' => {
        'fr' => {
            'country_name' => 'Porto Rico',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Puerto Rico',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '波多黎各' }
    },
    'JP' => {
        'fr' => {
            'country_name' => 'Japon',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Japan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '日本' }
    },
    'NA' => {
        'fr' => {
            'country_name' => 'Namibie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Namibia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '纳米比亚' }
    },
    'LC' => {
        'fr' => {
            'country_name' => 'Sainte-Lucie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'St. Lucia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圣卢西亚' }
    },
    'MA' => {
        'fr' => {
            'country_name' => 'Maroc',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Marokko',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '摩洛哥' }
    },
    'VU' => {
        'fr' => {
            'country_name' => 'Vanuatu',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Vanuatu',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '瓦努阿图' }
    },
    'SV' => {
        'fr' => {
            'country_name' => 'Salvador',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'El Salvador',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '萨尔瓦多' }
    },
    'MT' => {
        'fr' => {
            'country_name' => 'Malte',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Malta',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马耳他' }
    },
    'MN' => {
        'fr' => {
            'country_name' => 'Mongolie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Mongolei',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '蒙古' }
    },
    'MP' => {
        'fr' => {
            'country_name' => 'Îles Mariannes du Nord',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Nördlichen Marianen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '北马里亚纳群岛' }
    },
    'IT' => {
        'fr' => {
            'country_name' => 'Italie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Italien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '意大利' }
    },
    'RE' => {
        'fr' => {
            'country_name' => 'Île de la Réunion',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AL,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AL,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Réunion',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '留尼汪' }
    },
    'WS' => {
        'fr' => {
            'country_name' => 'Samoa',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Samoa',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '萨摩亚' }
    },
    'FR' => {
        'fr' => {
            'country_name' => 'France',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Frankreich',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '法国' }
    },
    'EG' => {
        'fr' => {
            'country_name' => 'Égypte',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Ägypten',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '埃及' }
    },
    'PW' => {
        'fr' => {
            'country_name' => 'Palaos',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Palau',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '帕劳' }
    },
    'LR' => {
        'fr' => {
            'country_name' => 'Liberia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Liberia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '利比里亚' }
    },
    'TN' => {
        'fr' => {
            'country_name' => 'Tunisie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Tunesien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '突尼西亚' }
    },
    'BE' => {
        'fr' => {
            'country_name' => 'Belgique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Belgien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '比利时' }
    },
    'EE' => {
        'fr' => {
            'country_name' => 'Estonie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Estland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '爱沙尼亚' }
    },
    'CK' => {
        'fr' => {
            'country_name' => 'Îles Cook',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Cook Inseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '库克群岛' }
    },
    'BY' => {
        'fr' => {
            'country_name' => 'Biélorussie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Weißrussland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '白俄罗斯' }
    },
    'SA' => {
        'fr' => {
            'country_name' => 'Arabie Saoudite',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Saudi Arabien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '沙特阿拉伯' }
    },
    'NO' => {
        'fr' => {
            'country_name' => 'Norvège',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Norwegen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '挪威' }
    },
    'LS' => {
        'fr' => {
            'country_name' => 'Lesotho',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Lesotho',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '莱索托' }
    },
    'KR' => {
        'fr' => {
            'country_name' => 'Corée du Sud',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Südkorea',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '韩国' }
    },
    'IC' => {
        'fr' => {
            'country_name' => 'îles Canaries (les)',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Spanien - Kanaren',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '西班牙：加那利群岛' }
    },
    'ZA' => {
        'fr' => {
            'country_name' => 'Afrique du Sud',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Südafrika',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '南非' }
    },
    'PT' => {
        'fr' => {
            'country_name' => 'Portugal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Portugal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '葡萄牙' }
    },
    'CA' => {
        'fr' => {
            'country_name' => 'Canada',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kanada',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '加拿大' }
    },
    'AM' => {
        'fr' => {
            'country_name' => 'Armenien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Armenien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '亚美尼亚' }
    },
    'CM' => {
        'fr' => {
            'country_name' => 'Cameroun',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kamerun',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '喀麦隆' }
    },
    'SR' => {
        'fr' => {
            'country_name' => 'Suriname',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Suriname ',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '苏里南' }
    },
    'MG' => {
        'fr' => {
            'country_name' => 'Madagascar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Madagaskar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马达加斯加' }
    },
    'NP' => {
        'fr' => {
            'country_name' => 'Népal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Nepal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '尼泊尔' }
    },
    'BT' => {
        'fr' => {
            'country_name' => 'Bhoutan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Bhutan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '不丹' }
    },
    'PL' => {
        'fr' => {
            'country_name' => 'Pologne',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Polen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '波兰' }
    },
    'GA' => {
        'fr' => {
            'country_name' => 'Gabon',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Gabun',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '加蓬' }
    },
    'BA' => {
        'fr' => {
            'country_name' => 'Bosnie-Herzégovine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Bosnien-Herzegovina',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '波斯尼亚和黑塞哥维那' }
    },
    'AE' => {
        'fr' => {
            'country_name' => 'Émirats Arabes Unis',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Vereinten Arabischen Emirate',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '阿联酋' }
    },
    'TH' => {
        'fr' => {
            'country_name' => 'Thaïlande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Thailand',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '泰国' }
    },
    'KY' => {
        'fr' => {
            'country_name' => 'Îles Caïmans',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Kaimaninseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '开曼群岛' }
    },
    'LA' => {
        'fr' => {
            'country_name' => 'Laos',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Laos',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '老挝' }
    },
    'PH' => {
        'fr' => {
            'country_name' => 'Philippines',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Philippinen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '菲律宾' }
    },
    'NI' => {
        'fr' => {
            'country_name' => 'Nicaragua',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Nicaragua',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '尼加拉瓜' }
    },
    'NC' => {
        'fr' => {
            'country_name' => 'Nouvelle-Calédonie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Neukaledonien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '新喀里多尼亚' }
    },
    'GU' => {
        'fr' => {
            'country_name' => 'Guam',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Guam',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '关岛' }
    },
    'KZ' => {
        'fr' => {
            'country_name' => 'Kazakhstan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kasachstan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '哈萨克斯坦' }
    },
    'DM' => {
        'fr' => {
            'country_name' => 'Dominique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Dominica',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '多米尼克' }
    },
    'TO' => {
        'fr' => {
            'country_name' => 'Tonga',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Tonga',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '汤加' }
    },
    'AD' => {
        'fr' => {
            'country_name' => 'Andorre',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Andorra',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '安道尔' }
    },
    'SE' => {
        'fr' => {
            'country_name' => 'Suède',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Schweden',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '瑞典' }
    },
    'AZ' => {
        'fr' => {
            'country_name' => 'Azerbaïdjan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Aserbaidschan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '阿塞拜疆' }
    },
    'KE' => {
        'fr' => {
            'country_name' => 'Kenya',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kenia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '肯尼亚' }
    },
    'ME' => {
        'fr' => {
            'country_name' => 'Monténégro',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Montenegro',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '黑山共和国' }
    },
    'OM' => {
        'fr' => {
            'country_name' => 'Oman',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Oman',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DEN
            }
        },
        'zh' => { 'country_name' => '阿曼' }
    },
    'VN' => {
        'fr' => {
            'country_name' => 'Viêt Nam',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Vietnam',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '越南' }
    },
    'VG' => {
        'fr' => {
            'country_name' => 'Îles Vierges britanniques',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Britischen Jungferninseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '英属维尔京群岛' }
    },
    'YE' => {
        'fr' => {
            'country_name' => 'Yémen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Yemen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DEN
            }
        },
        'zh' => { 'country_name' => '也门' }
    },
    'DZ' => {
        'fr' => {
            'country_name' => 'Algérie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Algerien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '阿尔及利亚' }
    },
    'LK' => {
        'fr' => {
            'country_name' => 'Sri Lanka',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Sri Lanka',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '斯里兰卡' }
    },
    'ID' => {
        'fr' => {
            'country_name' => 'Indonésie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Indonesien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '印尼' }
    },
    'FM' => {
        'fr' => {
            'country_name' => 'États fédérés de Micronésie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Förderierten Staaten von Mikronesien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '密克罗尼西亚联邦' }
    },
    'GE' => {
        'fr' => {
            'country_name' => 'Géorgie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Georgien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '格鲁吉亚' }
    },
    'GM' => {
        'fr' => {
            'country_name' => 'Gambie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Gamba',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '冈比亚' }
    },
    'LV' => {
        'fr' => {
            'country_name' => 'Lettonie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Lettland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '拉脱维亚' }
    },
    'RU' => {
        'fr' => {
            'country_name' => 'Russie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Russland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '俄罗斯' }
    },
    'LB' => {
        'fr' => {
            'country_name' => 'Liban',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Libanon',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DEN
            }
        },
        'zh' => { 'country_name' => '黎巴嫩' }
    },
    'FK' => {
        'fr' => {
            'country_name' => 'Îles Falkland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Falklandinseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '福克兰群岛' }
    },
    'DE' => {
        'fr' => {
            'country_name' => 'Allemagne',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Deutschland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '德国' }
    },
    'FI' => {
        'fr' => {
            'country_name' => 'Finlande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Finnland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '芬兰' }
    },
    'MV' => {
        'fr' => {
            'country_name' => 'Maldives',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Malediven',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '马尔代夫' }
    },
    'LU' => {
        'fr' => {
            'country_name' => 'Luxembourg',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Luxemburg',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '卢森堡' }
    },
    'VE' => {
        'fr' => {
            'country_name' => 'Venezuela',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Venezuela',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '委内瑞拉' }
    },
    'BH' => {
        'fr' => {
            'country_name' => 'Bahreïn',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Bahrain',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴林' }
    },
    'GI' => {
        'fr' => {
            'country_name' => 'Gibraltar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Gibraltar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '直布罗陀' }
    },
    'RO' => {
        'fr' => {
            'country_name' => 'Roumanie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Rumänien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '罗马尼亚' }
    },
    'VI' => {
        'fr' => {
            'country_name' => 'Îles Vierges américaines',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Amerikanischen Jungferninseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '美属维尔京群岛' }
    },
    'TV' => {
        'fr' => {
            'country_name' => 'Tuvalu',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Tuvalu',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '图瓦卢' }
    },
    'IN' => {
        'fr' => {
            'country_name' => 'Inde',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Indien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '印度' }
    },
    'GP' => {
        'fr' => {
            'country_name' => 'Guadeloupe',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Guadeloupe',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '瓜德罗普' }
    },
    'AR' => {
        'fr' => {
            'country_name' => 'Argentine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Argentinien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '阿根廷' }
    },
    'SN' => {
        'fr' => {
            'country_name' => 'Sénégal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Senegal',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '塞内加尔' }
    },
    'MX' => {
        'fr' => {
            'country_name' => 'Mexique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Mexiko',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '墨西哥' }
    },
    'AW' => {
        'fr' => {
            'country_name' => 'Aruba',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Aruba',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '阿鲁巴' }
    },
    'FO' => {
        'fr' => {
            'country_name' => 'Îles Féroé',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Färöer',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '法罗群岛' }
    },
    'MC' => {
        'fr' => {
            'country_name' => 'Monaco',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Monaco',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '摩纳哥' }
    },
    'HN' => {
        'fr' => {
            'country_name' => 'Honduras',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Honduras',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '洪都拉斯' }
    },
    'BR' => {
        'fr' => {
            'country_name' => 'Brésil',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Brasilien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴西' }
    },
    'IL' => {
        'fr' => {
            'country_name' => 'Israël',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Israel',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '以色列' }
    },
    'GG' => {
        'fr' => {
            'country_name' => 'Guernesey',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Vereinigte Königreich - Jersey',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DAS,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DAS
            }
        },
        'zh' => { 'country_name' => '英国：根西岛' }
    },
    'SB' => {
        'fr' => {
            'country_name' => 'Îles Salomon',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Salomonen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '所罗门群岛' }
    },
    'NZ' => {
        'fr' => {
            'country_name' => 'Nouvelle-Zélande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Neuseeland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '新西兰' }
    },
    'HU' => {
        'fr' => {
            'country_name' => 'Hongrie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Ungarn',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '匈牙利' }
    },
    'DO' => {
        'fr' => {
            'country_name' => 'République Dominicaine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Dominikanische Republik',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '多米尼加' }
    },
    'UG' => {
        'fr' => {
            'country_name' => 'Ouganda',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Uganda',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '乌干达' }
    },
    'KH' => {
        'fr' => {
            'country_name' => 'Cambodge',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kambodscha',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '柬埔寨' }
    },
    'TG' => {
        'fr' => {
            'country_name' => 'Togo',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Togo',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '多哥' }
    },
    'GB' => {
        'fr' => {
            'country_name' => 'Royaume-Uni',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Vereinigte Königreich - Guernsey',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DAS,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DAS
            }
        },
        'zh' => { 'country_name' => '英国' }
    },
    'BB' => {
        'fr' => {
            'country_name' => 'Barbade',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Barbados',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴巴多斯' }
    },
    'JE' => {
        'fr' => {
            'country_name' => 'Jersey – Royaume-Uni',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Vereinigten Staaten',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '英国：泽西岛' }
    },
    'HT' => {
        'fr' => {
            'country_name' => 'Haïti',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Haiti',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '海地' }
    },
    'DK' => {
        'fr' => {
            'country_name' => 'Danemark',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Dänemark',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '丹麦' }
    },
    'PA' => {
        'fr' => {
            'country_name' => 'Panama',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Panama',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴拿马' }
    },
    'QA' => {
        'fr' => {
            'country_name' => 'Qatar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Katar',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '卡塔尔' }
    },
    'CV' => {
        'fr' => {
            'country_name' => 'Îles du Cap-Vert',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Kapverdischen Inseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '佛得角' }
    },
    'GD' => {
        'fr' => {
            'country_name' => 'Grenade',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Grenada',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '格林纳达' }
    },
    'GF' => {
        'fr' => {
            'country_name' => 'Guyane française',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Französich-Guayana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '法属圭亚那' }
    },
    'MO' => {
        'fr' => {
            'country_name' => 'Macao',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Macau',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '澳门' }
    },
    'KM' => {
        'fr' => {
            'country_name' => 'Îles Comores',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Komoren',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '科摩罗群岛' }
    },
    'HR' => {
        'fr' => {
            'country_name' => 'Croatie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Kroatien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '克罗地亚' }
    },
    'KW' => {
        'fr' => {
            'country_name' => 'Koweït',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Kuwait',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '科威特' }
    },
    'TC' => {
        'fr' => {
            'country_name' => 'Îles Turques et Caïques',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Turks- und Caicosinseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '特克斯和凯科斯群岛' }
    },
    'MQ' => {
        'fr' => {
            'country_name' => 'Martinique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A_LA,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Martinique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马提尼克' }
    },
    'CZ' => {
        'fr' => {
            'country_name' => 'République Tchèque',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Tschechische Republik',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '捷克共和国' }
    },
    'BL' => {
        'fr' => {
            'country_name' => 'Saint-Barthélemy',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Saint Barthélemy',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => ' 圣巴泰勒米岛' }
    },
    'XY' => { # this is a hack! St Barthélemy has ISO country code BL,
              # but DHL calls it XY; we had to align our database with
              # DHL, otherwise we can't ship there :((( see DCOP-1729
        'fr' => {
            'country_name' => 'Saint-Barthélemy',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Saint Barthélemy',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => ' 圣巴泰勒米岛' }
    },
    'ES' => {
        'fr' => {
            'country_name' => 'Espagne',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Spanien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '西班牙' }
    },
    'MZ' => {
        'fr' => {
            'country_name' => 'Mozambique',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Mosambik',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '莫桑比克' }
    },
    'BO' => {
        'fr' => {
            'country_name' => 'Bolivie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Bolivien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '玻利维亚' }
    },
    'ST' => {
        'fr' => {
            'country_name' => 'Sao Tomé-et-Principe',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'São Tomé und Príncipe',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圣多美和普林西比' }
    },
    'AU' => {
        'fr' => {
            'country_name' => 'Australie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Australien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '澳大利亚' }
    },
    'AL' => {
        'fr' => {
            'country_name' => 'Albanie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Albanien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '阿尔巴尼亚' }
    },
    'TR' => {
        'fr' => {
            'country_name' => 'Turquie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Türkei',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '土耳其' }
    },
    'MD' => {
        'fr' => {
            'country_name' => 'Moldavie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Moldawien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '摩尔多瓦' }
    },
    'MK' => {
        'fr' => {
            'country_name' => 'Macédoine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Mazedonien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马其顿' }
    },
    'GR' => {
        'fr' => {
            'country_name' => 'Grèce',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Griechenland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '希腊' }
    },
    'AG' => {
        'fr' => {
            'country_name' => 'Anguilla',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Antigua und Barbuda',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '安提瓜和巴布达' }
    },
    'SI' => {
        'fr' => {
            'country_name' => 'Slovénie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Slowenien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '斯洛文尼亚' }
    },
    'CO' => {
        'fr' => {
            'country_name' => 'Colombie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Kolumbien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '哥伦比亚' }
    },
    'AI' => {
        'fr' => {
            'country_name' => 'Angola',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Anguilla',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '安圭拉岛' }
    },
    'AN' => {
        'fr' => {
            'country_name' => 'Antilles néerlandaises',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Niederländischen Antillen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '荷属安的列斯群岛' }
    },
    'XC' => {
        'fr' => {
            'country_name' => 'Curaçao',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Curaçao',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '库拉索' }
    },
    'JO' => {
        'fr' => {
            'country_name' => 'Jordanie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Jordanien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '约旦' }
    },
    'SM' => {
        'fr' => {
            'country_name' => 'Saint-Martin',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'San Marino',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圣马力诺' }
    },
    'UA' => {
        'fr' => {
            'country_name' => 'Ukraine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Ukraine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '乌克兰' }
    },
    'CL' => {
        'fr' => {
            'country_name' => 'Chili',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Chile',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '智利' }
    },
    'KN' => {
        'fr' => {
            'country_name' => 'Saint-Christophe-et-Nevis',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'St. Kitts and Nevis',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圣基茨和尼维斯' }
    },
    'SC' => {
        'fr' => {
            'country_name' => 'Seychelles',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Seychellen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '塞舌尔' }
    },
    'ET' => {
        'fr' => {
            'country_name' => 'Éthiopie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Äthiopien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '埃塞俄比亚' }
    },
    'IS' => {
        'fr' => {
            'country_name' => 'Islande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Island',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '冰岛' }
    },
    'NL' => {
        'fr' => {
            'country_name' => 'Pays-Bas',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Niederlande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '荷兰' }
    },
    'MS' => {
        'fr' => {
            'country_name' => 'Montserrat',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Montserrat',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '蒙特塞拉特' }
    },
    'EC' => {
        'fr' => {
            'country_name' => 'Équateur',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Ecuador',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '厄瓜多尔' }
    },
    'HK' => {
        'fr' => {
            'country_name' => 'Hong Kong',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Hong Kong',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '香港' }
    },
    'MY' => {
        'fr' => {
            'country_name' => 'Malaisie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Malaysia',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马来西亚' }
    },
    'CR' => {
        'fr' => {
            'country_name' => 'Costa Rica – San José',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Costa-Rica - San José',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '哥斯达黎加：圣何塞' }
    },
    'RS' => {
        'fr' => {
            'country_name' => 'Serbie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Serbien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '塞尔维亚' }
    },
    'CN' => {
        'fr' => {
            'country_name' => 'Chine',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'China',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '中国' }
    },
    'BG' => {
        'fr' => {
            'country_name' => 'Bulgarie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Bulgarien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '保加利亚' }
    },
    'MH' => {
        'fr' => {
            'country_name' => 'Îles Marshall',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Republik Marshallinseln',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '马绍尔群岛' }
    },
    'UY' => {
        'fr' => {
            'country_name' => 'Uruguay',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Uruguay',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '乌拉圭' }
    },
    'PY' => {
        'fr' => {
            'country_name' => 'Paraguay',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Paraguay',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴拉圭' }
    },
    'BS' => {
        'fr' => {
            'country_name' => 'Bahamas',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Bahamas',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_AUF_DEN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '巴哈马' }
    },
    'TL' => {
        'fr' => {
            'country_name' => 'Timor-Leste',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Timor Leste',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '东帝汶' }
    },
    'MU' => {
        'fr' => {
            'country_name' => 'Maurice',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Mauritius',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '毛里求斯' }
    },
    'CH' => {
        'fr' => {
            'country_name' => 'Suisse',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Schweiz',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '瑞士' }
    },
    'LI' => {
        'fr' => {
            'country_name' => 'Liechtenstein',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Liechtenstein',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '列支敦士登' }
    },
    'GH' => {
        'fr' => {
            'country_name' => 'Ghana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Ghana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '加纳' }
    },
    'US' => {
        'fr' => {
            'country_name' => 'États-Unis',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Vereinigte Königreich',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DAS,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IM,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DAS
            }
        },
        'zh' => { 'country_name' => '美国' }
    },
    'PE' => {
        'fr' => {
            'country_name' => 'Pérou',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Peru',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '秘鲁' }
    },
    'SL' => {
        'fr' => {
            'country_name' => 'Sierra Leone',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Sierra Leone',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '塞拉利昂' }
    },
    'BZ' => {
        'fr' => {
            'country_name' => 'Belize',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Belize',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '伯利兹' }
    },
    'CY' => {
        'fr' => {
            'country_name' => 'Chypre',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Zypern',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '塞浦路斯' }
    },
    'FJ' => {
        'fr' => {
            'country_name' => 'Îles Fidji',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Fidschi',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '斐济' }
    },
    'IE' => {
        'fr' => {
            'country_name' => 'Irlande',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_L
            }
        },
        'de' => {
            'country_name' => 'Irland',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '爱尔兰' }
    },
    'TW' => {
        'fr' => {
            'country_name' => 'Taïwan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Taiwan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '台湾' }
    },
    'KP' => {
        'fr' => {
            'country_name' => 'Corée du Nord',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Nordkorea',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '朝鲜' }
    },
    'PF' => {
        'fr' => {
            'country_name' => 'Polynésie française',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Französisch-Polynesien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '法属波利尼西亚' }
    },
    'AS' => {
        'fr' => {
            'country_name' => 'Samoa américaines',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Amerikanisch-Samoa',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '美属萨摩亚' }
    },
    'TZ' => {
        'fr' => {
            'country_name' => 'Tanzanie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Tansania',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '坦桑尼亚' }
    },
    'MW' => {
        'fr' => {
            'country_name' => 'Malawi',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Malawi',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '马拉维' }
    },
    'GT' => {
        'fr' => {
            'country_name' => 'Guatemala',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Guatemala',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '危地马拉' }
    },
    'GY' => {
        'fr' => {
            'country_name' => 'Guyane',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Guyana',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '圭亚那' }
    },
    'BM' => {
        'fr' => {
            'country_name' => 'Bermudes',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AUX,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LES
            }
        },
        'de' => {
            'country_name' => 'Bermuda',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '百慕大群岛' }
    },
    'PK' => {
        'fr' => {
            'country_name' => 'Pakistan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Pakistan',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '巴基斯坦' }
    },
    'LT' => {
        'fr' => {
            'country_name' => 'Lituanie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Litauen',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '立陶宛' }
    },
    'SG' => {
        'fr' => {
            'country_name' => 'Singapour',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Singapur',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '新加坡' }
    },
    'TT' => {
        'fr' => {
            'country_name' => 'Trinité-et-Tobago',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_AU,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR
            }
        },
        'de' => {
            'country_name' => 'Trinidad und Tobago',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '特立尼达和多巴哥' }
    },
    'SY' => {
        'fr' => {
            'country_name' => 'Syrie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Syrien',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '叙利亚' }
    },
    'SK' => {
        'fr' => {
            'country_name' => 'Slovaquie',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_EN,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LA
            }
        },
        'de' => {
            'country_name' => 'Slowakei',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DIE,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN_DER,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR_DIE
            }
        },
        'zh' => { 'country_name' => '斯洛伐克' }
    },
    'BD' => {
        'fr' => {
            'country_name' => 'Bangladesh',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'in'  => $LOCALE_MAPPING__PREPOSITION_FRENCH_A,
                'for' => $LOCALE_MAPPING__PREPOSITION_FRENCH_POUR_LE
            }
        },
        'de' => {
            'country_name' => 'Bangladesch',
            'preposition'  => {
                'to'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_NACH,
                'in'  => $LOCALE_MAPPING__PREPOSITION_GERMAN_IN,
                'for' => $LOCALE_MAPPING__PREPOSITION_GERMAN_FUR
            }
        },
        'zh' => { 'country_name' => '孟加拉' }
    }
};

our @EXPORT_OK = qw(
    $LOCALE_MAPPING__COUNTRY_NAME
);
