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

sub new {
	my $invocant = shift;
	my $class   = ref($invocant) || $invocant;
	my $self={
	    -transport=>'Annelidous::Transport::SSH',
	    -vm=>undef,
	    @_
	};
	bless $self, $class;

	if (defined($self->{-vm})) {
		$self->vm($self->{-vm});
	}

	$self->transport($self->{-transport},{-host=>$self->vm->get_host});
	return $self;
}

# Reimager
sub bootcd {
    my $self=shift;

	# If already running...
	if ($self->status == 1) {
		return;
	}

    my $guest=$self->vm->data;

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];
#	my $hostname=$self->vm->get_host();
#	my $guestVG="XenDomains";
#	my $swapVG="XenDomains";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		print "Hostname is $hostname\n";
#		$guestVG="SanXenDomains";
#		$swapVG="XenSwap";
#	}

	my $hostname=$guest->{host};
	my $guestVG="XenDomains";
	my $swapVG="XenDomains";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

    $self->transport()->exec('lvchange','-ay',$guestVG.'/'.$guest->{username});
    $self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
    $self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');

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
    #"disk='phy:mapper/XenDomains-".$guest->{username}.",sda1,w'",
    #"disk='phy:mapper/XenDomains-".$guest->{username}."swap,sda2,w'",
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
sub rescue {
    my $self=shift;
    my $guest=$self->vm->data;

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];
	my $hostname=$self->vm->get_host();
	my $guestVG="XenDomains";
	my $swapVG="XenDomains";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    "kernel='/boot/xen/vmlinuz-".$guest->{bitness}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip}."'",
    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",sda1,w'",
    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
    #"disk='phy:mapper/XenDomains-".$guest->{username}.",sda1,w'",
    #"disk='phy:mapper/XenDomains-".$guest->{username}."swap,sda2,w'",
    "root='/dev/sda1 ro'",
    "extra='init=/bin/sh console=xvc0 clocksource=jiffies'",
	# independent_wallclock=1'",
    #"extra='init=/bin/sh console=xvc0'",
    "vcpus=".$guest->{cpu_count});
    #print join " ", @exec;
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
#sub boot32 {
#    my $self=shift;
#
#	# If already running...
#	if ($self->status == 1) {
#		return;
#	}
#
#    my $guest=$self->vm->data;
#
#    #my @userinfo=getpwent($guest->{username});
#    #my $homedir=$userinfo[7];
##	my $hostname=$self->vm->get_host();
##	my $guestVG="XenDomains";
##	my $swapVG="XenDomains";
##	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
##		print "Hostname is $hostname\n";
##		$guestVG="SanXenDomains";
##		$swapVG="XenSwap";
##	}
#
#	my $hostname=$self->vm->get_host();
#	#my $hostname=$guest->{host};
#	my $guestVG="XenDomains";
#	my $swapVG="XenDomains";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		$guestVG="SanXenDomains";
#		$swapVG="XenSwap";
#	} elsif ($hostname =~ /^206/i) {
#		$guestVG="XenDomains";
#		$swapVG="XenDomains";
#	}
#
#    $self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
#    $self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');
#
#    #print "Starting guest: ".$guest->{username}."\n";
#    my @exec=("xm","create",
#    "/dev/null",
#    "name='".$guest->{username}."'",
#    "kernel='/boot/xen/vmlinuz-32'",
#    "memory=".$guest->{'memory'},
#    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
#    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",sda1,w'",
#    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
#    #"disk='phy:mapper/XenDomains-".$guest->{username}.",sda1,w'",
#    #"disk='phy:mapper/XenDomains-".$guest->{username}."swap,sda2,w'",
#    "root='/dev/sda1 ro'",
#    "extra='3 console=xvc0 clocksource=jiffies'",
#	# independent_wallclock=1'",
#    "vcpus=".$guest->{cpu_count});
#	#print "\n";
#	#print join " ", @exec;
#	#print "\n";
#    $self->transport()->exec(@exec);
#
#    # Configure IPv6 router IP for vif (no proxy arp here, we give a whole subnet)
#    if ($guest->{'ip6router'}) {
#        my @exec2=("ifconfig",$guest->{username},"inet6","add",$guest->{ip6router});
#        $self->transport->exec(@exec2);
#    }
#
#	return 0;
#}

# Launch client guest OS...
# takes a client_pool as argument 
sub bootgrub32 {
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

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];
#	my $hostname=$self->vm->get_host();
#	my $guestVG="XenDomains";
#	my $swapVG="XenDomains";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		print "Hostname is $hostname\n";
#		$guestVG="SanXenDomains";
#		$swapVG="XenSwap";
#	}

	my $hostname=$guest->{host};
	my $guestVG="SanXenDomains";
	my $swapVG="XenSwap";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

    $self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
    $self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
	$console,
    "name='".$guest->{username}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",sda1,w'",
    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
	"kernel='/usr/lib/xen/boot/pv-grub-x86_32.gz'",
	"extra='(hd0)/boot/grub/menu.lst'",
    "vcpus=".$guest->{cpu_count});
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
sub bootgrub {
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

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];
#	my $hostname=$self->vm->get_host();
#	my $guestVG="XenDomains";
#	my $swapVG="XenDomains";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		print "Hostname is $hostname\n";
#		$guestVG="SanXenDomains";
#		$swapVG="XenSwap";
#	}

	my $hostname=$guest->{host};
	my $guestVG="SanXenDomains";
	my $swapVG="XenSwap";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

    $self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
    $self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');

    #print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
	$console,
    "name='".$guest->{username}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",sda1,w'",
    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
	"kernel='/usr/lib/xen/boot/pv-grub-x86_64.gz'",
	"extra='(hd0)/boot/grub/menu.lst'",
    "vcpus=".$guest->{cpu_count});
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
sub bootpart {
    my $self=shift;

	print "Booting.\n";

	# If already running...
	if ($self->status == 1) {
		return;
	}

	print "Assigning guest var.\n";
    my $guest=$self->vm->data;

    #my @userinfo=getpwent($guest->{username});
    #my $homedir=$userinfo[7];
#	my $hostname=$self->vm->get_host();
#	my $guestVG="XenDomains";
#	my $swapVG="XenDomains";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		print "Hostname is $hostname\n";
#		$guestVG="SanXenDomains";
#		$swapVG="XenSwap";
#	}

	print "Setting filesystem vars.\n";
	my $hostname=$guest->{host};
	my $guestVG="SanXenDomains";
	my $swapVG="XenSwap";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} else { #if ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

	#print "Building swap.\n";
    #$self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
    #$self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');

    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    "kernel='/boot/xen/vmlinuz-".$guest->{bitness}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    "disk='phy:mapper/".$guestVG."-".$guest->{username}.",xvda,w'",
    "disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sdb1,w'",
    "root='/dev/xvda1 ro'",
    "extra='3 console=xvc0 clocksource=jiffies'",
	# independent_wallclock=1'",
    "vcpus=".$guest->{cpu_count});

	# Retrieve & assign storage devices
	#foreach my $dev ($self->get_storage()) {
	#	push @exec, "disk='".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	#}

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


sub boot32 {
	my $self=shift;
	return $self->_boot(32)
}

sub boot {
	my $self=shift;
	return $self->_boot(64)
}

# Launch client guest OS...
# takes a client_pool as argument 
sub _boot {
    my $self=shift;
	my $bitness=shift;

	print "Booting.\n";

	# If already running...
	if ($self->status == 1) {
		return;
	}

	print "Assigning guest var.\n";
    my $guest=$self->vm->data;

#	print "Setting filesystem vars.\n";
#	my $hostname=$guest->{host};
#	my $devpath="phy:mapper/SanXenDomains-".$guest->{username};
#	my $swapVG="XenSwap";
#	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
#		$devpath="phy:mapper/SanXenDomains-".$guest->{username};
#		$swapVG="XenSwap";
#	} elsif ($hostname =~ /206\.251\.37\.235/) {
#		my $volume="array002/".$guest->{username};
#		my $iss=from_json(get "http://206.251.37.252:8080/iscsitadm/target/".$volume);
#		$devpath="iscsi:".$iss->{$volume}->{'iSCSI Name'};
#		$swapVG="XenSwap";
#	} else {
#		$devpath="phy:mapper/XenDomains-".$guest->{username};
#		$swapVG="XenDomains";
#	}

	#print "Building swap.\n";
    #$self->transport()->exec('lvcreate','-L',$guest->{'memory'}*2,'-n',$guest->{username}."swap",$swapVG);
    #$self->transport()->exec('mkswap','/dev/'.$swapVG.'/'.$guest->{username}.'swap');

    print "Starting guest: ".$guest->{username}."\n";
    my @exec=("xm","create",
    "/dev/null",
    "name='".$guest->{username}."'",
    #"kernel='/boot/xen/vmlinuz-".$guest->{bitness}."'",
    "memory=".$guest->{'memory'},
    "vif='vifname=".$guest->{username}.",ip=".$guest->{ip4}."'",
    #"disk='".$devpath.",sda1,w'",
    #"disk='phy:mapper/".$swapVG."-".$guest->{username}."swap,sda2,w'",
    #"root='/dev/sda1 ro'",

    "kernel='/boot/xen/vmlinuz-".$bitness."'",
    "extra='3 console=xvc0 clocksource=jiffies'",

	#"kernel='/usr/lib/xen/boot/pv-grub-x86_64.gz'",
	#"extra='(hd0)/boot/grub/menu.lst'",

	# independent_wallclock=1'",
    "vcpus=".$guest->{cpu_count});
	#print "\n";
	#print join " ", @exec;
	#print "\n";

	# Retrieve & assign storage devices
	foreach my $dev ($self->get_storage()) {
		if ( $dev->{'-description'} =~ /root/i ) {
			push @exec, "root='/dev/".$dev->{'-dev'}." ro'";
		}
		push @exec, "disk='".$dev->{'-path'}.",".$dev->{'-dev'}.",w'";
	}
	#print Dumper @exec;

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

sub list_storage {
	my $self=shift;
	my @bdevs;
	#push @bdevs, Annelidous::Storage::LVM::new->('sda1', 'Root Filesystem', $guestVG, $self->vm->data->{username});
	#push @bdevs, Annelidous::Storage::LVM::new->('sda2', 'Swap partition', $swapVG, $self->vm->data->{username}."swap");
	#return @bdevs;
}

sub get_storage {
	my $self=shift;
	my @storage=();

	print "Setting filesystem vars.\n";
	my $guest=$self->vm->data;
	my $hostname=$self->vm->data->{host};
	#my $devpath="phy:mapper/SanXenDomains-".$guest->{username};
	#my $swapVG="XenSwap";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		push @storage, Annelidous::Storage->new(
			-class=>'LVM',
			-dev=>'sda1',
			-description=>'Root Filesystem',
			-path=>"phy:mapper/SanXenDomains-".$guest->{username});
		push @storage, Annelidous::Storage->new(
			-class=>'LVM',
			-dev=>'sda2',
			-description=>'Swap Filesystem',
			-path=>"phy:mapper/XenSwap-".$guest->{username}."swap");
	} elsif ($hostname =~ /206\.251\.37\.235/) {
		my $volume="array002/".$guest->{username};
		my $iss=from_json(get "http://206.251.37.252:8080/iscsitadm/target/".$volume);
		push @storage, Annelidous::Storage->new(
			-class=>'iSCSI',
			-dev=>'sda1',
			-description=>'Root Filesystem',
			#-path=>"iscsi:".$iss->{$volume}->{'iSCSI Name'});
			-path=>"phy:/dev/disk/by-path/ip-10.1.0.1:3260-iscsi-".$iss->{$volume}->{'iSCSI Name'}."-lun-0");
		push @storage, Annelidous::Storage->new(
			-class=>'LVM',
			-dev=>'sdb1',
			-description=>'Swap Filesystem',
			-path=>"phy:mapper/XenSwap-".$guest->{username}."swap");
	} else {
		push @storage, Annelidous::Storage->new(
			-class=>'LVM',
			-dev=>'sda1',
			-description=>'Root Filesystem',
			-path=>"phy:mapper/XenDomains-".$guest->{username});
		push @storage, Annelidous::Storage->new(
			-class=>'LVM',
			-dev=>'sda2',
			-description=>'Swap Filesystem',
			-path=>"phy:mapper/XenDomains-".$guest->{username}."swap");
	}
	#print Dumper @storage;
	return @storage;
}

sub destroy {
    my $self=shift;
    my $ret= $self->transport->exec("xm","destroy",$self->vm->data->{username});
	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('destroy','[GrokThis] VPS Powered Off (forcefully)','support@grokthis.net',$guest);
	return $ret;
}

sub shutdown {
    my $self=shift;
    my $ret=$self->transport->exec("xm","shutdown",$self->vm->data->{username});
	my $mutil=Annelidous::Utility::Email->new();
	$mutil->email('shutdown','[GrokThis] VPS Shutdown','support@grokthis.net',$guest);
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

    my $guest=$self->vm->data;
	my $hostname=$guest->{host};
	my $guestVG="XenDomains";
	my $swapVG="XenDomains";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

	if (! $hostname =~ /(^rorschach|^fury|226$)/i) {
		# Only "new" systems have NFS built in, so limit old ones for now.
		print "Error: this host node does not yet support archives.\n";
		return;
	}


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

	# Archive the disk data
	$self->transport->tty("dd", sprintf("if=/dev/%s/%s",$guestVG,$guest->{username}),"bs=8M","|","pv","-s",$guest->{'memory'}*64*1024*1024,"|","lzop","|","uuencode","-m","/dev/stdout","|","dd",sprintf("of=/backup/%s.sda1",$guest->{username}),"bs=8M");
	$self->transport->tty("dd", sprintf("if=/dev/%s/%sswap",$swapVG,$guest->{username}),"bs=8M","|","pv","-s",$guest->{'memory'}*2*1024*1024,"|","lzop","|","uuencode","-m","/dev/stdout","|","dd",sprintf("of=/backup/%s.sda2",$guest->{username}),"bs=8M");

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
	my $guestVG="XenDomains";
	my $swapVG="XenDomains";
	if ($hostname =~ /(rorschach|fury)\.grokthis\.net/i) {
		$guestVG="SanXenDomains";
		$swapVG="XenSwap";
	} elsif ($hostname =~ /^206/i) {
		$guestVG="XenDomains";
		$swapVG="XenDomains";
	}

	if (! $hostname =~ /(^rorschach|^fury|226$)/i) {
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

    $self->transport->tty("dd",sprintf("if=/backup/%s.sda1",$guest->{username}),"bs=8M","|","uudecode","|","lzop","-dc","|","pv","-s",$guest->{'memory'}*64*1024*1024,"|","dd",sprintf("of=/dev/%s/%s",$guestVG,$guest->{username}),"bs=8M");
    $self->transport->tty("dd",sprintf("if=/backup/%s.sda2",$guest->{username}),"bs=8M","|","uudecode","|","lzop","-dc","|","pv","-s",$guest->{'memory'}*64*1024*1024,"|","dd",sprintf("of=/dev/%s/%sswap",$swapVG,$guest->{username}),"bs=8M");
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

1;
