module AppActions where

import AppState
import Prelude

import AutoscrollSpeed (speedToIntervalMs, speedToIntervalPixelDelta)
import Cache as Cache
import Clipboard (copyToClipboard)
import Control.Monad.Cont (lift)
import Control.Monad.State (class MonadState, StateT(..), execStateT)
import Control.Monad.State as MonadState
import Data.Enum (pred, succ)
import Data.Maybe (Maybe(..))
import Effect.Aff.Class (class MonadAff, liftAff)
import Effect.Class (class MonadEffect, liftEffect)
import LocationString (getLocationString, getQueryParam)
import TablatureDocument (predTransposition, succTransposition)
import UrlShortener (createShortUrl)
import Control.Monad.State (class MonadState, StateT(..), execStateT, state)
import Control.Monad.State as MonadState
import Control.Monad.Trans.Class (class MonadTrans, lift)
import Data.Newtype (class Newtype)
import Halogen as H

-- newtype MyHaloT output m a = MyHaloT (H.HalogenM (State (MyStateT (MyHaloT output m))) Action () output (MyStateT (MyHaloT output m)) a)
newtype MyHaloT m a = MyHaloT (H.HalogenM (State (MyHaloT m)) Action () Unit m a)
             type MyHalo m a = H.HalogenM (State (MyHaloT m)) Action () Unit m a
unMyHaloT (MyHaloT m) = m
instance MonadTrans MyHaloT where
  -- lift :: Monad m => m a -> (MyHaloT output) m a
  lift ma = MyHaloT $ lift ma
derive instance Newtype (MyHaloT m a) _
derive instance Functor m => Functor (MyHaloT m)
derive newtype instance Monad m => Apply (MyHaloT m)
derive newtype instance Monad m => Applicative (MyHaloT m)
derive newtype instance Monad m => Bind (MyHaloT m)
derive newtype instance Monad m => Monad (MyHaloT m)
derive newtype instance MonadEffect m => MonadEffect (MyHaloT m)
derive newtype instance MonadAff m => MonadAff (MyHaloT m)
instance Monad m => MonadState (State (MyHaloT m)) (MyHaloT m) where
  -- state f = MyHaloT (H.HalogenM $ pure <<< f)
  -- state f = MyHaloT $ (H.HalogenM <<< liftF <<< H.State) f
  state f = MyHaloT $ state f

-- TODO: store scrollspeed somewhere
increaseAutoscrollSpeed :: forall m . Monad m => MyHaloT m Unit
increaseAutoscrollSpeed = do
  state <- getState
  case succ state.autoscrollSpeed of
    Nothing -> pure unit
    Just speed -> modifyState _ { autoscrollSpeed = speed }
  modifyState _ { autoscroll = true }

decreaseAutoscrollSpeed :: forall m . Monad m => MyHaloT m Unit
decreaseAutoscrollSpeed = do
  state <- getState
  case pred state.autoscrollSpeed of
    Nothing -> pure unit
    Just speed -> modifyState _ { autoscrollSpeed = speed }
  modifyState _ { autoscroll = true }

initialize  :: forall m . Monad m => MyHaloT m Unit
initialize = do
  tablatureText <- Cache.read _tablatureText
  if tablatureText == ""
  then modifyState _ { mode = EditMode }
  else modifyState _ { mode = ViewMode }

toggleEditMode  :: forall m . Monad m => MyHaloT m Unit
toggleEditMode = do
  state <- getState
  case state.mode of
    EditMode -> do
      -- FIXNOW
      -- tablatureText <- lift getTablatureTextFromEditor
      -- Cache.write _tablatureText tablatureText
      modifyState _ { mode = ViewMode }
      -- lift focusTablatureContainer
    ViewMode -> do
      modifyState _ { mode = EditMode }
      tablatureText <- Cache.read _tablatureText
      pure unit
      -- lift $ setTablatureTextInEditor tablatureText
      -- Don't focus the textarea, as the cursor position will be put at the end (which also sometimes makes the window jump)

toggleTabNormalization  :: forall m . Monad m => MyHaloT m Unit
toggleTabNormalization = do
  tabNormalizationEnabled <- Cache.read _tabNormalizationEnabled
  Cache.write _tabNormalizationEnabled (not tabNormalizationEnabled)

toggleTabDozenalization  :: forall m . Monad m => MyHaloT m Unit
toggleTabDozenalization = do
  ignoreDozenalization <- Cache.read _ignoreDozenalization
  if ignoreDozenalization
  then pure unit
  else do
    tabDozenalizationEnabled <- Cache.read _tabDozenalizationEnabled
    Cache.write _tabDozenalizationEnabled (not tabDozenalizationEnabled)

toggleChordDozenalization  :: forall m . Monad m => MyHaloT m Unit
toggleChordDozenalization = do
  ignoreDozenalization <- Cache.read _ignoreDozenalization
  if ignoreDozenalization
  then pure unit
  else do
    chordDozenalizationEnabled <- Cache.read _chordDozenalizationEnabled
    Cache.write _chordDozenalizationEnabled (not chordDozenalizationEnabled)

copyShortUrl  :: forall m . MonadAff m => MyHaloT m Unit
copyShortUrl = do
  longUrl <- liftEffect getLocationString
  maybeShortUrl <- liftAff $ createShortUrl longUrl
  liftEffect $ case maybeShortUrl of
    Just shortUrl -> copyToClipboard shortUrl
    Nothing -> pure unit

increaseTransposition  :: forall m . Monad m => MyHaloT m Unit
increaseTransposition = do
  transposition <- Cache.read _transposition
  Cache.write _transposition $ succTransposition transposition

decreaseTransposition  :: forall m . Monad m => MyHaloT m Unit
decreaseTransposition = do
  transposition <- Cache.read _transposition
  Cache.write _transposition $ predTransposition transposition
