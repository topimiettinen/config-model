# -*- cperl -*-

use warnings;

use ExtUtils::testlib;
use Test::More;
use Test::Memory::Cycle;
use Config::Model;
use Data::Dumper;
use Test::Log::Log4perl;

use Config::Model::Tester::Setup qw/init_test setup_test_dir/;

use warnings;
use strict;

my ($model, $trace) = init_test();


my @rules = (
    F => { choice => [qw/A B C F F2/], default => 'F' },
    G => { choice => [qw/A B C G G2/], default => 'G' } );

my @args = (
    value_type => 'enum',
    mandatory  => 1,
    choice     => [qw/A B C/] );

$model->create_config_class(
    name    => "Master",
    element => [
        enum => {
            type       => 'leaf',
            class      => 'Config::Model::Value',
            value_type => 'enum',
            choice     => [qw/F G H/],
            default    => undef
        },
        wrong_syntax_rule => {
            type  => 'leaf',
            class => 'Config::Model::Value',
            warp  => {
                follow => '- enum',
                rules  => [ F => [ default => 'F' ] ]
            },
            @args
        },
        warped_object => {
            type  => 'leaf',
            class => 'Config::Model::Value',
            @args,
            warp => {
                follow => '- enum',
                rules  => \@rules
            }
        },
        recursive_warped_object => {
            type  => 'leaf',
            class => 'Config::Model::Value',
            @args,
            warp => { follow => '- warped_object', rules => \@rules }
        },
        [qw/w2 w3/] => {
            type  => 'leaf',
            class => 'Config::Model::Value',
            @args,
            warp => { follow => '- enum', rules => \@rules },
        },
        'Standards-Version' => {
            'default' => '4.1.0',
            'type' => 'leaf',
            'value_type' => 'uniline',
            'warn_unless' => {
                'current' => {
                    'code' => '$_ eq $self->_fetch_std;',
                    'fix' => '$_ = undef; # restore default value',
                    'msg' => q!Current standards version is '$std_value'!
                }
            }
        },
        Priority => {
            'choice' => ['required', 'important', 'standard', 'optional', 'extra'],
            'default' => 'optional',
            'type' => 'leaf',
            'value_type' => 'enum',
            'warp' => {
                'follow' => {
                    'std_ver' => '- Standards-Version'
                },
                'rules' => [
                    q!$std_ver ge '4.0.1'! => {'replace' => {'extra' => 'optional'}}
                ]
            }
        },

    ],    # dummy class
);

# check model content
my $canonical_model = $model->get_element_model( 'Master', 'warped_object' );
is_deeply(
    $canonical_model->{warp},
    {
        'follow' => { 'f1' => '- enum' },
        'rules'  => [
            '$f1 eq \'F\'',
            {
                'default' => 'F',
                'choice'  => [ 'A', 'B', 'C', 'F', 'F2' ]
            },
            '$f1 eq \'G\'',
            {
                'default' => 'G',
                'choice'  => [ 'A', 'B', 'C', 'G', 'G2' ] } ]
    },
    "check munged warp arguments"
);

my $inst = $model->instance(
    root_class_name => 'Master',
    instance_name   => 'test1'
);
ok( $inst, "created dummy instance" );

my $root = $inst->config_root;

my $tlogger = Test::Log::Log4perl->get_logger("User");

my ( $w1, $w2, $w3, $bad_w, $rec_wo, $t );

eval { $bad_w = $root->fetch_element('wrong_syntax_rule'); };
ok( $@, "set up warped object with wrong rules syntax" );
print "normal error:\n", $@, "\n" if $trace;

eval { $t = $bad_w->fetch; };
ok( $@, "wrong rules semantic warped object blows up" );
print "normal error:\n", $@, "\n" if $trace;

ok( $w1 = $root->fetch_element('warped_object'), "set up warped object" );

eval { my $str = $w1->fetch; };
ok( $@, "try to read warped object while warp master is undef" );
print "normal error:\n", $@, "\n" if $trace;

my $warp_master = $root->fetch_element('enum');
is( $warp_master->store('F'), 1,   "store F in warp master" );
is( $w1->fetch,               'F', "read warped object default value" );

is( $w1->store('F2'), 1,    "store F2 in  warped object" );
is( $w1->fetch,       'F2', "and read" );

ok( $rec_wo = $root->fetch_element('recursive_warped_object'), "set up recursive_warped_object" );

eval { my $str = $rec_wo->fetch; };
ok( $@, "try to read recursive warped object while its warp master is F2" );
print "normal error:\n", $@, "\n" if $trace;

eval { $t = $rec_wo->fetch; };
ok( $@, "recursive_warped_object blows up" );
print "normal error:\n", $@, "\n" if $trace;

is( $w1->store('F'), 1,   "store F in warped object" );
is( $rec_wo->fetch,  'F', "read recursive_warped_object: default value was set by warp master" );

$warp_master->store('G');
is( $w1->fetch, 'G', "warp 'enum' so that F2 value is clobbered (outside new choice)" );

$w1->store('A');
$warp_master->store('F');
is( $w1->fetch, 'A',
    "set value valid for both warp, warp w1 to G and test that the value is still ok" );

$w2 = $root->fetch_element('w2');
$w3 = $root->fetch_element('w3');

is( $w2->fetch, 'F', "test unset value for w2 after setting warp master" );
is( $w3->fetch, 'F', "idem for w3" );

$warp_master->store('G');
is( $w1->fetch, 'A', "set warp master to G and test unset value for w1 ... 2 and w3" );
is( $w2->fetch, 'G', "... and w2 ..." );
is( $w3->fetch, 'G', "... and w3" );

my $stdv = $root->fetch_element('Standards-Version');
my $prio = $root->fetch_element('Priority');

my $store_with_log_test = sub {
    my $v = shift;
    Test::Log::Log4perl->start(ignore_priority => 'info');
    $tlogger->warn(qr/Current standards version/);
    $stdv->store($v);
    Test::Log::Log4perl->end("Test that store('$v') logs okay");
};

$store_with_log_test->('3.9.8');

$prio->store('extra');
is($prio->fetch, 'extra', "check value with old std_version");

$stdv->apply_fixes;
is($prio->fetch, 'optional', "check value with new std_version");
is($stdv->fetch, '4.1.0', "check std_v default value");

$store_with_log_test->('3.9.8');
$prio->store('extra');
is($prio->fetch, 'extra', "check value with old std_version (2)");

$store_with_log_test->('4.0.2');
is($prio->fetch, 'optional', "check value with new std_version (2)");

$stdv->apply_fixes;
is($prio->fetch, 'optional', "check value with new std_version (2)");

memory_cycle_ok($model, "check memory cycles");

done_testing;
