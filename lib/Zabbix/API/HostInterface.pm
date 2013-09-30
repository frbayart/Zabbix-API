package Zabbix::API::HostInterface;

use strict;
use warnings;
use 5.010;
use Carp;

use Params::Validate qw/validate validate_with :types/;

use parent qw/Exporter Zabbix::API::CRUDE/;


use constant {
    INTERFACE_TYPE_AGENT => 1,
    INTERFACE_TYPE_SNMP => 2,
    INTERFACE_TYPE_IPMI => 3,
    INTERFACE_TYPE_JMX => 4
};

our @EXPORT_OK = qw/
INTERFACE_TYPE_AGENT
INTERFACE_TYPE_SNMP
INTERFACE_TYPE_IPMI
INTERFACE_TYPE_JMX
/;


our %EXPORT_TAGS = (
    interface_types => [
        qw/INTERFACE_TYPE_AGENT
        INTERFACE_TYPE_SNMP
        INTERFACE_TYPE_IPMI
        INTERFACE_TYPE_JMX/
    ],
);


sub id {
	
    ## mutator for id

    my ($self, $value) = @_;

    if (defined $value) {

        $self->data->{interfaceid} = $value;
        return $self->data->{interfaceid};

    } else {

        return $self->data->{interfaceid};

    }

}

sub prefix {

    my (undef, $suffix) = @_;

    if ($suffix) {

		if ($suffix eq 'id' or $suffix eq 'ids') {

			return 'interface'.$suffix;

		} else {

	        return 'hostinterface'.$suffix;

		}

    } else {

        return 'hostinterface';

    }

}

sub extension {

    return ( output => 'extend' );

}

sub collides {

    my $self = shift;

    return @{$self->{root}->query(method => $self->prefix('.get'),
                                  params => { filter => { hostid => $self->data->{hostid},
                                                          type => $self->data->{type},
                                                          main => $self->data->{main},
                                                        },
                                              $self->extension })};

}

sub dns {

    my $self = shift;

    return $self->data->{dns} || '';

}

sub ip {

	my $self = shift;

	return $self->data->{ip} || '';

}


sub host {

    ## accessor for host

    my ($self, $value) = @_;

    if (defined $value) {

        croak 'Accessor host called as mutator';

    } else {

        unless (exists $self->{host}) {

            my $host = $self->{root}->fetch_single('Host', params => { hostids => [ $self->data->{hostid} ] });
            $self->{host} = $host;

        }

        return $self->{host};

    }

}

1;
__END__

=pod

Zabbix::API::HostInterface -- Zabbix host interface objects

=head1 SYNOPSIS

  use Zabbix::API::HostInterface;
  # fetch a single host interface by ID
  my $interface = $zabbix->fetch('HostInterface', params => { filter => { interfaceid => 10 } })->[0];
  
  # and delete it
  $interface->delete;
  
  # fetch an interface's host
  my $interface = $zabbix->fetch('HostInterface', params => { filter => { interfaceid => 42 } })->[0];
  my $host_from_interface = $interface->host;
  
  # create a new host interface (local)
    my $interface = Zabbix::API::HostInterface->new(
        root => $zabbix,
        data => {
            'hostid'  => '123',
            'dns'   => 'host.domain.tld',
            'ip'    => '127.0.0.1',
            'main'  => 1,
            'port'  => 10050,
            'type'  => INTERFACE_TYPE_AGENT, 
            'useip' => 1
        },
    );
  # save the new host interface on the server (i.e. 'create' it)
    $interface->push();

=head1 DESCRIPTION

Handles CRUD for Zabbix host objects.

This is a subclass of C<Zabbix::API::CRUDE>; see there for inherited methods.

=head1 METHODS

=over 4

=item dns()

Accessor for the interface dns.

=item ip

Accessor for the host interface ip.

=item host()

Accessor for a local C<host> attribute, which it also happens to set from the
server data if it isn't set already.  The host is an instance of
C<Zabbix::API::Host>.

=item collides()

This method returns a list of hosts colliding (i.e. matching) this one. If there
if more than one colliding interface found the implementation can not know
on which one to perform updates and will bail out.

=back

=head1 SEE ALSO

L<Zabbix::API::CRUDE>.

=head1 AUTHOR

Thierry Sallé <tsalle@uperto.com>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 Devoteam

This library is free software; you can redistribute it and/or modify it under
the terms of the GPLv3.

=cut
