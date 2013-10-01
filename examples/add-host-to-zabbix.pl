#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;

use Getopt::Long::Descriptive;
use Log::Log4perl;
use YAML;
use Zabbix::API;


my ($opt, $usage) = describe_options(
    'perl add-host-to-zabbix.pl %o',
    [ 'host=s', 'host' ],
	[ 'group=s@', 'Specify the host group.' ],
	[ 'template=s@', 'Link a template to this host.' ],
	[ 'interface=s@', 'add an interface to host (format : "type:ip:dns:useip:port:main",
		where type can be 1 for AGENT, 2 for SNMP, 3 for JMX or 4 for IPMI)' ],
	[ 'csv=s', 'CVS file to load. The format should be like 
		"host:groups (comma separated):templates (comma separated):interface-type:interface-ip:interface-dns:useip:interface-port:main"' ],
	[ 'zabbix-config=s', 'where to find the Zabbix::API configuration file.', { required => 1 } ],
    [ 'l4p-config=s', 'Log::Log4perl configuration file', { required => 1 } ],
);


### Init Logger
Log::Log4perl::init($opt->l4p_config);
my $logger = Log::Log4perl->get_logger;

### Logfile method in case of l4p-config need it
sub logfile {
	if ($opt->host) {
		return $opt->host.'.log';
	} else {
		return 'output.log';
	}
}

if (not defined $opt->host and not defined $opt->group
	and not defined $opt->template and not defined $opt->interface
	and not defined $opt->csv) {
	print $usage;
	exit;
}

### Connection to Zabbix API
my $config = YAML::LoadFile($opt->zabbix_config);
if ($config->{host} !~ /api_jsonrpc.php$/) {
	$config->{host} .= "/api_jsonrpc.php";
}
my $zabber = Zabbix::API->new(server => $config->{host});

eval { $zabber->login(user => $config->{user}, password => $config->{password}) };

if ($@) {

    my $error = $@;
    die "Could not log in: $error";

}

my $api_version = $zabber->api_version;
$logger->debug(sprintf("Connected to Zabbix API version %s", $api_version));


my %hosts;
if ($opt->csv) {

	$logger->info(sprintf("Loading csv file %s..", $opt->csv));

	open my $fh, '<', $opt->csv or die sprintf("Can't open csv file %s : %s", $opt->csv, $!);
	my @file = <$fh>;
	close $fh;
	for my $line (@file) {
		chomp $line;
		next if $line =~ /^#/;
		my ($host, $group, $template, $interface_type, $ip, $dns, $useip, $port, $main) = split(':', $line);

		my (@groups) = split(',', $group);
		my (@templates) = split(',', $template);

		$hosts{$host}{groups} = \@groups;
		$hosts{$host}{templates} = \@templates;

		push @{$hosts{$host}{interfaces}}, {
			type => $interface_type,
			ip => $ip,
			dns => $dns,
			useip => $useip,
			port => $port,
			main => $main
		};
	}

	$logger->info(sprintf("Found %d host in csv file.", scalar keys %hosts));

} else {

	$hosts{$opt->host}{groups} = $opt->group;
	$hosts{$opt->host}{templates} = $opt->template;

	for my $if (@{$opt->interface}) {

		my ($interface_type, $ip, $dns, $useip, $port, $main) = split(':', $if);

		push @{$hosts{$opt->host}{interfaces}}, {
	        type => $interface_type,
    	    ip => $ip,
        	dns => $dns,
	        useip => $useip,
    	    port => $port,
        	main => $main
	    };
	}
}


for my $host (keys %hosts) {

### Testing if tempates exists
	my @templates;
	for my $t (@{$hosts{$host}{templates}}) {

		my $zbx_template = $zabber->fetch_single('Template', params => { filter => { host => [ $t ] } });

		if (not defined $zbx_template) {

			$logger->logdie(sprintf("Error : Template %s doesn't exists", $t));

		} else {

			$logger->info(sprintf("Found template %s", $t));

			push @templates, { templateid => $zbx_template->id };

		}
	
	}


###	Testing if hostgroups exists
	my @hostgroups;
	for my $g (@{$hosts{$host}{groups}}) {

		my $zbx_group = $zabber->fetch_single('HostGroup', params => { filter => { name => $g } });

		if (not defined $zbx_group) {

			$logger->info(sprintf("Host Group %s doesn't exists in Zabbix. Creating It.", $g));

			$zbx_group = Zabbix::API::HostGroup->new(
				root => $zabber,
				data => {
					name => $g
				}
			);

			eval { $zbx_group->push };
			if ($@) {
				$logger->logdie(sprintf("Problem during HostGroup %s creation : %s",$g, $@));
			}
		} else {

			$logger->info(sprintf("HostGroup %s already exists.", $g));

		}
		push @hostgroups, { groupid => $zbx_group->id };
	}


### Testing if host exists
	my $zbx_host = $zabber->fetch_single('Host', params => { filter => { host => $host } });
	if (not defined $zbx_host) {

		$logger->info(sprintf("Creating Zabbix host %s", $host));

		my $zbx_host = Zabbix::API::Host->new(
			root => $zabber,
			data => {
				host => $host,
				groups => \@hostgroups,
				templates => \@templates,
				interfaces => $hosts{$host}{interfaces}
			}
		);

		eval { $zbx_host->push; };
		if ($@) {
			$logger->logdie(sprintf("Problem during Host %s creation : %s", $host, $@));
		}

	} else {

		$logger->info(sprintf("Host %s already exists, skipping.", $host));

	}
					
}


### Logout
eval { $zabber->logout };

if ($@) {

    my $error = $@;

    given ($error) {

        when (/Invalid method parameters/) {
            # business as usual
        }

        default {

            die "Unexpected exception while logging out: $error";

        }

    }

}

