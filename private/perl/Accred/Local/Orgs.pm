#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Orgs.pm
# Description:  Accès à la base de données CADI des unités
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Wed Nov 12 12:07:13 CET 2014
# Revision:     
#
##############################################################################
#
package Accred::Local::Orgs;
#
use strict;
use utf8;

use lib qw(/opt/dinfo/lib/perl);
use Accred::Local::LocalDB;
use Carp;

our $errmsg;

sub new {
  my ($class, $args) = @_;
  my  $self = {
    dinfodb => undef,
    verbose => 0,
      trace => 0,
       utf8 => 0,
  };
  foreach my $arg (keys %$args) {
    $self->{$arg} = $args->{$arg};
  }
  warn scalar localtime, " new Accred::Local::Orgs ().\n" if $self->{verbose};
  unless ($self->{dinfodb}) {
    $self->{dinfodb} = new Accred::Local::LocalDB (
        dbname => 'dinfo',
         trace => $self->{trace},
          utf8 => $self->{utf8},
      tracesql => 0,
    );
    unless ($self->{dinfodb}) {
      $errmsg = "Unable to connect to dinfo db database : $Accred::Local::LocalDB::errmsg";
      return;
    }
  }
  $self->{lang} ||= 'en';
  bless $self, $class;
}

sub getUnits {
  my ($self, $unitid) = @_;
  return unless $unitid;
  
  my $units;
  my  $inunit = ($self->{language} eq 'en') ? 'unit'   : 'l\'unité';
  my @unitids = (ref $unitid eq 'ARRAY') ? @$unitid : ( $unitid );

  if ($self->{dateref}) {
    my @offunits = grep { $_ <  50000 } @unitids;
    if (@offunits) { # Go into full table with history.
      my $in = join (', ', map { '?' } @offunits);
      my $sql = qq{
        select *
           from dinfo.unites1
          where id_unite in ($in)
      };
      my $sth = $self->dbsafequery ($sql, @offunits);
      if ($sth) {
        while (my $offunit = $sth->fetchrow_hashref) {
          $units->{$offunit->{id_unite}} = $offunit;
        }
      }
    }
    @unitids = grep { $_ >= 50000 } @unitids;
  }
  if (@unitids) {
    my $in = join (', ', map { '?' } @unitids);
    my $sql = qq{
      select *
        from dinfo.allunits
        where id_unite in ($in)
    };
    my $sth = $self->dbsafequery ($sql, @unitids);
    if ($sth) {
      while (my $extunit = $sth->fetchrow_hashref) {
        $units->{$extunit->{id_unite}} = $extunit;
      }
    }
  }
  #
  my $results;
  foreach my $id_unite (keys %$units) {
    my     $unit = $units->{$id_unite};
    my $readonly = ($unit->{niveau} <  4) ||
      ($unit->{id_unite} >= 50000 && $unit->{id_unite} < 70000);
    my $labelen = $unit->{libelle_en} || $unit->{libelle};
    my   $label = ($self->{lang} eq 'en') ? $labelen : $unit->{libelle};
    my  $folder = $unit->{niveau} < 4 ? 1 : 0;
    $results->{$unit->{id_unite}} = {
          type => 'Orgs',
            id => $unit->{id_unite},
          name => $unit->{sigle},
        inname => "$inunit $unit->{sigle}",
       altname => "CF $unit->{cf}",
       labelfr => $unit->{libelle},
       labelen => $labelen,
         label => $label,
          path => $unit->{hierarchie},
            cf => $unit->{cf},
         level => $unit->{niveau},
      readonly => $readonly,
        folder => $folder,
    };
  }
  return (ref $unitid eq 'ARRAY') ? $results : $results->{$unitid};
}
*getUnit = \&getUnits;


sub getUnitType {
  my $self = shift;
  return {
              id => 'Orgs',
         package => 'Accred::Local::Orgs',
            icon => '/images/ic-unites.gif',
           order => 1,
    rolesmanager => 'adminroles',
  };
}

sub getRoots {
  my $self = shift;
  my $sql = qq{select * from unites where id_parent = 0};
  my $sth = $self->dbsafequery ($sql) || return;
  my @roots;
  while (my $root = $sth->fetchrow_hashref) {
    my $labelen = $root->{libelle_en} || $root->{libelle};
    my   $label = ($self->{lang} eq 'en') ? $labelen : $root->{libelle};
    push (@roots, {
         type => 'Orgs',
           id => $root->{id_unite},
         name => $root->{sigle},
      labelfr => $root->{libelle},
      labelen => $labelen,
        label => $label,
        level => 1,
         path => '',
    });
  }
  $sth->finish;
  return @roots;
}

sub listChildren {
  my ($self, $unitid) = @_;
  my ($sql, @values);
  if ($self->{dateref} && $unitid < 50000) {
    $sql = qq{
      select *
         from dinfo.unites1
        where  id_parent = ?
    };
    @values = ($unitid);
  } else {
    $sql = qq{
      select *
         from dinfo.allunits
        where id_parent = ?
    };
    @values = ($unitid);
  }
  my $sth = $self->dbsafequery ($sql, @values) or return;

  my @children;
  while (my $child = $sth->fetchrow_hashref) {
    my $labelen = $child->{libelle_en} || $child->{libelle};
    my   $label = ($self->{lang} eq 'en') ? $labelen : $child->{libelle};
    my   $level = $child->{niveau};
    my  $folder = $level < 4 ? 1 : 0;
    push (@children, {
           id => $child->{id_unite},
         name => $child->{sigle},
      labelfr => $child->{libelle},
      labelen => $labelen,
        label => $label,
      altname => "CF $child->{cf}",
        level => $level,
         path => $child->{hierarchie},
         type => 'Orgs',
       folder => $folder,
    });
  }
  $sth->finish;
  return @children;
}

sub listDescendantsIds {
  my ($self, $unitid) = @_;
  my ($sql, @values);
  if ($self->{dateref} && $unitid < 50000) {
    $sql = qq{
      select *
         from dinfo.unites1
        where  id_parent = ?
    };
    @values = ($unitid);
  } else {
    $sql = qq{
      select *
         from dinfo.allunits
        where id_parent = ?
    };
    @values = ($unitid);
  }
  my $sth = $self->dbsafequery ($sql, @values) or return;

  my @childrenids;
  while (my ($childid) = $sth->fetchrow) {
    push (@childrenids, $childid);
    push (@childrenids, $self->listDescendantsIds ($childid));
  }
  $sth->finish;
  return @childrenids;
}

sub getAncestors {
  my ($self, $unitid) = @_;
  my $sql;
  if ($self->{dateref} && $unitid < 50000) {
    $sql = qq{
      select id_parent
        from dinfo.unites1
       where  id_unite = ?
    };
  } else {
    $sql = qq{
      select id_parent
        from dinfo.allunits
       where id_unite = ?
    };
  }
  my @ancestors;
  while ($unitid) {
    my $sth = $self->dbsafequery ($sql, $unitid) || last;
    my ($parentid) = $sth->fetchrow ();
    push (@ancestors, $parentid) if $parentid;
    $unitid = $parentid;
  }
  return @ancestors;
}

sub getAllAncestors {
  my ($self) = @_;
  my $parents;
  my $sql = qq{
    select id_unite, id_parent
      from dinfo.allunits
  };
  my $sth = $self->dbsafequery ($sql);
  while (my ($unitid, $parentid) = $sth->fetchrow) {
    $parents->{$unitid} = $parentid;
  }
  if ($self->{dateref}) {
    my $sql = qq{
      select id_unite, id_parent
        from dinfo.unites1
    };
    my $sth = $self->dbsafequery ($sql);
    while (my ($unitid, $parentid) = $sth->fetchrow) {
      $parents->{$unitid} ||= $parentid;
    }
  }
  my $ancestors;
  foreach my $unitid (keys %$parents) {
    my $parentid = $parents->{$unitid};
    while ($parentid) {
      push (@{$ancestors->{$unitid}}, $parentid);
      $parentid = $parents->{$parentid};
    }
  }
  return $ancestors;
}

sub expandUnitsList {
  my ($self, @unitids) = @_;
  my @retids;
  my $seen;
  foreach my $unitid (@unitids) {
    next if $seen->{$unitid};
    push (@retids, $unitid); $seen->{$unitid} = 1;
    my @subids = $self->getUnitSubtree ($unitid);
    foreach my $subid (@subids) {
      next if $seen->{$subid};
      push (@retids, $subid); $seen->{$subid} = 1;
    }
  }
  return @retids;
}

sub getUnitParent {
  my ($self, $unitid) = @_;
  my ($sql, @values);
  if ($self->{dateref} && $unitid < 50000) {
    $sql = qq{
      select id_parent
        from dinfo.unites1
       where  id_unite = ?
    };
    @values = ($unitid);
  } else {
    $sql = qq{
      select id_parent
        from dinfo.allunits
       where id_unite = ?
    };
    @values = ($unitid);
  }
  my $sth = $self->dbsafequery ($sql, @values) or return;
  my ($parent) = $sth->fetchrow or return;
  $sth->finish;
  return $parent;
}

sub getUnitSubtree {
  my ($self, $unitid) = @_;
  my $sql = qq{
    select id_unite
      from dinfo.allunits
     where (level1 = ? or level2 = ? or level3 = ? or level4 = ?)
       and id_unite != ?
  };
  my $sth = $self->dbsafequery ($sql, $unitid, $unitid, $unitid, $unitid, $unitid) or return;
  my $results = $sth->fetchall_arrayref ([0]);
  my @results = map { $_->[0] } @$results;
  return @results;
}

sub getUnitSubtreeWithInfos {
  my ($self, $unitid) = @_;
  my $sql = qq{
    select id_unite, sigle, hierarchie
      from dinfo.allunits
     where (level1 = ? or level2 = ? or level3 = ? or level4 = ?)
       and id_unite != ?
       and date_debut < now()
       and (date_fin > now() or
           date_fin = 0      or
           date_fin is null)
  };
  my $sth = $self->dbsafequery ($sql, $unitid, $unitid, $unitid, $unitid, $unitid);
  return unless $sth;
  my @results;
  while (my $unit = $sth->fetchrow_hashref) {
    push (@results, $unit);
  }
  return @results;
}

sub getUnitSubtreeAsSubtree { # Very slooow, should be optimised.
  my ($self, $unitid) = @_;
  my  $unit = $self->getUnit ($unitid);
  my $level = split (/\s+/, $unit->{path});
  my $subtree;

  return if ($level == 4);
  if ($level <= 3) {
    my $sql = qq{
      select id_unite, sigle
        from dinfo.allunits
       where id_parent = ?
         and date_debut < now()
         and (date_fin > now() or date_fin = 0 or date_fin is null)
    };
    my $sth = $self->dbsafequery ($sql, $unitid) or return;
    while (my ($id, $name) = $sth->fetchrow) {
      push (@{$subtree->{$unitid}}, { id => $id, name => $name });
    }
    $sth->finish;
  }
  if ($level <= 2) {
    my $sql = qq{
      select level3.id_unite,
             level4.id_unite,
             level4.sigle
        from dinfo.allunits as level3,
             dinfo.allunits as level4
       where level3.id_parent = ?
         and level3.id_unite = level4.id_parent
         and level3.date_debut < now()
         and (level3.date_fin > now() or
              level3.date_fin = 0     or
              level3.date_fin is null)
         and  level4.date_debut < now()
         and (level4.date_fin > now() or
              level4.date_fin = 0     or
              level4.date_fin is null)
    };
    my $sth = $self->dbsafequery ($sql, $unitid) or return;
    while (my ($id3, $id4, $name4) = $sth->fetchrow) {
      push (@{$subtree->{$id3}}, { id => $id4, name => $name4 });
    }
    $sth->finish;
  }
  if ($level <= 1) {
    my $sql = qq{
      select level2.id_unite,
             level3.id_unite, level3.sigle,
             level4.id_unite, level4.sigle
        from dinfo.allunits as level2,
             dinfo.allunits as level3,
             dinfo.allunits as level4
        where level2.id_parent = ?
          and  level2.id_unite = level3.id_parent
          and  level3.id_unite = level4.id_parent
          and  level2.date_debut < now()
          and (level2.date_fin > now() or
               level2.date_fin = 0     or
               level2.date_fin is null)
          and  level3.date_debut < now()
          and (level3.date_fin > now() or
               level3.date_fin = 0     or
               level3.date_fin is null)
          and  level4.date_debut < now()
          and (level4.date_fin > now() or
               level4.date_fin = 0     or
               level4.date_fin is null)
    };
    my $sth = $self->dbsafequery ($sql, $unitid) or return;
    while (my ($id2, $id3, $name3, $id4, $name4) = $sth->fetchrow) {
      push (@{$subtree->{$id3}}, { id => $id4, name => $name4 });
    }
    $sth->finish;
  }
  return $subtree;
}

sub getUnitFromName {
  my ($self, $name) = @_;
  my $sql = qq{
    select id_unite from unites1
     where sigle = ?
       and date_debut < now()
       and (date_fin = 0 or date_fin > now())
  };
  my $sth = $self->dbsafequery ($sql, $name) or return;
  my ($unitid) = $sth->fetchrow;
  $sth->finish;
  return $self->getUnit ($unitid) if $unitid;

  my $sql = qq{
    select id_unite from unites_etud
     where sigle = ?
       and date_debut < now()
       and (date_fin is null or date_fin > now())
  };
  my $sth = $self->dbsafequery ($sql, $name)  or return;
  my ($unitid) = $sth->fetchrow;
  $sth->finish;
  return $self->getUnit ($unitid) if $unitid;

  my $sql = qq{
    select id_unite from unites_alumni
     where sigle = ?
       and date_debut < now()
       and (date_fin is null or date_fin > now())
  };
  my $sth = $self->dbsafequery ($sql, $name)  or return;
  my ($unit) = $sth->fetchrow;
  $sth->finish;
  return $self->getUnit ($unitid) if $unitid;

  my $sql = qq{
    select id_unite from unites_hbp
     where sigle = ?
       and date_debut < now()
       and (date_fin is null or date_fin > now())
  };
  my $sth = $self->dbsafequery ($sql, $name)  or return;
  my ($unitid) = $sth->fetchrow;
  $sth->finish;
  return $self->getUnit ($unitid) if $unitid;
  return;
}

sub getAllUnits {
  my $self = shift;
  my $units;
  my $sql = qq{select * from dinfo.allunits};
  my $sth = $self->dbsafequery ($sql)  or return;
  while (my $unit = $sth->fetchrow_hashref) {
    $units->{$unit->{id_unite}} = $unit;
  }
  $sth->finish;
  foreach my $unitid (keys %$units) {
    my     $unit = $units->{$unitid};
    my $parentid = $unit->{id_parent};
    while ($parentid) {
      push (@{$unit->{ancestors}}, $parentid);
      $parentid = $units->{$parentid}->{id_parent};
    }
    $unit->{type} = 'Orgs';
  }
  return $units;
}

sub getAllUnitsTree {
  my $self = shift;
  my $units;
  my $sql = qq{select * from dinfo.allunits};
  my $sth = $self->dbsafequery ($sql) or return;
  while (my $unit = $sth->fetchrow_hashref) {
    $units->{$unit->{id_unite}} = $unit;
  }
  $sth->finish;
  my $children;
  foreach my $unitid (keys %$units) {
    my $parent = $units->{$unitid}->{id_parent};
    push (@{$children->{$parent}}, $unitid);
  }
  return $children;
}

sub getAllParents {
  my $self = shift;
  my $parents;
  my $sql = qq{
    select id_unite, id_parent, hierarchie
      from dinfo.allunits
  };
  my $sth = $self->dbsafequery ($sql) || return;
  while (my ($id_unite, $id_parent, $hierarchie) = $sth->fetchrow) {
    my @levels = split (/\s+/, $hierarchie);
    my  $level = @levels;
    $parents->{$id_unite} = {
      parent => $id_parent,
       level => $level,
    };
  }
  $sth->finish;
  return $parents;
}

sub getAllChildren {
  my $self = shift;
  my $children;
  my $sql = qq{
    select id_unite, id_parent
      from dinfo.allunits
  };
  my $sth = $self->dbsafequery ($sql);
  while (my ($unitid, $parentid) = $sth->fetchrow) {
    push (@{$children->{$parentid}}, $unitid);
  }
  if ($self->{dateref}) {
    my $oldchildren;
    my $sql = qq{
      select id_unite, id_parent
        from dinfo.unites1
    };
    my $sth = $self->dbsafequery ($sql);
    while (my ($unitid, $parentid) = $sth->fetchrow) {
      next if $children->{$parentid};
      push (@{$oldchildren->{$parentid}}, $unitid);
    }
    foreach my $parentid (keys %$oldchildren) {
      $children->{$parentid} ||= $oldchildren->{$parentid}
    }
  }
  return $children;
}

sub getRoleAdminRight {
  my ($self) = @_;
  return 'adminroles';
}

sub dbsafequery {
  my ($self, $sql, @values) = @_;
  carp "dbsafequery:sql = $sql\n" if ($self->{verbose} >= 3);
  
  unless ($self->{dinfodb}) {
    warn scalar localtime, " Orgs::Connecting to dinfo.\n" if $self->{verbose};
    $self->{dinfodb} = new Accred::Local::LocalDB (
      dbname => 'dinfo',
       trace => $self->{trace},
        utf8 => $self->{utf8},
    );
  }
  return unless $self->{dinfodb};
  my $sth = $self->{dinfodb}->prepare ($sql);
  unless ($sth) {
    warn scalar localtime, " Trying to reconnect..., sql = $sql";
    $sth = $self->{dinfodb}->prepare ($sql);
    warn scalar localtime, " Reconnection failed." unless $sth;
  }
  my $rv = $sth->execute (@values);
  unless ($rv) {
    warn scalar localtime, " Trying to reconnect..., sql = $sql";
    $rv = $sth->execute (@values);
    warn scalar localtime, " Reconnection failed." unless $rv;
  }
  return $sth;
}

sub setverbose {
  my $self = shift;
  $self->{verbose} = shift;
}



1;

