#!/usr/bin/perl
#
use lib qw(/opt/dinfo/lib/perl);

use strict;
use Cadi::Oracle;
use Cadi::Units;
use Cadi::Persons;
use Cadi::Accreds;

package Cadi::AdminDB;

use vars qw($errmsg);

my  $camiproprop = 4;
my $annuaireprop = 1;
my    $respinfra = 4;

sub new { # Exported
  my $class = shift;
  my  $args = (@_ == 1) ? shift : { @_ } ;
  my  $self = {
          caller => undef,
          errmsg => undef,
         errcode => undef,
        language => 'en',
            utf8 => 1,
         verbose => 0,
            fake => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }  
  warn "new Cadi::AdminDB ()\n" if $self->{verbose};
  
  $self->{accreds} = new Cadi::Accreds ();
  unless ($self->{accreds}) {
    $errmsg = "Accreds database connection error : $self->{accreds}->{errmsg}";
    error ($self, "AdminDB::new: $errmsg");
    return;
  }

  $self->{oracle} = new Cadi::Oracle ();
  unless ($self->{oracle}) {
    $errmsg = "Oracle database connection error : $self->{oracle}->{errmsg}";
    error ($self, "AdminDB::new: $errmsg");
    return;
  }
  bless $self, $class;
}

sub addAccred {
  my ($self, $persid, $unitid) = @_;
  # don't forget to useSciper if necessary.
  return $self->updateAccred ($persid, $unitid);
}

sub updateAccred {
  my ($self, $persid, $unitid) = @_;
  unless ($persid && $unitid) {
    $self->error ("updateAccred: incorrect call : persid = $persid, unitid = $unitid");
    return;
  }
  unless ($persid =~ /^[A-Z\d]\d\d\d\d\d$/) {
    $self->error ("updateAccred: bad sciper : $persid");
    return;
  }
  my $unit = new Cadi::Units ($self)->getUnitInfos ($unitid);
  unless ($unit) {
    $self->error ("updateAccred: Unknown unit : $unitid");
    return;
  }
  
  my $person = new Cadi::Persons ($self)->getPersonInfos ($persid);
  unless ($person) {
    $self->error ("updateAccred: Unknown sciper : $persid");
    return;
  }
  
  my $accreds = $self->{accreds};
  my  $accred = $accreds->getAccred ($persid, $unitid);
  unless ($accred && $accred->{persid}) {
    $self->error ("updateAccred: $accreds->{errmsg}") unless $self->{fake};
    return;
  }

  my $datedeb = undef;
  if ($accred->{datedeb}) {
    $datedeb =  $accred->{datedeb};
    $datedeb =~ s/\s+.*$//;
    my ($y, $m, $d) = split (/-/, $datedeb); 
    $datedeb = sprintf ("%02d.%02d.%04d", $d, $m, $y);
  }
  my $datefin = undef;
  $accred->{datefin} = undef
    if (!$accred->{datefin} || ($accred->{datefin} =~ /^0000/));
  if ($accred->{datefin}) {
    $datefin =  $accred->{datefin};
    $datefin =~ s/\s+.*$//;
    my ($y, $m, $d) = split (/-/, $datefin); 
    $datefin = sprintf ("%02d.%02d.%04d", $d, $m, $y);
  }
  my   $status = $accreds->getStatus   ($accred->{statusid});
  my    $class = $accreds->getClass    ($accred->{classid});
  my $position = $accreds->getPosition ($accred->{posid});
  my ($fctlib, $fct2lib);
  if ($position) {
    $fctlib  = $position->{labelfr};
    $fct2lib = ($person->{gender} eq 'F')
      ? $position->{labelxx}
      : $position->{labelfr};
  }
  my $statuslib = $status->{labelfr};
  my  $classlib = $class->{labelfr};
  my  $camipro = $accreds->getAccredProperty ($accred, 4);
  my $annuaire = $accreds->getAccredProperty ($accred, 1);

  $camipro  = $camipro  ? 'y' : 'n';
  $annuaire = $annuaire ? 'y' : 'n';

  my $ora = $self->{oracle};
  my $sql = qq{
    select SCIPER
      from accreds
     where SCIPER = ?
       and  UNITE = ?
  };
  my $sth = $ora->prepare ($sql);
  unless ($sth) {
    $errmsg = "Oracle database connection error : $ora->{errmsg}";
    $self->error ($errmsg);
    return;
  }
  my $rv = $sth->execute ($persid, $unitid);
  unless ($rv) {
    $errmsg = "Oracle database connection error : $ora->{errmsg}";
    $self->error ($errmsg);
    return;
  }
  my ($scip) = $sth->fetchrow;

  my @values;
  if ($scip) { # Update
    $sql = qq{
      update accreds set
          STATUT = ?,   CLASSE = ?, FONCTION = ?, FONCTION2 = ?,
           ORDRE = ?,  DATEDEB = ?,  DATEFIN = ?,   CAMIPRO = ?, ANNUAIRE = ?
      where SCIPER = ?
        and  UNITE = ?
    };
    @values = (
      $statuslib, $classlib,  $fctlib,  $fct2lib, $accred->{ordre}, 
      $datedeb, $datefin,  $camipro, $annuaire, $persid, $unitid  
    );
  } else { # Add
    $sql = qq{
      insert into accreds
        (SCIPER,    UNITE,   STATUT,  CLASSE,  FONCTION,
         FONCTION2, ORDRE,   DATEDEB, DATEFIN, CAMIPRO, ANNUAIRE)
      values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    };
    @values = (
      $persid, $unitid,  $statuslib, $classlib, $fctlib, $fct2lib, 
      $accred->{ordre}, $datedeb, $datefin, $camipro, $annuaire
    );
  }
  my $sth = $ora->prepare ($sql);
  unless ($sth) {
    $errmsg = "Oracle database connection error : $ora->{errmsg}";
    $self->error ($errmsg);
    return;
  }
  $sth->execute (@values) unless $self->{fake};
  return 1;
}

sub remAccred {
  my ($self, $persid, $unitid) = @_;
  # don't forget to releaseSciper if necessary.
  my $sql = qq{
    delete from accreds
     where sciper = ?
       and  unite = ?
  };
  my $ora = $self->{oracle};
  my $sth = $ora->prepare ($sql);
  unless ($sth) {
    $errmsg = "Oracle database connection error : $DBI::errstr.";
    $self->error ($errmsg);
    return;
  }
  msg ('remAccred', "$persid:$unitid") if $self->{verbose};
  $sth->execute ($persid, $unitid) unless $self->{fake};
  return 1;
}

sub updateAccredsOrder {
  my ($self, $persid) = @_;
  my $accreds = $self->{accreds};
  my  $orders = $accreds->getAccredsOrders ($persid);
  my $sql = qq{
    update accreds
       set  ordre = ?
     where sciper = ?
       and  unite = ?
  };
  my $ora = $self->{oracle};
  my $sth = $ora->prepare ($sql);
  unless ($sth) {
    $errmsg = "Oracle database connection error : $DBI::errstr.";
    $self->error ($errmsg);
    return;
  }
  my @unitids = sort { $orders->{$a} cmp $orders->{$b} } keys %$orders;
  msg ('updateAccredsOrder', "$persid : new order = ". join (':', @unitids))
    if $self->{verbose};

  foreach my $unitid (@unitids) {
    my $order = $orders->{$unitid};
    $sth->execute ($order, $persid, $unitid) unless $self->{fake};
  }
  return 1;
}

sub addRightToPerson {
  my ($self, $persid, $unitid, $rightid) = @_;
  my $right = $self->{accreds}->getRight ($rightid);
  unless ($right) {
    $errmsg = "Unknown rightid : $rightid.";
    $self->error ($errmsg);
    return;
  }
  return 1 unless (($right->{name} eq 'inventaire') || ($right->{name} eq 'controlesf'));
  return $self->resetright ($persid, $right);
}

sub delRightOfPerson {
  my ($self, $persid, $unitid, $rightid) = @_;
  my $right = $self->{accreds}->getRight ($rightid);
  unless ($right) {
    $errmsg = "Unknown rightid : $rightid.";
    $self->error ($errmsg);
    return;
  }
  return 1 unless (($right->{name} eq 'inventaire') || ($right->{name} eq 'controlesf'));
  return $self->resetright ($persid, $right);
}

sub resetright {
  my ($self, $persid, $right) = @_;
  my     $rightid = $right->{id};
  my   $rightname = $right->{name};
  my $unitsrights = $self->{accreds}->getUnitsRights ($persid, $rightid);

  my $oracle = new Cadi::Oracle ();
  my $rc = $oracle->begin_work;
  unless ($rc) {
    error ("resetright: unable to start transaction : $oracle->errstr");
    return;
  }
  my $sql = qq{
    delete from accdroits
     where sciper = ?
       and  droit = ?
  };
  my $sth = $oracle->prepare ($sql);
  unless ($sth) {
    $errmsg = "Oracle database connection error : $oracle->errstr.";
    return;
  }
  $sth->execute ($persid, $right->{name});

  foreach my $unitid (keys %$unitsrights) {
    my $val = $unitsrights->{$unitid};
    my $sql = qq{insert into accdroits values (?, ?, ?, ?)};
    my $sth = $oracle->prepare ($sql);
    unless ($sth) {
      $oracle->rollback;
      error ("resetright: Unable to add right in Oracle1 : $oracle->errstr");
      return;
    }
    my $rv = $sth->execute ($rightname, $persid, $unitid, $val);
    unless ($rv) {
      $oracle->rollback;
      error ("resetright: Unable to add right in Oracle2 : $oracle->errstr");
      return;
    }
  }
  $oracle->commit || do {
    error ("resetright: Unable to commit Oracle updates : $oracle->errstr");
    return;
  };
  return 1;
}

sub addRoleToPerson {
  my ($self, $persid, $unitid, $roleid) = @_;
  my $role = $self->{accreds}->getRole ($roleid);
  unless ($role) {
    $errmsg = "Unknown roleid : $roleid.";
    $self->error ($errmsg);
    return;
  }
  my @adminrightids = $self->{accreds}->getAdminRights ($roleid);
  foreach my $rightid (@adminrightids) {
    my $right = $self->{accreds}->getRight ($rightid);
    next unless $right;
    next unless (
      ($right->{name} eq 'inventaire') ||
      ($right->{name} eq 'controlesf')
    );
    return unless $self->resetright ($persid, $right);
  }
  
  if ($role->{name} eq 'respinfra') {
    my $oracle = new Cadi::Oracle ();
    my $sql = qq{insert into accdroits values (?, ?, ?, ?)};
    my $sth = $oracle->prepare ($sql);
    unless ($sth) {
      error ("addRoleToPerson: Oracle query1 failed for $persid, $unitid, $roleid.");
      return;
    }
    my $rv = $sth->execute ('respinfra', $persid, $unitid, 'y');
    unless ($rv) {
      error ("addRoleToPerson: Oracle query2 failed for $persid, $unitid, $roleid.");
      return;
    }
  }
  return 1;
}

sub delRoleOfPerson {
  my ($self, $persid, $unitid, $roleid) = @_;
  my $role = $self->{accreds}->getRole ($roleid);
  unless ($role) {
    $errmsg = "Unknown roleid : $roleid.";
    $self->error ($errmsg);
    return;
  }
  my @adminrightids = $self->{accreds}->getAdminRights ($roleid);
  foreach my $rightid (@adminrightids) {
    my $right = $self->{accreds}->getRight ($rightid);
    next unless $right;
    my $rightname = $right->{name};
    next unless (
      ($rightname eq 'inventaire') ||
      ($rightname eq 'controlesf')
    );
    return unless $self->resetright ($persid, $right);
  }
  if ($role->{name} eq 'respinfra') {
    my $oracle = new Cadi::Oracle ();
    my $sql = qq{
      delete from accdroits
       where  droit = ?
         and sciper = ?
         and  unite = ?
    };
    my $sth = $oracle->prepare ($sql);
    unless ($sth) {
      error ("delRoleOfPerson: Oracle query1 failed for $persid, $unitid, $roleid.");
      return;
    }
    my $rv = $sth->execute ('respinfra', $persid, $unitid);
    unless ($rv) {
      error ("delRoleOfPerson: Oracle query2 failed for $persid, $unitid, $roleid.");
      return;
    }
  }
  return 1;
}

sub setAccredProperty {
  my ($self, $persid, $unitid, $propid) = @_;
  my $propname;
  if    ($propid == $annuaireprop) { $propname = 'annuaire'; }
  elsif ($propid ==  $camiproprop) { $propname = 'camipro';  }
  unless ($propname) {
    $errmsg = "Unknown propid : $propid.";
    $self->error ($errmsg);
    return;
  }
  my $accred = $self->{accreds}->getAccred ($persid, $unitid);
  unless ($accred) {
    error ("setAccredProperty: Unknown accred : $persid, $unitid");
    return;
  }
  my $propvalue = $self->{accreds}->getAccredProperty ($accred, $propid) ? 'y' : 'n';
  my $sql = qq{
    update accreds
       set $propname = ?
     where    sciper = ?
       and     unite = ?
  };
  my $sth = $self->{oracle}->prepare ($sql);
  unless ($sth) {
    error ("setAccredProperty: Oracle query1 failed for $persid, $unitid, $propvalue");
    return;
  }
  my $rv = $sth->execute ($propvalue, $persid, $unitid);
  unless ($rv) {
    error ("setAccredProperty: Oracle query2 failed for $persid, $unitid, $propvalue");
    return;
  }
  return 1;
}

sub errmsg {
  my $self = shift;
  return $self->{errmsg};
}

sub msg {
  my ($sub, @msgs) = @_;
  warn scalar localtime, " Cadi::AdminDB::$sub: ", join (', ', @msgs), "\n";
}

sub error {
  my ($self, @msgs) = @_;
  $errmsg = join (',', @msgs);
  $self->{errmsg} = $errmsg if $self;
  warn scalar localtime, " AdminDB::$errmsg\n";
  return;
}



1;
