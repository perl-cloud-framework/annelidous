#!/usr/bin/perl
#
# Annelidous - the flexibile cloud management framework
# Copyright (C) 2009  Eric Windisch <eric@grokthis.net>
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
# 
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

package Annelidous::Connector::Xen;
use base 'Annelidous::Connector';
use Data::Dumper;

# for iscsi grabbing
use JSON;
use LWP::Simple;

use Annelidous::Storage;
use Annelidous::Utility::Email;
#use Annelidous::Transport::SSH;

# Reimager
sub boot_cd {
    my $self=shift;

	# If already running...
	if ($self->status == 1) {
		return;
	}

    my $guest=$self->vm->data;

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create","-n",
    "/dev/null",
    "name='".$guest->{username}."'",
    "kernel='/usr/lib/xen/boot/hvmloader'",
	"build='hvm'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}.",type=ioemu'",
    "disk='file:/opt/disk_images/CentOS-5.3-x86_64-netinstall.iso,hda:cdrom,r'",
    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",sda1,w'",
    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
	"device_model='/usr/lib64/xen/bin/qemu-dm'",
	"boot='d'",
	"serial='pty'",
	#"nographic=1",
    "vcpus=".$guest->{cpu_count});

	#print "\n";
	#print join " ", @exec;
	#print "\n";

    $self->transport()->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ifconfig",$guest->{username},"inet6","add",$guest->{ip6router});
        $self->transport->exec(@exec2);
    }

	return 0;
}


# Launch client guest OS into rescue mode
# takes a client_pool as argument 
sub boot_rescue {
    my $self=shift;
    my $guest=$self->vm->data;

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
	# 64 should always work...
    "kernel='/boot/xen/vmlinuz-64'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip}."'",
    "extra='init=/bin/sh console=xvc0 clocksource=jiffies'",
	# independent_wallclock=1'",
    #"extra='init=/bin/sh console=xvc0'",
    "vcpus=".$guest->{cpu_count});

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		if ( $dev->{'-description'} =~ /root/i ) {
			push @exec, "root='/dev/".$dev->{'-dev'}." ro'";
		}
		push @exec, "disk='phy:".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	}

    $self->transport()->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ifconfig","inet6","add",$guest->{username},$guest->{ip6router});
        #print join " ", @exec2;
        $self->transport->exec(@exec2);
    }
}

# Launch client guest OS...
# takes a client_pool as argument 
sub boot_pvgrub {
    my $self=shift;
	my $console=shift;
	if (defined $console) {
		$console="-c";
	} else {
		$console="-q";
	}

	# If already running...
	if ($self->status == 1) {
		return;
	}

    my $guest=$self->vm->data;
	my $hostname=$guest->{host};

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
	$console,
    "name='".$guest->{username}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
	"kernel='/usr/lib/xen/boot/pv-grub-x86_".$guest->{bitness}.".gz'",
	"extra='(hd0)/boot/grub/menu.lst'",
    "vcpus=".$guest->{cpu_count});

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		if ( $dev->{'-description'} =~ /root/i ) {
			push @exec, "root='/dev/".$dev->{'-dev'}." ro'";
		}
		push @exec, "disk='phy:".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	}

	if ($console) {
		print Dumper @exec;
	}
    $self->transport()->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ifconfig",$guest->{username},"inet6","add",$guest->{ip6router});
        $self->transport->exec(@exec2);
    }

	return 0;
}


# Launch client guest OS...
# takes a client_pool as argument 
sub boot_pv_part {
    my $self=shift;

	print "Booting.\n";

	# If already running...
	if ($self->status == 1) {
		return;
	}

	print "Assigning guest var.\n";
    my $guest=$self->vm->data;

	print "Setting filesystem vars.\n";
	my $hostname=$guest->{host};
    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    "kernel='/boot/xen/vmlinuz-".$guest->{bitness}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    "extra='3 console=xvc0 clocksource=jiffies'",
    "vcpus=".$guest->{cpu_count});

	# Retrieve & assign storage devices
	#foreach my $dev ($self->get_storage()) {
	#	push @exec, "disk='".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	#}

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		if ( $dev->{'-description'} =~ /root/i ) {
			push @exec, "root='/dev/xvda1 ro'";
			push @exec, "disk='phy:".$dev->{'-path'}.",xvda,w'";
		} else {
			push @exec, "disk='phy:".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
		}
	}

	#print "\n";
	#print join " ", @exec;
	#print "\n";

    $self->transport()->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ifconfig",$guest->{username},"inet6","add",$guest->{ip6router});
        $self->transport->exec(@exec2);
    }

	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('boot','[GrokThis] VPS Booted','support@grokthis.net',$guest);

	return 0;
}

sub boot {
	my $self=shift;
	#return $self->_boot(64)
	#print Dumper $self->{_bmethods}->{$self->vm->data->{boot_method}} ;
	$self->{_bmethods}->{$self->vm->data->{boot_method}} ($self);
}

# Launch client guest OS...
# takes a client_pool as argument 
sub boot_pv {
    my $self=shift;

	print "Booting.\n";

	# If already running...
	if ($self->status == 1) {
		return;
	}

	print "Assigning guest var.\n";
    my $guest=$self->vm->data;

    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    "kernel='/boot/xen/vmlinuz-".$guest->{bitness}."'",
    "extra='3 console=xvc0 clocksource=jiffies'",
    "vcpus=".$guest->{cpu_count});

	#print "\n";
	#print join " ", @exec;
	#print "\n";

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		if ( $dev->{'-description'} =~ /root/i ) {
			push @exec, "root='/dev/".$dev->{'-dev'}." ro'";
		}
		push @exec, "disk='phy:".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	}
	#print Dumper @exec;
	#print Dumper $guest;
	#exit 0;

    $self->transport()->exec(@exec);

    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
    if ($guest->{'ip6router'}) {
        my @exec2=("ifconfig",$guest->{username},"inet6","add",$guest->{ip6router});
        $self->transport->exec(@exec2);
    }

	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('boot','[GrokThis] VPS Booted','support@grokthis.net',$guest);

	return 0;
}

sub get_storage {
	#print Dumper @storage;
	my $self=shift;
	return $self->storage->get_storage();
}

sub destroy {
    my $self=shift;
    my $ret= $self->transport->exec("xm","destroy",$self->vm->data->{username});
	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('destroy','[GrokThis] VPS Powered Off (forcefully)','support@grokthis.net',$self->vm->data);
	return $ret;
}

sub shutdown {
    my $self=shift;
    my $ret=$self->transport->exec("xm","shutdown",$self->vm->data->{username});

	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('shutdown','[GrokThis] VPS Shutdown','support@grokthis.net',$self->vm->data);

	return $ret;
}

sub status {
    my $self=shift;
	#if ($self->_locked) {
	#	return;
	#}
    my $ret=${$self->transport->exec("xm","list",$self->vm->data->{username})}[0];
	return ($ret)?0:1;
}

sub uptime {
    my $self=shift;
    return ${$self->transport->exec("xm","uptime",$self->vm->data->{username})}[1];
}

sub console {
    my $self=shift;
    return $self->transport->tty("xm","console",$self->vm->data->{username});
}

sub reimage {
    my $self=shift;
	my @ip4=split (/ /, $self->vm->data->{ip4});
	my $ip=$ip4[0];
    return $self->transport->tty("/usr/bin/gt-xm-reimage",$self->vm->data->{username},$self->vm->data->{username},$self->vm->data->{memory},$ip);
}

sub pause {
    my $self=shift;
    return $self->transport->exec("xm","pause",$self->vm->data->{username});
}

sub unpause {
    my $self=shift;
    return $self->transport->exec("xm","unpause",$self->vm->data->{username});
}

sub _lock {
    my $self=shift;
    my $guest=$self->vm->data;
	if ($self->_locked) {
		return;
	}
	# Create the lock file.
    $self->transport->exec("touch",sprintf("/backup/%s.lck",$guest->{username}));
	return 0;
}

sub _locked {
    my $self=shift;
    my $guest=$self->vm->data;
    my $lck=$self->transport->exec("ls",sprintf("/backup/%s.lck",$guest->{username}));
	if (! $lck[0]) { # == 0) {
		return 0;
	}
	return;
}

sub _unlock {
    my $self=shift;
    my $guest=$self->vm->data;
	#if ($self->_locked) {
		$self->transport->exec("rm",sprintf("/backup/%s.lck",$guest->{username}));
		return 0;
	#}
	#return;
}

sub archive {
    my $self=shift;

	if (! $hostname =~ /(^rorschach|^fury|226$|235$)/i) {
		# Only "new" systems have NFS built in, so limit old ones for now.
		print "Error: this host node does not yet support archives.\n";
		return;
	}

    my $guest=$self->vm->data;
	my $hostname=$guest->{host};

	# exit if locked
    if ($self->_locked) {
		return;
	}
	# Create the lock file.
    $self->_lock;

	# Backup the system memory and shutdown.
    $self->transport->exec("xm","save",$guest->{username},sprintf("/backup/%s.save",$guest->{username}));

    # If the above fails, the instance is still running (and we'll exit)
    if ($self->status == 1) {
        return;
    }

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		# Archive the disk data
		$self->transport->tty("dd", sprintf("if=%s",$dev->{'-path'}),"bs=8M","|","pv","-s",$guest->{'memory'}*64*1024*1024,"|","lzop","|","uuencode","-m","/dev/stdout","|","dd",sprintf("of=/backup/%s.%s",$guest->{username},$dev->{'-dev'}),"bs=8M");
	}

    # The disk backup might have taken a really long time. Just double-check the system status.
    if ($self->status == 1) {
        return;
    }

	# Restore operation and remove lock!
	$self->transport->exec("xm","restore",sprintf("/backup/%s.save",$guest->{username}));
	$self->_unlock;

	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('archive','[GrokThis] Archive Complete','support@grokthis.net',$guest);
	return 0;
}

sub restore {
    my $self=shift;

    my $guest=$self->vm->data;
	my $hostname=$guest->{host};

	if (! $hostname =~ /(^rorschach|^fury|226$|235$)/i) {
		# Only "new" systems have NFS built in, so limit old ones for now.
		print "Error: this host node does not yet support archives.\n";
		return;
	}

	# exit if locked or running
	my $state=$self->status;
    if ($state == 1) {
		return;
	}

	# Create the lock file.
    $self->_lock;

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		# Archive the disk data
		$self->transport->tty("dd",sprintf("if=/backup/%s.%s",$guest->{username},$dev->{'-dev'}),"bs=8M","|","uudecode","|","lzop","-dc","|","pv","-s",$guest->{'memory'}*64*1024*1024,"|","dd",sprintf("of=%s",$dev->{'-path'}),"bs=8M");
	}

	$self->transport->exec("xm","restore",sprintf("/backup/%s.save",$guest->{username}));
	
	$self->_unlock;

	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('restore','[GrokThis] Archive Restored','support@grokthis.net',$guest);
	return 0;
}


#sub console {
#    my $self=shift;
#    # TODO: IMPLEMENT Xen Console
#    # provided is a suggested layout for this method...
#    #my $cap=new Annelidous::Capabilities;
#    #$cap->add("serial");
#    # Get the console here.
#    #$self->transport->exec("xm");
#    #if () {
#    #    $cap->add("tty");
#    #} else {
#    #    $cap->add("vnc");
#    #}
#}

sub boot_methods {
	my $self=shift;
}

sub new {
	my $invocant = shift;
	my $class   = ref($invocant) || $invocant;
	my $self={
	    -transport=>'Annelidous::Transport::SSH',
	    -vm=>undef,
	    -storage=>undef,
	    @_
	};
	bless $self, $class;

	if (defined($self->{-vm})) {
		$self->vm($self->{-vm});
	}
	if (defined($self->{-storage})) {
		$self->storage($self->{-storage});
	}


	$self->{_bmethods}={};
	$self->{_bmethods}->{pv} = \&boot_pv;
	$self->{_bmethods}->{pvgrub} = \&boot_pv_grub;
	$self->{_bmethods}->{pvgrub_part} = \&boot_pvgrub_part;
	$self->{_bmethods}->{pv_part} = \&boot_pv_part;

	$self->{_bmethods}->{cdrom} = \&boot_cd;
	$self->{_bmethods}->{rescue} = \&boot_rescue;

	$self->transport($self->{-transport},{-host=>$self->vm->get_host});
	return $self;
}

1;
