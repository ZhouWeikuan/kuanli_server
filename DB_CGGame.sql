-- MySQL dump 10.14  Distrib 5.5.56-MariaDB, for Linux (x86_64)
--
-- Host: 192.168.0.121    Database: DB_CGGame
-- ------------------------------------------------------
-- Server version	5.5.56-MariaDB

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
-- Table structure for table `TAgent`
--

DROP TABLE IF EXISTS `TAgent`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TAgent` (
  `FAgentCode` int(11) NOT NULL AUTO_INCREMENT,
  `FUniqueID` char(40) NOT NULL,
  `FAgentLead` int(11) NOT NULL DEFAULT '0',
  `FAgentType` int(11) NOT NULL DEFAULT '0',
  `FJoinTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `FAgentStatus` int(11) NOT NULL DEFAULT '1',
  PRIMARY KEY (`FAgentCode`),
  UNIQUE KEY `FUniqueID` (`FUniqueID`),
  KEY `idx_agent_agentlead` (`FAgentLead`),
  KEY `idx_agent_agenttype` (`FAgentType`)
) ENGINE=MyISAM AUTO_INCREMENT=100000 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TGame`
--

DROP TABLE IF EXISTS `TGame`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TGame` (
  `FGameID` int(11) NOT NULL,
  `FGameName` char(20) DEFAULT NULL,
  `FTableName` char(20) NOT NULL,
  `FReturnRate1` float DEFAULT '0',
  `FReturnRate2` float DEFAULT '0',
  `FBindBonus` int(11) DEFAULT '0',
  `FAppID` char(24) NOT NULL,
  `FAppSecret` char(36) NOT NULL,
  `FMerchantID` char(20) NOT NULL,
  `FMerchantPass` char(36) NOT NULL,
  `FXiaomiAppID` char(24) DEFAULT '',
  `FXiaomiAppKey` char(16) DEFAULT '',
  `FXiaomiAppSecret` char(28) DEFAULT '',
  `F360AppKey` char(36) DEFAULT '',
  `F360AppSecret` char(36) DEFAULT '',
  `FVivoAppId` char(36) DEFAULT '',
  `FVivoAppKey` char(36) DEFAULT '',
  `FAliAppId` char(20) DEFAULT '',
  `FAliAppKey` char(36) DEFAULT '',
  PRIMARY KEY (`FGameID`),
  KEY `idx_game_appid` (`FAppID`),
  KEY `idx_game_xiaomi_appid` (`FXiaomiAppID`),
  KEY `idx_game_360_appkey` (`F360AppKey`),
  KEY `idx_game_vivo_appid` (`FVivoAppId`),
  KEY `idx_game_ali_appid` (`FAliAppId`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TLandlordUser`
--

DROP TABLE IF EXISTS `TLandlordUser`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TLandlordUser` (
  `FUniqueID` char(40) NOT NULL,
  `FUserCode` int(11) NOT NULL AUTO_INCREMENT,
  `FAgentCode` int(11) NOT NULL DEFAULT '0',
  `FCounter` int(11) NOT NULL DEFAULT '5000',
  `FChargeMoney` decimal(10,2) DEFAULT '0.00',
  `FChargeCounter` int(11) DEFAULT '0',
  `FScore` int(11) NOT NULL DEFAULT '0',
  `FWins` int(11) NOT NULL DEFAULT '0',
  `FLoses` int(11) NOT NULL DEFAULT '0',
  `FDraws` int(11) NOT NULL DEFAULT '0',
  `FLastGameTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `FSaveCount` int(11) DEFAULT '0',
  `FSaveDate` int(11) DEFAULT '0',
  PRIMARY KEY (`FUserCode`),
  UNIQUE KEY `FUniqueID` (`FUniqueID`),
  KEY `idx_landlord_lasttime` (`FLastGameTime`),
  KEY `idx_landlord_counter` (`FCounter`),
  KEY `idx_landlord_agentcode` (`FAgentCode`)
) ENGINE=MyISAM AUTO_INCREMENT=100000 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TRoomInfo`
--

DROP TABLE IF EXISTS `TRoomInfo`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TRoomInfo` (
  `FRoomID` int(11) NOT NULL,
  `FGameID` int(11) NOT NULL,
  `FOwnerCode` int(11) NOT NULL,
  `FOpenTime` datetime DEFAULT NULL,
  `FGameCount` int(11) DEFAULT NULL,
  PRIMARY KEY (`FRoomID`),
  KEY `idx_roominfo_opentime` (`FOpenTime`),
  KEY `idx_roominfo_owner` (`FOwnerCode`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TShop`
--

DROP TABLE IF EXISTS `TShop`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TShop` (
  `FShopID` varchar(60) NOT NULL,
  `FShopDesc` varchar(200) DEFAULT NULL,
  `FGameID` int(11) NOT NULL,
  `FFieldName` varchar(20) NOT NULL DEFAULT 'FCounter',
  `FMoney` decimal(6,2) NOT NULL DEFAULT '0.00',
  `FValue` int(11) NOT NULL DEFAULT '0',
  `FBonus` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`FShopID`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TUseRecord`
--

DROP TABLE IF EXISTS `TUseRecord`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TUseRecord` (
  `FRecordID` int(11) NOT NULL AUTO_INCREMENT,
  `FDate` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `FRoomID` int(11) NOT NULL,
  `FGameID` int(11) NOT NULL,
  `FUniqueID` char(40) NOT NULL,
  `FCounter` int(11) NOT NULL DEFAULT '0',
  `FOldCounter` int(11) NOT NULL DEFAULT '0',
  `FNewCounter` int(11) NOT NULL DEFAULT '0',
  PRIMARY KEY (`FRecordID`),
  KEY `idx_userecord_roomid` (`FRoomID`),
  KEY `idx_userecord_gameid` (`FGameID`),
  KEY `idx_userecord_uid` (`FUniqueID`)
) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TUser`
--

DROP TABLE IF EXISTS `TUser`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TUser` (
  `FUniqueID` char(40) NOT NULL,
  `FPassword` char(32) DEFAULT 'Pa$$w0rd',
  `FNickName` varchar(100) NOT NULL DEFAULT '',
  `FOSType` varchar(32) NOT NULL DEFAULT '',
  `FPlatform` varchar(32) NOT NULL DEFAULT '',
  `FAvatarID` int(11) NOT NULL DEFAULT '0',
  `FAvatarData` blob,
  `FAvatarUrl` varchar(256) DEFAULT NULL,
  `FMobile` varchar(20) DEFAULT '',
  `FEmail` varchar(120) DEFAULT NULL,
  `FIDCard` varchar(40) NOT NULL DEFAULT '',
  `FTotalTime` double DEFAULT '0',
  `FRegTime` datetime DEFAULT NULL,
  `FLastLoginTime` datetime DEFAULT NULL,
  `FLastIP` char(20) NOT NULL,
  `FLongitude` double DEFAULT NULL,
  `FLatitude` double DEFAULT NULL,
  `FAltitude` double DEFAULT NULL,
  `FLocation` varchar(1024) DEFAULT NULL,
  `FNetSpeed` double DEFAULT NULL,
  UNIQUE KEY `FUniqueID` (`FUniqueID`),
  KEY `idx_flastlogintime` (`FLastLoginTime`),
  KEY `idx_flastip` (`FLastIP`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `TYunChengUser`
--

DROP TABLE IF EXISTS `TYunChengUser`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TYunChengUser` (
  `FUniqueID` char(40) NOT NULL,
  `FUserCode` int(11) NOT NULL AUTO_INCREMENT,
  `FAgentCode` int(11) NOT NULL DEFAULT '0',
  `FCounter` int(11) NOT NULL DEFAULT '5000',
  `FChargeMoney` decimal(10,2) DEFAULT '0.00',
  `FChargeCounter` int(11) DEFAULT '0',
  `FScore` int(11) NOT NULL DEFAULT '0',
  `FWins` int(11) NOT NULL DEFAULT '0',
  `FLoses` int(11) NOT NULL DEFAULT '0',
  `FDraws` int(11) NOT NULL DEFAULT '0',
  `FLastGameTime` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `FSaveCount` int(11) DEFAULT '0',
  `FSaveDate` int(11) DEFAULT '0',
  PRIMARY KEY (`FUserCode`),
  UNIQUE KEY `FUniqueID` (`FUniqueID`),
  KEY `idx_yuncheng_lasttime` (`FLastGameTime`),
  KEY `idx_yuncheng_counter` (`FCounter`),
  KEY `idx_yuncheng_agentcode` (`FAgentCode`)
) ENGINE=MyISAM AUTO_INCREMENT=100000 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-01-04 15:48:26
