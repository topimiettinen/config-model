# -*- cperl -*-

use Test::More;
use Test::Differences;
use Test::Memory::Cycle;
use Config::Model;
use Config::Model::Tester::Setup qw/init_test/;
use Test::Log::Log4perl;

use strict;
use warnings;

use 5.10.1;

my ($model, $trace, $args) = init_test('rd-hint','rd-trace');

note("use --rd-hint or --rd-trace options to debug Parse::RecDescent");

Test::Log::Log4perl-> ignore_priority('INFO');

$model->create_config_class(
    name    => "Slave",
    element => [
        find_node_element_name => {
            type       => 'leaf',
            value_type => 'string',
            compute    => {
                formula => '&element(-)',
            },
        },
        location_function_in_formula => {
            type       => 'leaf',
            value_type => 'string',
            compute    => {
                formula => '&location',
            },
        },
        check_node_element_name => {
            type       => 'leaf',
            value_type => 'boolean',
            compute    => {
                formula => '"&element(-)" eq "foo2"',
            },
        },
        [qw/av bv/] => {
            type       => 'leaf',
            value_type => 'integer',
            compute    => {
                variables => { p => '! &element' },
                formula   => '$p',
            },
        },
        Licenses => {
            type       => 'hash',
            index_type => 'string',
            cargo      => {
                type              => 'node',
                config_class_name => 'LicenseSpec'
            }
        },
    ] );

# Tx to Ilya Arosov
$model->create_config_class(
    'name'    => 'TestIndex',
    'element' => [
        name => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
            'compute'    => {
                'formula'   => '$my_name is my name',
                'variables' => {
                    'my_name' => '! index_function_target:&index(-) name'
                }
            },
        } ] );

$model->create_config_class(
    'name'    => 'TargetIndex',
    'element' => [
        name => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
        } ] );

$model->create_config_class(
    'name'    => 'LicenseSpec',
    'element' => [
        'text',
        {
            'value_type' => 'string',
            'type'       => 'leaf',
            'compute'    => {
                'replace' => {
                    'GPL-1+'   => "yada yada GPL-1+\nyada yada",
                    'Artistic' => "yada yada Artistic\nyada yada",
                },
                'formula'        => '$replace{&index(-)}',
                'allow_override' => '1',
                undef_is         => '',
            },
        },
        short_name_from_index => {
            'type'       => 'leaf',
            'value_type' => 'string',
            compute      => {
                'formula'  => '&index( - );',
                'use_eval' => 1,
            },
        },
        short_name_from_above1 => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
            compute      => {
                'formula'  => '&element( - - )',
            },
        },
        short_name_from_above2 => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
            compute      => {
                'formula'  => '&element( -- )',
            },
        },
        short_name_from_above3 => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
            compute      => {
                'formula'  => '&element( -2 )',
            },
        },
    ]
);

$model->create_config_class(
    name    => "Master",
    element => [
        [qw/av bv/] => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'integer',
        },
        compute_int => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'integer',
            compute    => {
                formula   => '$a + $b',
                variables => { a => '- av', b => '- bv' }
            },
            min => -4,
            max => 4,
        },
        [qw/sav sbv/] => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'string',
        },
        one_var => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'string',
            compute    => {
                formula   => '&element().$bar',
                variables => { bar => '- sbv' }
            },
        },
        one_wrong_var => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'string',
            compute    => {
                formula   => '$bar',
                variables => { bar => '- wrong_v' }
            },
        },
        meet_test => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'string',
            compute    => {
                formula   => 'meet $a and $b',
                variables => { a => '- sav', b => '- sbv' }
            },
        },
        compute_with_override => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'integer',
            compute    => {
                formula        => '$a + $b',
                variables      => { a => '- av', b => '- bv' },
                allow_override => 1,
            },
            min => -4,
            max => 4,
        },
        compute_with_warning => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'integer',
            compute    => {
                formula        => '$a + $b',
                variables      => { a => '- av', b => '- bv' },
                allow_override => 1,
            },
            warn_if => {
                positive_test => {
                    code => 'defined $_ && $_ < 0;',
                    msg  => 'should be positive',
                    fix  => '$_ = 0;'
                }
            },
            min => -4,
            max => 4,
        },
        compute_with_override_and_fix => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'uniline',
            compute    => {
                formula        => 'def value',
                allow_override => 1,
            },
            warn_unless => {
                device_file => {
                    code => 'm/def/;',
                    msg => "not default value",
                    fix => '$_ = undef;'
                }
            }
        },
        # emulate imon problem where /dev/lcd0 is the default value and may not be found
        compute_with_override_and_powerless_fix => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'uniline',
            compute    => {
                formula        => q"my $l = '/dev/lcd-imon'; -e $l ? $l : '/dev/lcd0';",
                use_eval => 1,
                allow_override => 1,
            },
            warn_if => {
                not_lcd_imon => {
                    code => q!my $l = '/dev/lcd-imon';defined $_ and -e $l and $_ ne $l ;!,
                    msg => "not lcd-foo.txt",
                    fix => '$_ = undef;'
                },
            },
            warn_unless => {
                good_value => {
                    code => 'defined $_ ? -e : 1;',
                    msg => "not good value",
                    fix => '$_ = undef;'
                }
            }
       },
       compute_with_upstream => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'integer',
            compute    => {
                formula                 => '$a + $b',
                variables               => { a => '- av', b => '- bv' },
                use_as_upstream_default => 1,
            },
        },
        compute_no_var => {
            type       => 'leaf',
            value_type => 'string',
            compute    => { formula => '&element()', },
        },
        [qw/bar foo2/] => {
            type              => 'node',
            config_class_name => 'Slave'
        },

        'url' => {
            type       => 'leaf',
            value_type => 'uniline',
        },
        'host' => {
            type       => 'leaf',
            value_type => 'uniline',
            compute    => {
                formula   => '$url =~ m!http://([\w\.]+)!; $1 ;',
                variables => { url => '- url' },
                use_eval  => 1,
            },
        },
        'with_tmp_var' => {
            type       => 'leaf',
            value_type => 'uniline',
            compute    => {
                formula   => 'my $tmp = $url; $tmp =~ m!http://([\w\.]+)!; $1 ;',
                variables => { url => '- url' },
                use_eval  => 1,
            },
        },
        'Upstream-Contact' => {
            'cargo' => {
                'value_type'   => 'uniline',
                'migrate_from' => {
                    'formula'   => '$maintainer',
                    'variables' => {
                        'maintainer' => '- Upstream-Maintainer:&index'
                    }
                },
                'type' => 'leaf'
            },
            'type' => 'list',
        },
        'Upstream-Maintainer' => {
            'cargo' => {
                'value_type'   => 'uniline',
                'migrate_from' => {
                    'formula'   => '$maintainer',
                    'variables' => {
                        'maintainer' => '- Maintainer:&index'
                    }
                },
                'type' => 'leaf'
            },
            'status' => 'deprecated',
            'type'   => 'list'
        },
        'Maintainer' => {
            'cargo' => {
                'value_type' => 'uniline',
                'type'       => 'leaf'
            },
            'type' => 'list',
        },
        'Source' => {
            'value_type'   => 'string',
            'mandatory'    => '1',
            'migrate_from' => {
                'use_eval'  => '1',
                'formula'   => '$old || $older ;',
                undef_is    => "''",
                'variables' => {
                    'older' => '- Original-Source-Location',
                    'old'   => '- Upstream-Source'
                }
            },
            'type' => 'leaf',
        },
        'Source2' => {
            'value_type' => 'string',
            'mandatory'  => '1',
            'compute'    => {
                'use_eval'  => '1',
                'formula'   => '$old || $older ;',
                undef_is    => "''",
                'variables' => {
                    'older' => '- Original-Source-Location',
                    'old'   => '- Upstream-Source'
                }
            },
            'type' => 'leaf',
        },
        [qw/Upstream-Source Original-Source-Location/] => {
            'value_type' => 'string',
            'status'     => 'deprecated',
            'type'       => 'leaf'
        },
        Licenses => {
            type       => 'hash',
            index_type => 'string',
            cargo      => {
                type              => 'node',
                config_class_name => 'LicenseSpec'
            }
        },
        index_function_target => {
            'type'       => 'hash',
            'index_type' => 'string',
            'cargo'      => {
                'config_class_name' => 'TargetIndex',
                'type'              => 'node'
            },
        },
        test_index_function => {
            'type'       => 'hash',
            'index_type' => 'string',
            'cargo'      => {
                'config_class_name' => 'TestIndex',
                'type'              => 'node'
            },
        },
        'OtherMaintainer' => { type => 'leaf', value_type => 'uniline' },
        'Vcs-Browser'     => {
            'type'       => 'leaf',
            'value_type' => 'uniline',
            'compute'    => {
                'allow_override' => '1',
                'formula' =>
                    '$maintainer =~ /pkg-(perl|ruby-extras)/p ? "http://anonscm.debian.org/gitweb/?p=${^MATCH}/packages/$pkgname.git" : undef ;',
                'use_eval'  => '1',
                'variables' => {
                    'maintainer' => '- OtherMaintainer',
                    'pkgname'    => '- Source'
                } }
        },
    ] );

my $inst = $model->instance(
    root_class_name => 'Master',
    instance_name   => 'test1'
);
ok( $inst, "created dummy instance" );
$inst->initial_load_stop;

my $root = $inst->config_root;

# order is important. Do no use sort.
eq_or_diff(
    [ $root->get_element_name() ],
    [
        qw/av bv compute_int sav sbv one_var one_wrong_var
            meet_test compute_with_override compute_with_warning
            compute_with_override_and_fix compute_with_override_and_powerless_fix
            compute_with_upstream compute_no_var bar
            foo2 url host with_tmp_var Upstream-Contact Maintainer Source Source2 Licenses
            index_function_target test_index_function OtherMaintainer Vcs-Browser/
    ],
    "check available elements"
);

my ( $av, $bv, $compute_int );
$av = $root->fetch_element('av');
$bv = $root->fetch_element('bv');

ok( $bv, "created av and bv values" );

ok( $compute_int = $root->fetch_element('compute_int'), "create computed integer value (av + bv)" );

no warnings 'once';

my $parser = Parse::RecDescent->new($Config::Model::ValueComputer::compute_grammar);

use warnings 'once';

{
    no warnings qw/once/;
    $::RD_HINT  = 1 if $args->{'rd-hint'};
    $::RD_TRACE = 1 if $args->{'rd-trace'};
}

my $object = $root->fetch_element('one_var');
my $rules  = { bar => '- sbv', };
my $srules = { bv => 'rbv' };

my $ref = $parser->pre_value( '$bar', 1, $object, $rules, $srules );
is( $$ref, '$bar', "test pre_compute parser on a very small formula: '\$bar'" );

$ref = $parser->value( '$bar', 1, $object, $rules, $srules );
is( $$ref, undef, "test compute parser on a very small formula with undef variable" );

$root->fetch_element('sbv')->store('bv');
$ref = $parser->value( '$bar', 1, $object, $rules, $srules );
is( $$ref, 'bv', "test compute parser on a very small formula: '\$bar'" );

$ref = $parser->pre_value( '$replace{$bar}', 1, $object, $rules, $srules );
is( $$ref, '$replace{$bar}', "test pre-compute parser with substitution" );

$ref = $parser->value( '$replace{$bar}', 1, $object, $rules, $srules );
is( $$ref, 'rbv', "test compute parser with substitution" );

my $txt = 'my stuff is  $bar, indeed';
$ref = $parser->pre_compute( $txt, 1, $object, $rules, $srules );
is( $$ref, $txt, "test pre_compute parser with a string" );

my $code = q{&location() =~ /^copyright/ ? $self->grab_value('! control source Source') : '''};
$ref = $parser->pre_compute( $code, 1, $object, $rules, $srules );
$code =~ s/&location\(\)/$object->location/e;
is( $$ref, $code, "test pre_compute parser with code" );

$ref = $parser->compute( $txt, 1, $object, $rules, $srules );
is( $$ref, 'my stuff is  bv, indeed', "test compute parser with a string" );

$txt = 'local stuff is element:&element!';
$ref = $parser->pre_compute( $txt, 1, $object, $rules, $srules );
is( $$ref, 'local stuff is element:one_var!', "test pre_compute parser with function (&element)" );

# In fact, function is formula is handled only by pre_compute.
$ref = $parser->compute( $txt, 1, $object, $rules, $srules );
is( $$ref, $txt, "test compute parser with function (&element)" );

## test integer formula
my $result = $compute_int->fetch;
is( $result, undef, "test that compute returns undef with undefined variables" );

$av->store(1);
$bv->store(2);

$result = $compute_int->fetch;
is( $result, 3, "test result :  computed integer is $result (a: 1, b: 2)" );

eval { $compute_int->store(4); };
ok( $@, "test assignment to a computed value (normal error)" );
print "normal error:\n", $@, "\n" if $trace;

$result = $compute_int->fetch;
is( $result, 3, "result has not changed" );

$bv->store(-2);
$result = $compute_int->fetch;
is( $result, -1, "test result :  computed integer is $result (a: 1, b: -2)" );

ok( $bv->store(4), "change bv value" );
eval { $result = $compute_int->fetch; };
ok( $@, "computed integer: computed value error" );
print "normal error:\n", $@, "\n" if $trace;

is( $compute_int->fetch( check => 'no' ), undef,
    "returns undef when computed integer is invalid and check is no (a: 1, b: -2)" );

is( $compute_int->fetch( check => 'skip' ),
    undef, "test result :  computed integer is undef (a: 1, b: -2)" );

my $s = $root->fetch_element('meet_test');
$result = $s->fetch;
is( $result, undef, "test for undef variables in string" );

my ( $as, $bs ) = ( 'Linus', 'his penguin' );
$root->fetch_element('sav')->store($as);
$root->fetch_element('sbv')->store($bs);
$result = $s->fetch;
is(
    $result,
    'meet Linus and his penguin',
    "test result :  computed string is '$result' (a: $as, b: $bs)"
);

print "test allow_compute_override\n" if $trace;

my $comp_over = $root->fetch_element('compute_with_override');
$bv->store(2);

is( $comp_over->fetch, 3, "test computed value" );
$comp_over->store(4);
is( $comp_over->fetch, 4, "test overridden value" );

my $cwu = $root->fetch_element('compute_with_upstream');

is( $cwu->fetch, undef, "test computed with upstream value" );
is( $cwu->fetch( mode => 'custom' ),   undef, "test computed with upstream value (custom)" );
is( $cwu->fetch( mode => 'standard' ), 3,     "test computed with upstream value (standard)" );
is( $cwu->fetch( mode => 'user' ), 3,     "test computed with upstream value (standard)" );
$cwu->store(4);
is( $cwu->fetch, 4, "test overridden value" );
is( $cwu->fetch( mode => 'user' ), 4,     "test computed with upstream value (standard)" );
my $owv = $root->fetch_element('one_wrong_var');
eval { $owv->fetch; };
ok( $@, "expected failure with one_wrong_var" );
print "normal error:\n", $@, "\n" if $trace;

my $cnv = $root->fetch_element('compute_no_var');
is( $cnv->fetch, 'compute_no_var', "test compute_no_var" );

my $foo2 = $root->fetch_element('foo2');
my $fen  = $foo2->fetch_element('find_node_element_name');
ok( $fen, "created element find_node_element_name" );
is( $fen->fetch, 'foo2', "did find node element name" );

my $cen = $foo2->fetch_element('check_node_element_name');
ok( $cen, "created element check_node_element_name" );
is( $cen->fetch, 1, "did check node element name" );

my $slave_av = $root->fetch_element('bar')->fetch_element('av');
my $slave_bv = $root->fetch_element('bar')->fetch_element('bv');

is( $slave_av->fetch, $av->fetch, "compare slave av and av" );
is( $slave_bv->fetch, $bv->fetch, "compare slave bv and bv" );

$root->fetch_element('url')->store('http://foo.bar/baz.html');

my $h = $root->fetch_element('host');

is( $h->fetch, 'foo.bar', "check extracted host" );

$root->fetch_element( name => 'Maintainer', check => 'no' )->store_set( [qw/foo bar baz/] );

# reset to check if migration is seen as a change to be saved
$inst->clear_changes;
is( $inst->needs_save, 0, "check needs save before migrate" );
is( $root->grab_value( step => 'Upstream-Maintainer:0', check => 'no' ),
    'foo', "check migrate_from first stage" );
is( $root->grab_value( step => 'Upstream-Contact:0' ), 'foo', "check migrate_from second stage" );
is( $inst->needs_save, 2, "check needs save after migrate" );
print join( "\n", $inst->list_changes("\n") ), "\n" if $trace;

$root->fetch_element( name => 'Original-Source-Location', check => 'no' )->store('foobar');
is( $root->grab_value( step => 'Source' ), 'foobar', "check migrate_from with undef_is" );

subtest "check Source2 compute with undef_is" => sub {
    my $v;
    my $xp = Test::Log::Log4perl->expect([ 'User', (warn => qr/deprecated/) x 2]);
    $v = $root->grab_value( step => 'Source2' );
    is( $v, 'foobar', "check result of compute with undef_is" );
};

foreach (qw/bar foo2/) {
    my $path = "$_ location_function_in_formula";
    is( $root->grab_value($path), $path, "check &location with $path" );
}

# test formula with tmp variable
my $tmph = $root->fetch_element('with_tmp_var');

is( $tmph->fetch, 'foo.bar', "check extracted host with temp variable" );

my $lic_gpl = $root->grab('Licenses:"GPL-1+"');
is( $lic_gpl->grab_value('text'), "yada yada GPL-1+\nyada yada",
    "check replacement with &index()" );

is( $lic_gpl->grab('text')->fetch_custom, undef,
    "check computed custom value" );

$lic_gpl->grab('text')->store($lic_gpl->grab_value('text'));
is( $lic_gpl->grab('text')->fetch_custom, undef,
    "check computed custom value after storing same value" );

is( $root->grab_value('Licenses:PsF text'),       "", "check missing replacement with &index()" );
is( $root->grab_value('Licenses:"MPL-1.1" text'), "", "check missing replacement with &index()" );

is( $root->grab_value('Licenses:"MPL-1.1" short_name_from_index'),
    "MPL-1.1", 'evaled &index($holder)' );

$root->load('index_function_target:foo name=Bond007');
is(
    $root->grab_value('test_index_function:foo name'),
    "Bond007 is my name",
    'variable with &index(-)'
);

$root->load(
    'OtherMaintainer="Debian Ruby Extras Maintainers <pkg-ruby-extras-maintainers@lists.alioth.debian.org>" Source=ruby-pygments.rb'
);
is(
    $root->grab_value("Vcs-Browser"),
    'http://anonscm.debian.org/gitweb/?p=pkg-ruby-extras/packages/ruby-pygments.rb.git',
    'test compute with complex regexp formula'
);

$root->load(
    'OtherMaintainer="Debian Perl Group <pkg-perl-maintainers@lists.alioth.debian.org>" Source=libconfig-model-perl'
);
is(
    $root->grab_value("Vcs-Browser"),
    'http://anonscm.debian.org/gitweb/?p=pkg-perl/packages/libconfig-model-perl.git',
    'test compute with complex regexp formula'
);

# Debian #810768, test a variable containing quote
$root->load(
    q!OtherMaintainer="Bla Bla O'bla <pkg-perl-maintainers@lists.alioth.debian.org>" Source=libconfig-model-perl!
);
is(
    $root->grab_value("Vcs-Browser"),
    'http://anonscm.debian.org/gitweb/?p=pkg-perl/packages/libconfig-model-perl.git',
    'test compute with complex regexp formula'
);

subtest "check warning with computed value and overide" => sub {
    my $xp = Test::Log::Log4perl->expect([ 'User', warn => qr/should be positive/ ]);
    my $cww = $root->fetch_element('compute_with_warning');
    $av->store(-2);
    $bv->store(-1);
    $cww->fetch;
    is($cww->has_warning, 1, "check has_warning after check");
    is($cww->perform_compute, -3);
    is($cww->has_warning, 1, "check has_warning after compute");
    $cww->store(2);
    is($cww->fetch, 2, "check overridden value");
    is($cww->has_warning, 0, "check has_warning after fixing with override");
};

subtest "check warning with overridden computed value" => sub {
    my $xp = Test::Log::Log4perl->expect([ 'User', warn => qr/should be positive/ ]);
    my $cww = $root->fetch_element('compute_with_warning');
    $av->store(2);
    $bv->store(1);
    $cww->fetch;
    is($cww->has_warning, 0, "computed value is fine");
    $cww->store(-2);
    is($cww->has_warning, 1, "overridden value trigges a warning");
    is($cww->fetch_standard, 3, "get standard value (triggers a compute)");
    is($cww->fetch, -2, "overridden value is still there");
    is($cww->has_warning, 1, "check that warning is still present");
    is($cww->perform_compute, 3, "force a compute");
    is($cww->fetch, -2, "overridden value is still there");
    is($cww->has_warning, 1, "check that warning is still present");
};

subtest "check warning with modified compute_with_override_and_fix" => sub {
    my $xp = Test::Log::Log4perl->expect([ 'User', warn => qr/not default value/]);
    my $cwoaf = $root->fetch_element('compute_with_override_and_fix');
    is($cwoaf->fetch, 'def value', "test compute_with_override_and_fix default value");

    # generate the expected warning because value does not match /def/
    $cwoaf->store('oops') ;

    is($cwoaf->fetch, 'oops', "test compute_with_override_and_fix value after fix");
    is($cwoaf->has_warning, 1, "check if bad value has warnings");
    $cwoaf->apply_fixes;
    is($cwoaf->fetch, 'def value', "test compute_with_override_and_fix value after fix");
    is($cwoaf->has_warning, 0, "check if apply fix has cleaned up the warnings");
};

subtest "check warning when applying powerless fix" => sub {
    my $cwoapf = $root->fetch_element('compute_with_override_and_powerless_fix');
    {
        my $xp = Test::Log::Log4perl->expect([ 'User', warn => qr/not good value/]);
        $cwoapf->apply_fixes;
    }

    is($cwoapf->fetch, '/dev/lcd0', "test default value after powerless fix");
};

foreach my $elem (qw/foo2 bar/) {
    foreach my $i (1..3) {
        my $step = $elem.' Licenses:booya short_name_from_above'.$i;
        my $v1 = $root->grab_value($step);
        is($v1,$elem,"test short_name with '$step'");
    }
}

memory_cycle_ok( $model, "test memory cycles" );

done_testing;
