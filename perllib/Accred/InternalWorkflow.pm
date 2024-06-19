#!/usr/bin/perl
#
##############################################################################
#
# File Name:    Workflows.pm
# Description:  Gestion des workflows externes.
# Author:       Claude Lecommandeur (Claude.Lecommandeur@epfl.ch)
# Date Created: Fri Sep 11 14:32:37 CEST 2015
# Version:      1.0
# Revision:     
#
##############################################################################
#
#
package Accred::InternalWorkflow;

use strict;
use utf8;

use Accred::Utils;
use Accred::Messages;

sub new {
  my ($class, $req) = @_;
  my  $self = {
         req => $req || {},
          db => undef,
        utf8 => 1,
      errmsg => undef,
        fake => 0,
       debug => 0,
     verbose => 0,
       trace => 0,
  };
  bless $self;
  $self->{lang} = $req->{lang} || 'en';
  Accred::Utils::import ();
  importmodules ($self, 'AccredDB');
  return $self;
}

sub startWorkflow {
  my ($self, $workflow, $userid, $unitid, $persid) = @_;
  my $pendid = addPendingApproval (
    $workflow->{id}, $userid, $unitid, $persid,
  );
  $self->askForApproval ($pendid);
}

sub endWorkflow {
  my ($self, $pendapp, $decision) = @_;
  importmodules ($self, 'Workflows');
  $self->{workflows}->deletePendingApproval ($pendapp->{id});
}

sub getWorkflowSigners {
  my ($self, $workid) = @_;
  my @signers = $self->{accreddb}->dbselect (
    table => 'workflows_internal',
     what => [ '*' ],
    where => {
      workid => $workid,
    },
  );
  return @signers;
}

sub addWorkflowSigner {
  my ($self, $workid, $objtype, $objid, $step) = @_;
  $self->{accreddb}->dbinsert (
    table => 'workflows_internal',
      set => {
         workid => $workid,
        objtype => $objtype,
          objid => $objid,
           step => $step || 1,
      },
  );
  return 1;
}

sub delWorkflowSigner {
  my ($self, $workid, $objtype, $objid) = @_;
  $self->{accreddb}->dbdelete (
    table => 'workflows_internal',
    where => {
       workid => $workid,
      objtype => $objtype,
        objid => $objid,
   },
  );
  return 1;
}

sub getUserPendingApprovals {
  my ($self, $userid) = @_;
  importmodules ($self, 'Rights', 'Roles', 'Workflows');
  #
  # No roles, returns immediately.
  #
  my $perspriv = {
     Role => $self->{roles}->getRoles   (persid => $userid),
    Right => $self->{rights}->getRights (persid => $userid),
  };
  next unless ($perspriv->{Role} || $perspriv->{Right});
  #
  # Cgeck all internal pending approval.
  #
  my @pendids = $self->{accreddb}->dbselect (
    table => 'workflows_pending',
     what => 'id',
  );
  return unless @pendids;
  
  my @pendapps;
  foreach my $pendid (@pendids) {
    my  $pendapp = $self->{workflows}->getPendingApproval ($pendid);
    my $workflow = $pendapp->{workflow};
    next unless $workflow->{internal};

    my   $unitid = $pendapp->{unitid};
    my $missings = $pendapp->{missings};
    next unless $missings;
    my @miss;
    foreach my $missing (@$missings) {
      my $objtype = $missing->{objtype};
      my   $objid = $missing->{objid};
      if ($perspriv->{$objtype}->{$objid} && $perspriv->{$objtype}->{$objid}->{$unitid}) {
        push (@miss, $missing);
      }
    }
    next unless @miss;
    $pendapp->{missings} = \@miss;
    push (@pendapps, $pendapp);
  }
  return @pendapps;
}

sub neededApprovals {
  my ($self, $workid) = @_;
  my @needed = $self->{accreddb}->dbselect (
    table => 'workflows_internal',
     what => [ '*' ],
    where => {
      workid => $workid,
    },
  );
  return unless @needed;
  my @needs;
  foreach my $need (@needed) {
    my $objtype = $need->{objtype};
    my   $objid = $need->{objid};
    $need->{object} = $self->{workflows}->getObject ($objtype, $objid);
    push (@needs, $need);
  }
  return @needs;
}

sub missingApprovals {
  my ($self, $pendapp) = @_;  
  my $alreadyapproved;
  my $approved = $pendapp->{approved};
  if ($approved && @$approved) {
    foreach my $approval (@$approved) {
      my $objtype = $approval->{objtype};
      my   $objid = $approval->{objid};
      $alreadyapproved->{"$objtype:$objid"} = $approval;
    }
  }
  
  my $needed = $pendapp->{needed};
  return unless ($needed && @$needed);
  my @missings;
  foreach my $need (@$needed) {
    my $objtype = $need->{objtype};
    my   $objid = $need->{objid};
    unless ($alreadyapproved->{"$objtype:$objid"}) {
      push (@missings, $need);
    }
  }
  return @missings ? \@missings : undef;
}

sub askForApproval {
  my ($self, $pendid) = @_;
  importmodules ($self, 'Persons', 'Units', 'Rights', 'Roles', 'Workflows', 'Logs');
  my $cgidir = $self->{cgidir};

  my $pendapp = $self->{workflows}->getPendingApproval ($pendid);
  return unless $pendapp;

  my $missings = $pendapp->{missings};
  return unless $missings;

  my $minstep = 10;
  foreach my $approval (@$missings) {
    if ($approval->{step} < $minstep) {
      $minstep = $approval->{step};
    }
  }
  
  my $needed = $pendapp->{needed};
  return unless $needed;
  my @currents;
  foreach my $approval (@$needed) {
    if ($approval->{step} == $minstep) {
      push (@currents, $approval);
    }
  }
  return unless @currents;
  
  my $unitid = $pendapp->{unitid};
  my   $unit = $self->{units}->getUnit ($unitid);
  return unless $unit;

  my $authorid = $pendapp->{userid};
  my   $author = $self->{persons}->getPerson ($authorid);

  my $recipid = $pendapp->{persid};
  my   $recip = $self->{persons}->getPerson ($recipid);

  my $workflow = $pendapp->{workflow};
  my   $action = $workflow->{action};
  my $wobjtype = $workflow->{objtype};
  my   $wobjid = $workflow->{objid};
  my  $wobject = $workflow->{object};
  my $wobjType = $self->{workflows}->getObjectType ($wobjtype);
    
  my   $delegfr = ($action->{name} =~ /^grant/) ? 'délégation' : 'revocation';
  my   $delegen = ($action->{name} =~ /^grant/) ? 'grant'      : 'revoke';
  my $logaction = 'askforactionapproval';

  foreach my $current (@currents) {
    my $sobjtype = $current->{objtype};
    my   $sobjid = $current->{objid};
    my  $sobject = $current->{object};
    
    my $validators;
    if ($wobjtype eq 'Right') {
      $validators = $self->{rights}->getRights (
        rightid => $wobjid,
         unitid => $unitid,
      );
    } else {
      $validators = $self->{roles}->getRoles (
        roleid => $wobjid,
        unitid => $unitid,
      );
    }
    return unless $validators;
    my $valpersids;
    foreach my $unitid (keys %{$validators->{$wobjid}}) {
      my @valpersids = keys %{$validators->{$wobjid}->{$unitid}};
      foreach my $persid (@valpersids) {
        $valpersids->{$persid} = $unitid;
      }
    }
    my @valpersids = keys %$valpersids;
    return unless @valpersids;
    my $valpers = $self->{persons}->getPersons (\@valpersids);
    my @emails;
    foreach my $destid (keys %$valpers) {
      my  $dest = $valpers->{$destid};
      my $email = $dest->{email};
      unless ($email) {
        warn "Rights:askForApproval: no email for $destid\n";
        next;
      }
      push (@emails, $email);
    }
    my $lunite = ($unit->{name} =~ /^CF /)
      ? 'le centre financier' : ($unit->{name} =~ /^Fund /)
      ? 'le fonds' : 'l\'unité';
    my $theunit = ($unit->{name} =~ /^CF /)
      ? 'financial center' : ($unit->{name} =~ /^Fund /)
      ? 'fund' : 'unit';
    my $sobjType = $self->{workflows}->getObjectType ($sobjtype);

    my      $to = join (', ', @emails);
    my $subject = msg('Approval', $wobjType->{label}, $wobject->{label});
    my    $body = 
      "<br>\n".
      "----------------- English below --------------------<br>\n".
      "<br>\n".
      "  Bonjour,<br>\n".
      "<br>\n".
      "  Vous recevez cet email car vous êtes titulaire du $sobjType->{labelfr} ".
      "<b>$sobject->{labelfr}</b> pour $lunite $unit->{name}.<br>\n".
      "<br>\n".
      "  Une demande de $delegfr du $wobjType->{labelfr} <b>$wobject->{labelfr}</b> ".
      "vient d'être faite par $author->{name}. Cette demande concerne l'attribution du ".
      "$wobjType->{labelfr} à $recip->{name} ".
      "dans $lunite $unit->{name} et nécessite votre approbation.<br>\n".
      "<br>\n".
      "  Pour accepter ou refuser cette demande, allez sur l'URL suivante ".
      "<a href=\"http://slpc1.epfl.ch/$cgidir/workflows.pl/activeworkflows\">".
      "Approbation </a><br>\n".
      "<br>\n".
      "<br>\n".
      "    Merci.<br>\n".
      "<br>\n".
      "----------------------------------------------------<br>\n".
      "<br>\n".
      "  Hello,<br>\n".
      "<br>\n".
      "  You are receiving this email because you have the $sobjType->{labelen} ".
      "<b>$sobject->{labelen}</b> in $theunit $unit->{name}.<br>\n".
      "<br>\n".
      "$author->{name} is willing to $delegen $wobjType->{labelen} ".
      "<b>$wobject->{labelen}</b> to $recip->{name} ".
      "for $theunit $unit->{name} and needs your approval.<br>\n".
      "<br>\n".
      "To accept or deny this request, you must to here :".
      "<a href=\"http://slpc1.epfl.ch/$cgidir/workflows.pl/activeworkflows\">".
      "Approbation </a><br>\n".
      "<br>\n".
      "<br>\n".
      "    Thanks.<br>\n".
      "<br>\n";
    if (1) {
      $to   = 'claude.lecommandeur@epfl.ch';
      $body = "Sent to @emails<br>\n" . $body;
    }
    sendmail ($to, $subject, $body);
    $self->{logs}->log ($authorid, $logaction, $wobjtype, $wobjid, $unitid, $recipid);
  }
}

sub finalApprovalMail {
  my ($self, $pendid) = @_;
  importmodules ($self, 'Persons', 'Units', 'Workflows', 'Logs');
  my $pendapp = $self->{workflows}->getPendingApproval ($pendid);
  return unless $pendapp;

  my $missings = $pendapp->{missings};
  return if $missings;

  my  $unitid = $pendapp->{unitid};
  my    $unit = $self->{units}->getUnit ($unitid);
  return unless $unit;

  my $authorid = $pendapp->{userid};
  my   $author = $self->{persons}->getPerson ($authorid);
  return unless $author;

  my  $workflow = $pendapp->{workflow};
  my    $action = $workflow->{action};
  my  $wobjtype = $workflow->{objtype};
  my    $wobjid = $workflow->{objid};
  my   $wobject = $workflow->{object};
  my  $wobjType = $self->{workflows}->getObjectType ($wobjtype);

  my   $recipid = $pendapp->{persid};
  my     $recip = $self->{persons}->getPerson ($recipid);
  return unless $recip;

  my   $delegfr = ($action->{name} =~ /^grant/) ? 'délégation' : 'revocation';
  my   $delegen = ($action->{name} =~ /^grant/) ? 'grant'      : 'revoke';
  my  $attribfr = ($action->{name} =~ /^grant/) ? 'attribué' : 'supprimé';
  my  $attriben = ($action->{name} =~ /^grant/) ? 'granted'  : 'revoked';
  my $logaction = 'actionapproved';

  my $lunite = ($unit->{name} =~ /^CF /)
    ? 'le centre financier' : ($unit->{name} =~ /^Fund /)
    ? 'le fonds' : 'l\'unité';
  my $theunit = ($unit->{name} =~ /^CF /)
    ? 'financial center' : ($unit->{name} =~ /^Fund /)
    ? 'fund' : 'unit';

  my      $to = $author->{email};
  my $subject = msg('Approval', $wobjType->{label}, $wobject->{label});
  my    $body = 
    "<br>\n".
    "----------------- English below --------------------<br>\n".
    "<br>\n".
    "  Bonjour,<br>\n".
    "<br>\n".
    "  Vous recevez cet email car vous avez fait une demande $delegfr du ".
    "$wobjType->{labelfr} <b>$wobject->{labelfr}</b> pour $recip->{name} ".
    "dans $lunite $unit->{name}.<br>\n".
    "<br>\n".
    "  Bonne nouvelle, cette demande a reçu tous les tampons nécessaires. Il a ".
    "dont été $attribfr comme demandé.<br>\n".
    "<br>\n".
    "<br>\n".
    "    Merci.<br>\n".
    "<br>\n".
    "----------------------------------------------------<br>\n".
    "<br>\n".
    "  Hello,<br>\n".
    "<br>\n".
    "  You are receiving this email because you ask for the $delegen of ".
    "$wobjType->{labelen} <b>$wobject->{labelen}</b> to $recip->{name} ".
    "in $theunit $unit->{name}.<br>\n".
    "<br>\n".
    "  Good news, all requested approvals have been signed. Hence the ".
    "$wobjType->{labelen} has been $attriben.<br>\n".
    "<br>\n".
    "<br>\n".
    "    Thanks.<br>\n".
    "<br>\n";
  if (1) {
    $to   = 'claude.lecommandeur@epfl.ch';
    $body = "Sent to $author->{email}<br>\n" . $body;
  }
  sendmail ($to, $subject, $body);
  $self->{logs}->log ($authorid, $logaction, $wobjtype, $wobjid, $unitid, $recipid);
}

sub refusedApprovalMail {
  my ($self, $pendid) = @_;
  importmodules ($self, 'Persons', 'Units', 'Workflows', 'Logs');
  my $pendapp = $self->{workflows}->getPendingApproval ($pendid);
  return unless $pendapp;
  
  my $approved = $pendapp->{approved};
  return unless $approved;
  my $refuser;
  foreach my $approval (@$approved) {
    if ($approval->{decision} eq 'Deny') {
      $refuser = $approval;
    }
  }
  return unless $refuser;

  my $robjtype = $refuser->{objtype};
  my   $robjid = $refuser->{objid};
  my $signedid = $refuser->{signerid};
  my $robjType = $self->{workflows}->getObjectType ($robjtype);
  my  $robject = $self->{workflows}->getObject ($robjtype, $robjid);
  my   $signer = $self->{persons}->getPerson ($signedid);
  return unless $robject;

  my $unitid = $pendapp->{unitid};
  my   $unit = $self->{units}->getUnit ($unitid);
  unless ($unit) {
    warn "Accred::Rights::refusedApprovalMail: bad unit id : $unitid.\n";
    return;
  }

  my    $authorid = $pendapp->{userid};
  my      $author = $self->{persons}->getPerson      ($authorid);
  unless ($author) {
    warn "Accred::Rights::refusedApprovalMail: bad author id : $authorid.\n";
    return;
  }

  my  $workflow = $pendapp->{workflow};
  my    $action = $workflow->{action};
  my  $wobjtype = $workflow->{objtype};
  my    $wobjid = $workflow->{objid};
  my   $wobject = $workflow->{object};
  my  $wobjType = $self->{workflows}->getObjectType ($wobjtype);

  my   $recipid = $pendapp->{persid};
  my     $recip = $self->{persons}->getPerson ($recipid);
  unless ($recip) {
    warn "Accred::Rights::refusedApprovalMail: bad recipient id : $recipid.\n";
    return;
  }

  my   $delegfr = ($action->{name} =~ /^grant/) ? 'délégation' : 'revocation';
  my   $delegen = ($action->{name} =~ /^grant/) ? 'grant'      : 'revoke';
  my  $attribfr = ($action->{name} =~ /^grant/) ? 'attribué' : 'supprimé';
  my  $attriben = ($action->{name} =~ /^grant/) ? 'granted'  : 'revoked';

  my $lunite = ($unit->{name} =~ /^CF /)
    ? 'le centre financier' : ($unit->{name} =~ /^Fund /)
    ? 'le fonds' : 'l\'unité';
  my $theunit = ($unit->{name} =~ /^CF /)
    ? 'financial center' : ($unit->{name} =~ /^Fund /)
    ? 'fund' : 'unit';

  my      $to = $author->{email};
  my $subject = msg('Approval', $wobjType->{label}, $wobject->{label});
  my    $body = 
    "<br>\n".
    "----------------- English below --------------------<br>\n".
    "<br>\n".
    "  Bonjour,<br>\n".
    "<br>\n".
    "  Vous recevez cet email car vous avez fait une demande $delegfr du ".
    "$wobjType->{labelfr} <b>$wobject->{labelfr}</b> pour $recip->{name} ".
    "dans $lunite $unit->{name}.<br>\n".
    "<br>\n".
    "  Mauvaise nouvelle, cette attribution a été refusée par un titulaire du ".
    "$robjType->{labelfr} <b>$robject->{labelfr}</b> ($signer->{name}).<br>\n".
    "<br>\n".
    "<br>\n".
    "    Merci.<br>\n".
    "<br>\n".
    "-----------------------------------------------------------------------------------\n".
    "<br>\n".
    "  Hello,<br>\n".
    "\n".
    "  You are receiving this email because you ask for the $delegen of ".
    "$wobjType->{labelen} <b>$wobject->{labelen}</b> to $recip->{name} ".
    "in $theunit $unit->{name}.<br>\n".
    "<br>\n".
    "  Bad news, someone with $robjType->{labelen} <b>$robject->{labelen}</b> ".
    "($signer->{name}) refused to approve it.<br>\n".
    "<br>\n".
    "<br>\n".
    "    Thanks.<br>\n".
    "<br>\n";
  if (1) {
    $to   = 'claude.lecommandeur@epfl.ch';
    $body = "Sent to $author->{email}<br>\n" . $body;
  }
  sendmail ($to, $subject, $body);
  $self->{logs}->log ($authorid, 'actionrefused', $wobjtype, $wobjid, $unitid, $recipid);
}



1;


