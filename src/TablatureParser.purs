module TablatureParser where

import Prelude hiding (between)

import AppState (ChordLineElem(..), HeaderLineElem(..), TablatureDocument, TablatureDocumentLine(..), TablatureLineElem(..), TextLineElem(..), TitleLineElem(..))
import Control.Alt ((<|>))
import Data.Either (Either(..))
import Data.List (List(..), (:))
import Data.Maybe (Maybe(..))
import Data.String (drop)
import Effect.Console as Console
import Effect.Unsafe (unsafePerformEffect)
import Text.Parsing.StringParser (Parser, try, unParser)
import Text.Parsing.StringParser.CodePoints (eof, regex)
import Text.Parsing.StringParser.Combinators (lookAhead, many, manyTill, option)


parseTablatureDocument :: Boolean -> Parser TablatureDocument
parseTablatureDocument dozenalize = do
  commentLinesBeforeTitle <- option Nil $ (try $ manyTill parseTextLine (try $ lookAhead (parseTitleLine <|> parseTablatureLine dozenalize)))
  title <- option Nil $ (try parseTitleLine) <#> \result -> result:Nil
  body <- many $ (try $ parseTablatureLine dozenalize) <|> (try parseChordLine) <|> (try parseHeaderLine) <|> parseTextLine
  pure $ commentLinesBeforeTitle <> title <> body

parseTitleLine :: Parser TablatureDocumentLine
parseTitleLine = do
  p <- regex """[^\w\n\r]*"""
  t <- regex """[^\n\r]*[\w)!?"']"""
  s <- regex """[^\n\r]*""" <* parseEndOfLine
  pure $ TitleLine $ TitleOther p : Title t : TitleOther s : Nil

digitsRegex :: Boolean -> String
digitsRegex dozenalize = if dozenalize then """\d""" else """\d↊↋"""

parseTablatureLine :: Boolean -> Parser TablatureDocumentLine
parseTablatureLine dozenalize = do
  p <- regex """[^|\n\r]*""" <#> \result -> Prefix result
  t <- try $ lookAhead (regex """\|\|?""") *> many
    (
      (regex """((-(?!\|)|(-?\|\|?(?=[^\s\-|]*[\-|]))))+""" <#> \result -> Timeline result) <|>
      (regex ("[" <> digitsRegex dozenalize <> "]+") <#> \result -> Fret result) <|>
      (regex ("""[^\s|\-""" <> digitsRegex dozenalize <> "]+") <#> \result -> Special result)
    )
  tClose <- regex """-?\|?\|?""" <#> \result -> Timeline result
  s <- regex """[^\n\r]*""" <* parseEndOfLine <#> \result -> Suffix result
  pure $ TablatureLine (p:Nil <> t <> tClose:Nil <> s:Nil)

parseHeaderLine :: Parser TablatureDocumentLine
parseHeaderLine = do
  h <- regex """[ \t]*\[[^\n\r]+\]"""
  s <- regex """[^\r\n]*""" <* parseEndOfLine
  pure $ HeaderLine ((Header h):(HeaderSuffix s):Nil)

parseChordLine :: Parser TablatureDocumentLine
parseChordLine = (many parseChordComment <> (parseChord <#> \c -> c:Nil) <> many (parseChord <|> parseChordComment) <* parseEndOfLine) <#> \result -> ChordLine result

parseChord :: Parser ChordLineElem
parseChord = regex """[ \t]*[ABCDEFG][#b]*[\w-+#()/]*[ \t]*""" <#> \result -> Chord result

parseChordComment :: Parser ChordLineElem
parseChordComment = regex """[ \t]*\([^\n\r()]*\)[ \t]*""" <#> \result -> ChordComment result

parseTextLine :: Parser TablatureDocumentLine
parseTextLine = (regex """[^\n\r]+""" <* parseEndOfLine) <|> (parseEndOfLineString *> pure "") <#> \result -> TextLine ((Text result):Nil)

-- | We are as flexible as possible when it comes to line endings.
-- | Any of the following forms are considered valid: \n \r \n\r eof.
parseEndOfLine :: Parser Unit
parseEndOfLine = parseEndOfLineString *> pure unit <|> eof

parseEndOfLineString :: Parser String
parseEndOfLineString = regex """\n\r?|\r""" 

tryParseTablature :: Boolean -> String -> Maybe (List TablatureDocumentLine)
tryParseTablature dozenalize inputString = tryRunParser (parseTablatureDocument dozenalize) inputString

tryRunParser :: forall a. Show a => Parser a -> String -> Maybe a
tryRunParser parser inputString = 
  case unParser (parser <* eof) { str: inputString, pos: 0 } of
    Left rec -> Console.error msg # unsafePerformEffect # \_ -> Nothing
      where
      msg = "Position: " <> show rec.pos
        <> "\nError: " <> show rec.error
        <> "\nIn input string: " <> inputString
        <> "\nWith unparsed suffix: " <> (show $ drop rec.pos inputString)
    Right rec -> do
      pure rec.result
