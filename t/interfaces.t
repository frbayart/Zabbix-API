use Test::More;
use Test::Exception;
use Data::Dumper;

use Zabbix::API;

use lib 't/lib';
use Zabbix::API::TestUtils;

if ($ENV{ZABBIX_SERVER}) {

    plan tests => 8;

} else {

    plan skip_all => 'Needs an URL in $ENV{ZABBIX_SERVER} to run tests.';

}

use_ok('Zabbix::API::HostInterface', qw/:interface_types/);

my $zabber = Zabbix::API::TestUtils::canonical_login;

my $hosts = $zabber->fetch('Host', params => { host => 'Zabbix Server',
                                               search => { host => 'Zabbix Server' } });


my $zabhost = $hosts->[0];

my $interfaces = $zabhost->interfaces;

is(@{$interfaces}, 1, '... and a host interface  known to exist can be fetched');

my $interface = $interfaces->[0];

isa_ok($interface, 'Zabbix::API::HostInterface',
       '... and that s an interface');

ok($interface->created,
   '... and it returns true to existence tests');

my $olddns = $interface->data->{dns};

$interface->data->{dns} = 'new.dns';

$interface->push;

$interface->pull;

is($interface->data->{dns}, 'new.dns',
   '... and updated data can be pushed back to the server');

$interface->data->{dns} = $olddns;
$interface->push;

my $new_interface = Zabbix::API::HostInterface->new(root => $zabber,
                    data => {
                        hostid => $zabhost->id,
                        ip     => '127.0.0.1',
                        dns    => '',
                        useip  => 1,
                        main   => 1,
                        type   => 2,
                        port   => 161
                    });

isa_ok($new_interface, 'Zabbix::API::HostInterface',
       '... and a host interface created manually');

eval { $new_interface->push };

if ($@) { diag "Caught exception during creation : $@" };

ok($new_interface->created,
   '... and pushing it to the server creates a new host interface');

eval { $new_interface->delete };

if ($@) { diag "Caught exception on delete : $@" };

ok(!$new_interface->created,
   '... and calling its delete method removes it from the server');

eval { $zabber->logout };
