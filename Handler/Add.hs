{-# LANGUAGE QuasiQuotes, TemplateHaskell, TypeFamilies #-}
{-# LANGUAGE OverloadedStrings, GADTs, FlexibleContexts #-}

module Handler.Add where


import Conduit
import Data.Default
import Yesod hiding ((!=.), (==.), (=.), update)
import Yesod.Default.Util
import Foundation
import Yesod.Auth
import Data.Text (Text, unpack, pack)
import Database.Esqueleto
import Control.Applicative
import Data.Time.LocalTime
import Data.Time.Calendar
import Text.Julius
import FormUtils
import Utils




  
test mrab field = case mrab of
                    Nothing->Nothing
                    Just ri->Just (field ri)


opttest::Maybe Rabbit->(Rabbit->Text)->Maybe Text
opttest mrab field= case mrab of
                   Nothing-> Just ""
                   Just ri-> Just (field ri)




testDateIn now  Nothing = Nothing
testDateIn now (Just rab)  = Just (showtime (rabbitDateIn rab))

getDateIn Nothing = Nothing
getDateIn (Just rab) = Just (rabbitDateIn rab)

testStatusDate now Nothing = Nothing
testStatusDate now (Just rab) = Just (rabbitStatusDate rab)

testAlteredDate::Maybe Rabbit -> Maybe (Maybe Text)
testAlteredDate Nothing = Nothing
testAlteredDate (Just ( Rabbit _ _ _ _ _ _ _ Nothing _  _ _ _ _) ) = Nothing
testAlteredDate (Just ( Rabbit _ _ _ _ _ _ _ (Just da) _  _ _ _ _) ) = Just (Just (showtime da))

months::[(Text, Integer)]
months =[(pack (show x), x) | x<- [0..11]]
years::[(Text, Integer)]
years = [(pack (show x), x) | x<-[0..20]]
{-
diedW::Widget
diedW =  [whamlet|
              <div #diedDate>
                Date:  ^{fvInput statusDateView}
              <div #diedNote>
                Notes: ^{fvInput statusNoteView}
          |]
-}
diedForm::Html -> MForm Handler (FormResult Died, Widget)
diedForm extra = do
    local_time <- liftIO $ getLocalTime
    let today = localDay local_time
    let stime = showtime (today)
    (statusDateRes, statusDateView) <- mreq textField " nope" (Just stime) 
    (statusNoteRes, statusNoteView) <- mreq textField "nope" Nothing
    let diedRes = Died <$> statusDateRes <*> statusNoteRes
    let diedw = do
          [whamlet|
              #{extra}
              <div #diedDate .blDate>
                Date:  ^{fvInput statusDateView}
              <div #diedNote>
                Notes: ^{fvInput statusNoteView}
             <input type=submit value="submit">
                        |]
          toWidget [lucius|
                ##{fvId statusNoteView} {
                      width:25em;
                 }
              |]
    return (diedRes, diedw)

getDiedR::RabbitId->Handler Html
getDiedR rabId= do
    Just rab <- runDB $ get rabId
    (formWidget, enctype) <- generateFormPost diedForm 
    let menu = [whamlet|
              <div #addCance style="float:inherit; text-align:left; margin:10px;">
                <b> Death Report for #{rabbitName rab}
                <div .cancelBut #rabEdCan style="display:inline; float:right;">
                   <a href=@{ViewR rabId}> cancel </a>
                |]
    let form = [whamlet|
                <form method=post action=@{DiedR rabId} enctype=#{enctype}>
                 ^{formWidget}
                 |]

    baseForm "Died" menu form
    
postDiedR::RabbitId->Handler Html
postDiedR rabId = do
  ((result, _), _) <-runFormPost diedForm 

  case result of
    FormSuccess died -> 
       runDB $ 
        update $ \p -> do
          set p [RabbitStatus =. val "Died", RabbitStatusDate =. val  (diedDate died),
                 RabbitStatusNote =. val (diedNotes died) ]
          where_ (p ^. RabbitId ==. val rabId)
          return ()
    _ -> return ()

  redirect (ViewR rabId)



rabbitForm ::(Maybe Rabbit, [Text])-> Html -> MForm Handler (FormResult Rabbit, Widget)
rabbitForm (mrab, names) extra = do
    local_time <- liftIO  getLocalTime
    let today = localDay local_time
    let stime = showtime today
    let tname = case mrab of 
          Nothing -> Nothing
          Just rb -> Just (rabbitName rb)
    let newrabbit= case mrab of
          Nothing->True
          Just _ ->False
    (nameRes, nameView) <- mreq textField "this is not used" tname
    (dateInRes, dateInView) <-mreq textField "nope" (testDateIn stime mrab)
    (descRes, descView) <- mreq textField "neither is this"  (test mrab rabbitDesc)
    (sourceRes, sourceView) <- mreq textField "neither is this" (test mrab rabbitSource)
    (sexRes, sexView) <- mreq (selectFieldList sex) "not" (test mrab rabbitSex)
    (alteredRes, alteredView) <- mreq (selectFieldList altered) "not" (test mrab rabbitAltered)
    (alteredDateRes, alteredDateView)<-mopt textField "this is not" (testAlteredDate mrab)
    (statusRes, statusView) <- mreq (selectFieldList status) "who" (test mrab rabbitStatus)
    (yrsIntakeRes, yrsIntakeView) <- mreq (selectFieldList years) "zip" (getYrsDateInM mrab)
    (mnthsIntakeRes, mnthsIntakeView) <- mreq (selectFieldList months) "zip" (getMonthsDateInM mrab)
    (sourceTypeRes, sourceTypeView) <- mreq (selectFieldList sourceType) "zip" (test mrab rabbitSourceType)
    (statusDateRes, statusDateView) <- mreq textField " nope" (testStatusDate stime  mrab)
    (statusNoteRes, statusNoteView) <- mreq textField "nope" (opttest mrab rabbitStatusNote)
    (imgNoteRes, imgNoteView)<- mopt textField "nopt" Nothing
    let yrdays = (365*) <$> yrsIntakeRes
    let mndays = (30*) <$> mnthsIntakeRes
    let daysTot = (+) <$> yrdays <*> mndays
    let daysTotNeg = ((-1)*) <$> daysTot
    let date = text2date dateInRes
    let bday =  addDays <$> daysTotNeg <*> date 
    let alteredDate = text2dateM alteredDateRes 
    let rabbitUpdateRes =Rabbit <$>  nameRes <*>  descRes <*> date <*> sourceTypeRes <*> sourceRes <*> sexRes <*> alteredRes <*> alteredDate <*> statusRes <*> statusDateRes <*> statusNoteRes <*> bday  <*> imgNoteRes
 --   let rabbitRes = rabbitRes1 <*> (FormResult (Just True)) <*> (FormResult Nothing) Nothing
    let awid= do
         $(widgetFileNoReload def "add")
         addScriptRemote "http://ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js"
         addStylesheetRemote "//code.jquery.com/ui/1.11.0/themes/smoothness/jquery-ui.css"
    return (rabbitUpdateRes, awid)


getAddR::Handler Html
getAddR = do
  names <- getNamesDB
  (formWidget, enctype) <- generateFormPost (rabbitForm (Nothing,names))
  let menu = 
           [whamlet|
              <div #addCance style="float:inherit; text-align:left; margin:10px;">
                <b> Add Rabbit
                <div .cancelBut #rabEdCan style="display:inline; float:right;">
                   <a href=@{HomeR}> cancel </a>
                   |]
  let form =   [whamlet|  <form method=post action=@{PostR} enctype=#{enctype}>
                 ^{formWidget}
                 |]
  baseForm "Add Rabbit" menu form

  

postPostR::Handler Html
postPostR = do
  ((result, _), _) <-runFormPost (rabbitForm (Nothing, []))
  link<- case result of
    FormSuccess  rabi -> 
     runDB $ do
        rabId<-insert  rabi
        return (ViewR rabId)
    _ -> return HomeR
  redirect link

-- update a rabbit 
postUpdateR::RabbitId->Handler Html
postUpdateR rabId = do
  ((result, _), _) <-runFormPost (rabbitForm (Nothing,[]))

  case result of
    FormSuccess rabi -> do
      runDB $ do
        _ <-replace  rabId rabi
        return ()
    _ -> return ()

  redirect (ViewR rabId)





getEditR::RabbitId->Handler Html
getEditR rabId  = do
    rabbit <-runDB  $  get rabId
    (formWidget, enctype) <- generateFormPost (rabbitForm (rabbit, []))
    let menu = [whamlet|
              <div #addCance style="float:inherit; text-align:left; margin:10px;">
                <b> Edit Rabbit
                <div .cancelBut #rabEdCan style="display:inline; float:right;">
                   <a href=@{ViewR rabId}> cancel </a>
               |]
    let form = [whamlet|
              <form method=post action=@{UpdateR rabId} enctype=#{enctype}>
                 ^{formWidget}
                 |]            
    baseForm "Edit Rabbit" menu form

addStoryForm::RabbitId->Html->MForm Handler (FormResult RabbitStory, Widget)
addStoryForm rId extra = do
  (storyRes, storyView)<-mreq textareaField "nope" Nothing
  let res = RabbitStory rId <$> storyRes
  let wid = do
        [whamlet| #{extra}
          <div #storyForm>
             <div .bllabel>
              Enter story/blurb :
             <div #story> ^{fvInput storyView}
            <input type="submit" value="save story">
        |]
        toWidget [lucius|
            ##{fvId storyView} {
                  width:98%;
             }
        |]
  return(res, wid)

getAddStoryR::RabbitId-> Handler Html
getAddStoryR rId = do
    (formWidget, enctype)<- generateFormPost (addStoryForm rId)
    Just rab <- runDB $ get rId
    let menu = [whamlet|
              <div #addCance style="float:inherit; text-align:left; margin:10px;">
                <b> Add Story for #{rabbitName rab}
                <div .cancelBut #rabEdCan style="display:inline; float:right;">
                   <a href=@{ViewR rId}> cancel </a>
               |]
    let form = [whamlet|
              <form method=post action=@{AddStoryR rId} enctype=#{enctype}>
                 ^{formWidget}
                 |]            
    baseForm "Edit Rabbit" menu form  

postAddStoryR::RabbitId->Handler Html
postAddStoryR rId = do
  ((result, _), _) <- runFormPost (addStoryForm rId)
  case result of
    FormSuccess story -> do
      runDB $ insert story
      redirect (ViewR rId)
    _ -> defaultLayout $ [whamlet| Form Error |]
