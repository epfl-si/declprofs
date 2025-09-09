USE accred;

-- MySQL dump 10.13  Distrib 5.1.73, for redhat-linux-gnu (x86_64)
--
-- Host: cadidb.epfl.ch    Database: accred
-- ------------------------------------------------------
-- Server version	5.1.73-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `BKP_guests`
--

DROP TABLE IF EXISTS `BKP_guests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BKP_guests` (
  `code` mediumint(9) NOT NULL DEFAULT '0',
  `sciper` varchar(6) DEFAULT NULL,
  `password` varchar(128) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `firstname` varchar(32) DEFAULT NULL,
  `email` varchar(64) DEFAULT NULL,
  `organization` varchar(64) DEFAULT NULL,
  `authprovider` varchar(16) DEFAULT NULL,
  `creator` varchar(6) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `activation` datetime DEFAULT NULL,
  `renewed` datetime DEFAULT NULL,
  `reminded` datetime DEFAULT NULL,
  `remover` varchar(6) DEFAULT NULL,
  `removal` datetime DEFAULT NULL,
  `locked` tinyint(4) DEFAULT '0',
  `status` char(1) DEFAULT NULL,
  `actkey` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `BKP_guests1`
--

DROP TABLE IF EXISTS `BKP_guests1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `BKP_guests1` (
  `code` mediumint(9) NOT NULL DEFAULT '0',
  `sciper` varchar(6) DEFAULT NULL,
  `password` varchar(128) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `firstname` varchar(32) DEFAULT NULL,
  `email` varchar(64) DEFAULT NULL,
  `organization` varchar(64) DEFAULT NULL,
  `authprovider` varchar(16) DEFAULT NULL,
  `creator` varchar(6) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `activation` datetime DEFAULT NULL,
  `renewed` datetime DEFAULT NULL,
  `reminded` datetime DEFAULT NULL,
  `remover` varchar(6) DEFAULT NULL,
  `removal` datetime DEFAULT NULL,
  `locked` tinyint(4) DEFAULT '0',
  `status` char(1) DEFAULT NULL,
  `actkey` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `Universes`
--

DROP TABLE IF EXISTS `Universes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `Universes` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `nom` varchar(64) DEFAULT NULL,
  `libelle` varchar(64) DEFAULT NULL,
  `creator` varchar(6) DEFAULT NULL,
  `description` varchar(256) DEFAULT NULL,
  `dbname` varchar(64) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `id` (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=2 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accreds`
--

DROP TABLE IF EXISTS `accreds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `accreds` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `classid` int(11) DEFAULT NULL,
  `posid` int(11) DEFAULT NULL,
  `datedeb` datetime DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datereval` datetime DEFAULT NULL,
  `duree` char(2) DEFAULT NULL,
  `creator` char(8) DEFAULT NULL,
  `datecreat` datetime DEFAULT NULL,
  `origine` char(1) DEFAULT NULL,
  `comment` text,
  `author` char(8) DEFAULT NULL,
  `revalman` char(1) DEFAULT NULL,
  `ordre` tinyint(4) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `sciper` (`persid`),
  KEY `unite` (`unitid`),
  KEY `debval` (`debval`),
  KEY `finval` (`finval`),
  KEY `datedeb` (`datedeb`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accreds_properties`
--

DROP TABLE IF EXISTS `accreds_properties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `accreds_properties` (
  `propid` int(11) DEFAULT NULL,
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `sciper` (`persid`,`unitid`),
  KEY `debval` (`debval`,`finval`),
  KEY `unite` (`unitid`),
  KEY `finval` (`finval`),
  KEY `propriete` (`propid`),
  KEY `propid` (`propid`,`persid`,`unitid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `accredssave`
--

DROP TABLE IF EXISTS `accredssave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `accredssave` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `classid` int(11) DEFAULT NULL,
  `posid` int(11) DEFAULT NULL,
  `datedeb` datetime DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datereval` datetime DEFAULT NULL,
  `duree` char(2) DEFAULT NULL,
  `creator` char(8) DEFAULT NULL,
  `datecreat` datetime DEFAULT NULL,
  `origine` char(1) DEFAULT NULL,
  `comment` text,
  `author` char(8) DEFAULT NULL,
  `revalman` char(1) DEFAULT NULL,
  `ordre` tinyint(4) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `sciper` (`persid`),
  KEY `unite` (`unitid`),
  KEY `debval` (`debval`),
  KEY `finval` (`finval`),
  KEY `datedeb` (`datedeb`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `classes`
--

DROP TABLE IF EXISTS `classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `classes` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(16) DEFAULT NULL,
  `labelfr` varchar(64) DEFAULT NULL,
  `labelen` varchar(64) DEFAULT NULL,
  `description` varchar(128) DEFAULT NULL,
  `maillist` varchar(16) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `libelle` (`labelfr`)
) ENGINE=MyISAM AUTO_INCREMENT=21 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `deputations`
--

DROP TABLE IF EXISTS `deputations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `deputations` (
  `id` bigint(20) unsigned NOT NULL DEFAULT '0',
  `persid` char(8) DEFAULT NULL,
  `deputid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `roleid` int(11) DEFAULT NULL,
  `cond` char(1) DEFAULT NULL,
  `datedeb` date DEFAULT NULL,
  `datefin` date DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `persid` (`persid`,`deputid`,`unitid`,`roleid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `fonctions_ehe`
--

DROP TABLE IF EXISTS `fonctions_ehe`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fonctions_ehe` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `libelle` varchar(128) DEFAULT NULL,
  `libelle_xx` varchar(128) DEFAULT NULL,
  `libelle_en` varchar(128) DEFAULT NULL,
  `policy` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=330 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `fonctions_epfl`
--

DROP TABLE IF EXISTS `fonctions_epfl`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `fonctions_epfl` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `libelle` varchar(128) DEFAULT NULL,
  `libelle_xx` varchar(128) DEFAULT NULL,
  `libelle_en` varchar(128) DEFAULT NULL,
  `policy` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=1251 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `guests`
--

DROP TABLE IF EXISTS `guests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `guests` (
  `code` mediumint(9) NOT NULL AUTO_INCREMENT,
  `sciper` varchar(6) DEFAULT NULL,
  `password` varchar(128) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `firstname` varchar(32) DEFAULT NULL,
  `email` varchar(64) DEFAULT NULL,
  `organization` varchar(64) DEFAULT NULL,
  `authprovider` varchar(16) DEFAULT NULL,
  `creator` varchar(16) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `activation` datetime DEFAULT NULL,
  `renewed` datetime DEFAULT NULL,
  `reminded` datetime DEFAULT NULL,
  `remover` varchar(6) DEFAULT NULL,
  `removal` datetime DEFAULT NULL,
  `locked` tinyint(4) DEFAULT '0',
  `status` char(1) DEFAULT NULL,
  `actkey` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`code`),
  KEY `sciper` (`sciper`)
) ENGINE=MyISAM AUTO_INCREMENT=31002 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `history`
--

DROP TABLE IF EXISTS `history`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `history` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `classid` int(11) DEFAULT NULL,
  `posid` int(11) DEFAULT NULL,
  `datedeb` datetime DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datereval` datetime DEFAULT NULL,
  `duree` char(2) DEFAULT NULL,
  `creator` char(8) DEFAULT NULL,
  `datecreat` datetime DEFAULT NULL,
  `respons` varchar(8) DEFAULT NULL,
  `dateoper` datetime DEFAULT NULL,
  `operation` char(1) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `history1`
--

DROP TABLE IF EXISTS `history1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `history1` (
  `sciper` varchar(8) NOT NULL DEFAULT '',
  `unite` varchar(8) DEFAULT NULL,
  `statut` char(1) DEFAULT NULL,
  `classe` char(1) DEFAULT NULL,
  `fonction` int(11) DEFAULT NULL,
  `datedeb` datetime DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datereval` datetime DEFAULT NULL,
  `duree` char(2) DEFAULT NULL,
  `createur` varchar(8) DEFAULT NULL,
  `datecreat` datetime DEFAULT NULL,
  `respons` varchar(8) DEFAULT NULL,
  `dateoper` datetime DEFAULT NULL,
  `operation` char(1) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs`
--

DROP TABLE IF EXISTS `logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs` (
  `date` datetime DEFAULT NULL,
  `opcode` int(11) NOT NULL DEFAULT '0',
  `persid` char(8) DEFAULT NULL,
  `text` text,
  KEY `date` (`date`,`opcode`,`persid`,`text`(128)),
  KEY `text` (`text`(128)),
  KEY `sciper` (`persid`),
  KEY `opcode` (`opcode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logs1`
--

DROP TABLE IF EXISTS `logs1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logs1` (
  `date` datetime DEFAULT NULL,
  `opcode` int(11) NOT NULL DEFAULT '0',
  `persid` char(8) DEFAULT NULL,
  `text` text,
  KEY `date` (`date`,`opcode`,`persid`,`text`(128)),
  KEY `text` (`text`(128)),
  KEY `sciper` (`persid`),
  KEY `opcode` (`opcode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `logssave`
--

DROP TABLE IF EXISTS `logssave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `logssave` (
  `date` datetime DEFAULT NULL,
  `opcode` int(11) NOT NULL DEFAULT '0',
  `persid` char(8) DEFAULT NULL,
  `text` text,
  KEY `date` (`date`,`opcode`,`persid`,`text`(128)),
  KEY `text` (`text`(128)),
  KEY `sciper` (`persid`),
  KEY `opcode` (`opcode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `mutations`
--

DROP TABLE IF EXISTS `mutations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `mutations` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `date` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  `opcode` int(11) NOT NULL DEFAULT '0',
  `sciper` varchar(8) NOT NULL DEFAULT '',
  `text` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=627521 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `noms_usuels`
--

DROP TABLE IF EXISTS `noms_usuels`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `noms_usuels` (
  `sciper` varchar(8) NOT NULL DEFAULT '',
  `nomus` varchar(64) DEFAULT NULL,
  `prenomus` varchar(64) DEFAULT NULL,
  `resp` varchar(8) DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`sciper`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notifications_actions`
--

DROP TABLE IF EXISTS `notifications_actions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications_actions` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `labelfr` varchar(64) DEFAULT NULL,
  `labelen` varchar(64) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=7 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `notifications_listenings`
--

DROP TABLE IF EXISTS `notifications_listenings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `notifications_listenings` (
  `action` varchar(16) NOT NULL,
  `object` varchar(32) DEFAULT NULL,
  `persid` varchar(32) DEFAULT NULL,
  `reason` varchar(32) NOT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `olddroits`
--

DROP TABLE IF EXISTS `olddroits`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `olddroits` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `nom` varchar(16) DEFAULT NULL,
  `libelle` varchar(64) DEFAULT NULL,
  `description` text,
  `url` varchar(128) DEFAULT NULL,
  `resp` varchar(8) DEFAULT NULL,
  `editaccr` char(1) DEFAULT NULL,
  `status` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `libelle` (`libelle`)
) ENGINE=MyISAM AUTO_INCREMENT=18 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oldlogs`
--

DROP TABLE IF EXISTS `oldlogs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oldlogs` (
  `date` datetime DEFAULT NULL,
  `opcode` int(11) NOT NULL DEFAULT '0',
  `persid` char(8) DEFAULT NULL,
  `text` text,
  KEY `date` (`date`,`opcode`,`persid`,`text`(128)),
  KEY `text` (`text`(128)),
  KEY `sciper` (`persid`),
  KEY `opcode` (`opcode`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `oldroles`
--

DROP TABLE IF EXISTS `oldroles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `oldroles` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `nom` varchar(16) DEFAULT NULL,
  `libelle` varchar(64) DEFAULT NULL,
  `description` text,
  `maillist` varchar(16) DEFAULT NULL,
  `status` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `libelle` (`libelle`)
) ENGINE=MyISAM AUTO_INCREMENT=25 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `positions`
--

DROP TABLE IF EXISTS `positions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `positions` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `oldid` mediumint(9) DEFAULT NULL,
  `labelfr` varchar(128) DEFAULT NULL,
  `labelxx` varchar(128) DEFAULT NULL,
  `labelen` varchar(128) DEFAULT NULL,
  `restricted` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `libelle` (`labelfr`),
  KEY `unit` (`oldid`)
) ENGINE=MyISAM AUTO_INCREMENT=1304 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `privateemails`
--

DROP TABLE IF EXISTS `privateemails`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `privateemails` (
  `persid` char(8) NOT NULL DEFAULT '',
  `email` varchar(64) DEFAULT NULL,
  `status` tinyint(4) DEFAULT '0',
  PRIMARY KEY (`persid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `properties`
--

DROP TABLE IF EXISTS `properties`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `properties` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(16) DEFAULT NULL,
  `labelfr` varchar(64) DEFAULT NULL,
  `labelen` varchar(64) DEFAULT NULL,
  `description` varchar(128) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `destruction` datetime DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `properties_classes`
--

DROP TABLE IF EXISTS `properties_classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `properties_classes` (
  `propid` int(11) DEFAULT NULL,
  `classid` int(11) DEFAULT NULL,
  `granted` char(1) DEFAULT NULL,
  `allowed` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `propid` (`propid`,`classid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `properties_status`
--

DROP TABLE IF EXISTS `properties_status`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `properties_status` (
  `propid` int(11) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `granted` char(1) DEFAULT NULL,
  `allowed` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `propid` (`propid`,`statusid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `properties_units`
--

DROP TABLE IF EXISTS `properties_units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `properties_units` (
  `propid` int(11) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `allowed` char(1) DEFAULT NULL,
  `granted` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `propid` (`propid`,`unitid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights`
--

DROP TABLE IF EXISTS `rights`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `unittype` varchar(16) DEFAULT 'Orgs',
  `labelfr` varchar(200) DEFAULT NULL,
  `labelen` varchar(200) DEFAULT NULL,
  `description` text,
  `needreval` char(1) DEFAULT NULL,
  `unitlevels` varchar(16) DEFAULT NULL,
  `ordre` mediumint(9) DEFAULT '0',
  `url` varchar(128) DEFAULT NULL,
  `respid` varchar(8) DEFAULT NULL,
  `emailresp` varchar(128) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=220 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_classes`
--

DROP TABLE IF EXISTS `rights_classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_classes` (
  `rightid` int(11) DEFAULT NULL,
  `classid` int(11) DEFAULT NULL,
  `allowed` char(1) DEFAULT NULL,
  `defaults` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_persons`
--

DROP TABLE IF EXISTS `rights_persons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_persons` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `rightid` int(11) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `respid` char(8) DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datedel` datetime DEFAULT NULL,
  `accrdel` varchar(6) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_personssave`
--

DROP TABLE IF EXISTS `rights_personssave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_personssave` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `rightid` int(11) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `respid` char(8) DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datedel` datetime DEFAULT NULL,
  `accrdel` varchar(6) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_roles`
--

DROP TABLE IF EXISTS `rights_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_roles` (
  `rightid` int(11) DEFAULT NULL,
  `roleid` int(11) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  `hasrights` char(1) DEFAULT 'y'
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_statuses`
--

DROP TABLE IF EXISTS `rights_statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_statuses` (
  `rightid` int(11) DEFAULT NULL,
  `statusid` int(11) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `rights_units`
--

DROP TABLE IF EXISTS `rights_units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `rights_units` (
  `rightid` int(11) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles`
--

DROP TABLE IF EXISTS `roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) DEFAULT NULL,
  `unittype` varchar(16) DEFAULT NULL,
  `labelfr` varchar(64) DEFAULT NULL,
  `labelen` varchar(64) DEFAULT NULL,
  `description` text,
  `needreval` char(1) DEFAULT NULL,
  `unitlevels` varchar(16) DEFAULT NULL,
  `deputiesright` smallint(6) DEFAULT NULL,
  `hasrights` char(1) DEFAULT 'y',
  `delegate` char(1) DEFAULT 'y',
  `protected` char(1) DEFAULT 'n',
  `ordre` mediumint(9) DEFAULT '0',
  `maillist` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `name` (`name`)
) ENGINE=MyISAM AUTO_INCREMENT=64 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles_persons`
--

DROP TABLE IF EXISTS `roles_persons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles_persons` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `roleid` int(11) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `respid` char(8) DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datedel` datetime DEFAULT NULL,
  `accrdel` varchar(6) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles_personssave`
--

DROP TABLE IF EXISTS `roles_personssave`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles_personssave` (
  `persid` char(8) DEFAULT NULL,
  `unitid` char(12) DEFAULT NULL,
  `roleid` int(11) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `respid` char(8) DEFAULT NULL,
  `datefin` datetime DEFAULT NULL,
  `datedel` datetime DEFAULT NULL,
  `accrdel` varchar(6) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `roles_rights`
--

DROP TABLE IF EXISTS `roles_rights`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `roles_rights` (
  `roleid` smallint(6) DEFAULT NULL,
  `rightid` smallint(6) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `roleid` (`roleid`,`rightid`,`debval`,`finval`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `saveguests`
--

DROP TABLE IF EXISTS `saveguests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `saveguests` (
  `code` mediumint(9) NOT NULL AUTO_INCREMENT,
  `sciper` varchar(6) DEFAULT NULL,
  `password` varchar(32) DEFAULT NULL,
  `name` varchar(32) DEFAULT NULL,
  `firstname` varchar(32) DEFAULT NULL,
  `email` varchar(64) DEFAULT NULL,
  `organization` varchar(64) DEFAULT NULL,
  `authprovider` varchar(16) DEFAULT NULL,
  `creator` varchar(6) DEFAULT NULL,
  `creation` datetime DEFAULT NULL,
  `activation` datetime DEFAULT NULL,
  `renewed` datetime DEFAULT NULL,
  `reminded` datetime DEFAULT NULL,
  `remover` varchar(6) DEFAULT NULL,
  `removal` datetime DEFAULT NULL,
  `status` char(1) DEFAULT NULL,
  `actkey` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`code`),
  KEY `sciper` (`sciper`)
) ENGINE=MyISAM AUTO_INCREMENT=20045 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `services`
--

DROP TABLE IF EXISTS `services`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `services` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(64) DEFAULT NULL,
  `auteur` varchar(6) DEFAULT NULL,
  `description` varchar(256) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `id` (`id`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `statuses`
--

DROP TABLE IF EXISTS `statuses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `statuses` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(16) DEFAULT NULL,
  `labelfr` varchar(64) DEFAULT NULL,
  `labelen` varchar(64) DEFAULT NULL,
  `description` text,
  `maillist` varchar(16) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `libelle` (`labelfr`)
) ENGINE=MyISAM AUTO_INCREMENT=8 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `superrights`
--

DROP TABLE IF EXISTS `superrights`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `superrights` (
  `name` varchar(32) DEFAULT NULL,
  `env` varchar(8) DEFAULT NULL,
  `persid` char(8) DEFAULT NULL,
  `comment` varchar(64) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `test_view`
--

DROP TABLE IF EXISTS `test_view`;
/*!50001 DROP VIEW IF EXISTS `test_view`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `test_view` (
 `toto` tinyint NOT NULL
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `units`
--

DROP TABLE IF EXISTS `units`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `units` (
  `id_unite` varchar(6) NOT NULL,
  `id_parent` varchar(6) DEFAULT NULL,
  `sigle` varchar(24) DEFAULT NULL,
  `libelle` varchar(128) DEFAULT NULL,
  `abrege` varchar(64) DEFAULT NULL,
  `date_debut` datetime DEFAULT NULL,
  `date_fin` datetime DEFAULT NULL,
  `type` smallint(6) DEFAULT NULL,
  `responsable` varchar(6) DEFAULT NULL,
  `langueprinc` smallint(6) DEFAULT NULL,
  `no_unite` varchar(6) DEFAULT NULL,
  `cf` varchar(6) DEFAULT NULL,
  `hierarchie` varchar(64) DEFAULT NULL,
  `niveau` smallint(6) DEFAULT NULL,
  `date_creat` datetime DEFAULT NULL,
  `date_modif` datetime DEFAULT NULL,
  `sigle_en` varchar(24) DEFAULT NULL,
  `libelle_en` varchar(128) DEFAULT NULL,
  `abrege_en` varchar(64) DEFAULT NULL,
  `sigle_de` varchar(24) DEFAULT NULL,
  `libelle_de` varchar(128) DEFAULT NULL,
  `abrege_de` varchar(64) DEFAULT NULL,
  `sigle_it` varchar(24) DEFAULT NULL,
  `libelle_it` varchar(128) DEFAULT NULL,
  `abrege_it` varchar(64) DEFAULT NULL,
  `adresse_1` varchar(64) DEFAULT NULL,
  `adresse_2` varchar(64) DEFAULT NULL,
  `adresse_3` varchar(64) DEFAULT NULL,
  `adresse_4` varchar(64) DEFAULT NULL,
  `ville` varchar(64) DEFAULT NULL,
  `pays` smallint(6) DEFAULT NULL,
  `cmpl_type` varchar(4) DEFAULT NULL,
  `visible` char(1) DEFAULT NULL,
  `affichage` char(3) DEFAULT NULL,
  `fnresp` varchar(64) DEFAULT NULL,
  `visildap` char(1) DEFAULT NULL,
  `sigleorga` varchar(8) DEFAULT NULL,
  `ordre` smallint(6) DEFAULT NULL,
  KEY `id_unite` (`id_unite`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `units_positions`
--

DROP TABLE IF EXISTS `units_positions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `units_positions` (
  `unitid` char(12) DEFAULT NULL,
  `posid` int(11) DEFAULT NULL,
  `value` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `unitid` (`unitid`,`posid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `units_rights`
--

DROP TABLE IF EXISTS `units_rights`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `units_rights` (
  `unite` varchar(8) DEFAULT NULL,
  `prestation` varchar(8) DEFAULT NULL,
  `droit` char(1) DEFAULT NULL,
  `defaut` char(1) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `workflows`
--

DROP TABLE IF EXISTS `workflows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `workflows` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `name` varchar(32) NOT NULL,
  `action` varchar(32) NOT NULL,
  `objtype` varchar(16) NOT NULL,
  `objid` mediumint(9) NOT NULL,
  `url` varchar(128) DEFAULT NULL,
  `args` varchar(256) DEFAULT NULL,
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `action` (`action`,`objid`)
) ENGINE=MyISAM AUTO_INCREMENT=47 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `workflows_approved`
--

DROP TABLE IF EXISTS `workflows_approved`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `workflows_approved` (
  `pendid` mediumint(9) NOT NULL,
  `objtype` varchar(16) NOT NULL,
  `objid` mediumint(9) NOT NULL,
  `signerid` mediumint(9) NOT NULL,
  `decision` enum('Accept','Deny') DEFAULT NULL,
  `date` datetime DEFAULT NULL,
  KEY `pendid` (`pendid`,`objid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `workflows_internal`
--

DROP TABLE IF EXISTS `workflows_internal`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `workflows_internal` (
  `workid` mediumint(9) NOT NULL,
  `objtype` varchar(16) NOT NULL,
  `objid` mediumint(9) NOT NULL,
  `step` tinyint(4) DEFAULT '1',
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  KEY `workid` (`workid`,`objtype`,`objid`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `workflows_pending`
--

DROP TABLE IF EXISTS `workflows_pending`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `workflows_pending` (
  `id` mediumint(9) NOT NULL AUTO_INCREMENT,
  `workid` mediumint(9) NOT NULL,
  `args` varchar(256) DEFAULT NULL,
  `userid` mediumint(9) NOT NULL,
  `step` tinyint(4) DEFAULT '0',
  `debval` datetime DEFAULT NULL,
  `finval` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `workid` (`workid`)
) ENGINE=MyISAM AUTO_INCREMENT=4585 DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Final view structure for view `test_view`
--

/*!50001 DROP TABLE IF EXISTS `test_view`*/;
/*!50001 DROP VIEW IF EXISTS `test_view`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8 */;
/*!50001 SET character_set_results     = utf8 */;
/*!50001 SET collation_connection      = utf8_general_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`accred`@`kissrv89.epfl.ch` SQL SECURITY DEFINER */
/*!50001 VIEW `test_view` AS select 'toto' AS `toto` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-11-20  9:58:14
