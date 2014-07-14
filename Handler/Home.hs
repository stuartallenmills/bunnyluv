{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies #-}
{-# LANGUAGE OverloadedStrings, GADTs, FlexibleContexts #-}

module Handler.Home where

--this is a test 

import qualified Data.ByteString.Lazy as L
import Conduit

import Data.Conduit
import Data.Conduit.Binary
import Data.Default
import Yesod hiding ((!=.), (==.))
import Yesod.Default.Util
import Foundation

import Data.Text (Text, unpack)
import Database.Esqueleto
import Database.Persist.Sqlite (runSqlite, runMigrationSilent)
import Database.Persist.TH (mkPersist, mkMigrate, persistLowerCase, share, sqlSettings)
import Database.Persist.Sql (insert)
import Control.Monad.IO.Class (liftIO)
import Text.Printf

--query:: IO ()
{-
queryAll = runSqlite "test5.db3" $ do
  zipt<-select $ from $ \r ->do
     where_ (r ^. RabbitName !=. val "")
     orderBy [asc (r ^. RabbitName)]
     return (r)
  return zipt
-}
query field value= runSqlite "test5.db3" $ do
  zipt<-select $ from $ \r->do
    where_ (r ^. field ==. val value)
    orderBy [asc (r ^. RabbitName)]
    return r
  return zipt

queryStatus status = runSqlite "test5.db3" $ do
  zipt<-select $ from $ \r ->do
     where_ (r ^. RabbitStatus ==. val status)
     orderBy [asc (r ^. RabbitName)]
     return (r)
  return zipt

querySource source = runSqlite "test5.db3" $ do
  zipt<-select $ from $ \r ->do
     where_ (r ^. RabbitSourceType ==. val source)
     orderBy [asc (r ^. RabbitName)]
     return (r)
  return zipt

headerWidget::Widget
headerWidget = $(widgetFileNoReload def "header")

-- menuWidget::Widget
-- menuWidget = $(widgetFileNoReload def "menu")

cssmenuWidget::Widget
cssmenuWidget = $(widgetFileNoReload def "cssmenu")

mainMenu::Widget
mainMenu = do
          addScriptRemote "http://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"
          cssmenuWidget


  
getQueryR status  = do
     zinc<- queryStatus status
     defaultLayout $ do
        setTitle "Rabbits"
        [whamlet|
         ^{headerWidget}
         ^{mainMenu}

     $forall Entity rabbitid rabbit <- zinc
           ^{doRabbitRow rabbitid rabbit }
                |]

getSourceR source  = do
     zinc<- querySource source
     defaultLayout $ do
        setTitle "Source"
        [whamlet|
         ^{headerWidget}
         ^{mainMenu}
     $forall Entity rabbitid rabbit <- zinc
           ^{doRabbitRow rabbitid rabbit }
                |]

doRabbitRow::RabbitId->Rabbit->Widget
doRabbitRow rabbitid rabbit = $(widgetFileNoReload def "rabRow") 

getTestR :: Handler Html
getTestR = do
  defaultLayout $ do
     setTitle "Test"
     [whamlet|
      ^{headerWidget}
      ^{mainMenu}
      <div>This is a test of the something
            |]
  
getHomeR :: Handler Html
getHomeR = do
    bl <-queryStatus "BunnyLuv"
    ad <-queryStatus "Adopted"
    di <-queryStatus "Died"
    eu <-queryStatus "Euthanized"
--    zinc <-queryAll
    let zinc = bl++ad++di++eu
    defaultLayout $ do
        setTitle "Rabbits"
--        addScriptRemote "http://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"
     -- <div class="title" style="width:95%; margin-left:1%; margin-right:1%;" >
     --  <div #headimg>
     --   <img src="http://localhost:3000/images/bunnyluv_img.gif" width="80px">
     --  <div #splash>  
     --   <h2> BunnyLuv Rabbit Database

        [whamlet|
         ^{headerWidget}
         ^{mainMenu}
         <div #rabbitContainer>
     $forall Entity rabbitid rabbit <- zinc
           ^{doRabbitRow rabbitid rabbit }
                |]

postHomeR :: Handler Html
postHomeR = do
    ((result, _), _) <- runFormPost uploadForm
    case result of
      FormSuccess fi -> do
        app <- getYesod
        fileBytes <- runResourceT $ fileSource fi $$ sinkLbs
        addFile app (fileName fi, fileBytes)
      _ -> return ()
    redirect HomeR

uploadForm = renderDivs $ fileAFormReq "file"
