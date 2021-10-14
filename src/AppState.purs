module AppState where

import Prelude

import Data.List (List)
import Data.Maybe (Maybe)
import Effect.Timer (IntervalId)

import Data.Enum (class Enum)
import Data.Enum.Generic (genericPred, genericSucc)
import Data.Generic.Rep (class Generic)

data Action
  = Initialize 
  | ToggleEditMode 
  | ToggleTabNormalization 
  | ToggleTabDozenalization 
  | ToggleChordDozenalization 
  | CopyShortUrl
  | ToggleAutoscroll
  | IncreaseAutoscrollSpeed
  | DecreaseAutoscrollSpeed

instance showMode :: Show Mode where
  show ViewMode = "View Mode"
  show EditMode = "Edit Mode"

data Mode = ViewMode | EditMode

data AutoscrollSpeed
  = Speed1
  | Speed2

instance showAutoscrollSpeed :: Show AutoscrollSpeed where
  show Speed1 = "(x1)"
  show Speed2 = "(x2)"

derive instance eqAutoscrollSpeed :: Eq AutoscrollSpeed
derive instance ordAutoscrollSpeed :: Ord AutoscrollSpeed
derive instance genericAutoscrollSpeed :: Generic AutoscrollSpeed _
instance enumAutoscrollSpeed :: Enum AutoscrollSpeed where
  succ = genericSucc
  pred = genericPred

speedToIntervalMs :: AutoscrollSpeed -> Int
speedToIntervalMs Speed1 = 100
speedToIntervalMs Speed2 = 50

type State =
  { mode :: Mode
  , loading :: Boolean
  , tablatureText :: String
  , tablatureTitle :: String
  , tablatureDocument :: Maybe TablatureDocument
  -- Store the scrollTop in the state before actions so we can restore the expected scrollTop when switching views
  , scrollTop :: Number
  , autoscrollTimer :: Maybe IntervalId
  , autoscrollSpeed :: AutoscrollSpeed
  , autoscroll :: Boolean
  , tabNormalizationEnabled :: Boolean
  , tabDozenalizationEnabled :: Boolean
  , chordDozenalizationEnabled :: Boolean
  -- For tabs that are already dozenal themselves we want to ignore any dozenalization settings
  , ignoreDozenalization :: Boolean
  }

type RenderingOptions =
  { dozenalizeTabs :: Boolean
  , dozenalizeChords :: Boolean
  , normalizeTabs :: Boolean
  }

type TablatureDocument = List TablatureDocumentLine

data TablatureDocumentLine
  = TitleLine (List TitleLineElem) -- Title of whole document
  | HeaderLine (List HeaderLineElem) -- Header per section of document
  | TablatureLine (List TablatureLineElem)
  | ChordLine (List ChordLineElem)
  | TextLine (List TextLineElem)

data TitleLineElem
  = Title String
  | TitleOther String

data HeaderLineElem
  = Header String
  | HeaderSuffix String

data TablatureLineElem
  = Prefix String
  | Suffix String
  | Timeline String
  | Fret String
  | Special String

data TextLineElem
  = Text String
  | Spaces String
  | TextLineChord Chord
  | ChordLegend (List ChordLegendElem)

data ChordLegendElem
  = ChordFret String
  | ChordSpecial String

data ChordLineElem
  = ChordLineChord Chord
  | ChordComment String

type Chord =
  { root :: Note
  , type :: String
  , mods :: List ChordMod
  , bass :: Note
  }

newtype ChordMod = ChordMod
  { pre :: String
  , interval :: String
  , post :: String
  }

type Note =
  { letter :: String
  , mod :: String
  }

instance showLine :: Show TablatureDocumentLine where
  show (TitleLine elems) = "Title: " <> show elems
  show (TablatureLine elems) = "Tab: " <> show elems
  show (TextLine elems) = "Text: " <> show elems
  show (ChordLine elems) = "Chords: " <> show elems
  show (HeaderLine elems) = "Header: " <> show elems

instance showTablatureLineElem :: Show TablatureLineElem where
  show (Prefix string) = string
  show (Suffix string) = string
  show (Timeline string) = string
  show (Fret string) = string
  show (Special string) = string

instance showTextLineElem :: Show TextLineElem where
  show (Text string) = string
  show (Spaces string) = string
  show (TextLineChord chord) = show chord
  show (ChordLegend _) = "legend"

instance showChordLineElem :: Show ChordLineElem where
  show (ChordLineChord chord) = show chord
  show (ChordComment string) = string

instance showChordMod :: Show ChordMod where
  show (ChordMod x) = x.pre <> x.interval <> x.post

instance showHeaderLineElem :: Show HeaderLineElem where
  show (Header string) = string
  show (HeaderSuffix string) = string

instance showTitleLineElem :: Show TitleLineElem where
  show (Title string) = string
  show (TitleOther string) = string

