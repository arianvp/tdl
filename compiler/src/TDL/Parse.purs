module TDL.Parse
  ( parse
  ) where

import Control.Alternative ((<|>))
import Control.MonadZero (guard)
import Data.Array as Array
import Data.Either (Either)
import Data.Foldable (foldl, foldr)
import Data.List ((:), List(Nil))
import Data.String as String
import Data.Tuple.Nested ((/\))
import Prelude
import TDL.Syntax (Declaration(..), Kind(..), Module, PrimType(..), Type(..))
import Text.Parsing.StringParser (ParseError, Parser, runParser)
import Text.Parsing.StringParser as P
import Text.Parsing.StringParser.Combinators as PC
import Text.Parsing.StringParser.String as PS

--------------------------------------------------------------------------------

parse :: String -> Either ParseError Module
parse = runParser module_

--------------------------------------------------------------------------------

kind_ :: Parser Kind
kind_ = pure unit >>= \_ -> kind' unit

kind' :: Unit -> Parser Kind
kind' _ = do
  head <-     (SeriKind <$ asteriskPunc)
          <|> (leftParenPunc *> kind_ <* rightParenPunc)
  foldr ArrowKind head <$> PC.many (rightArrowPunc *> kind_)

type_ :: Parser Type
type_ = pure unit >>= \_ -> type' unit

type' :: Unit -> Parser Type
type' _ = application
  where
    application = foldl AppliedType <$> simple <*> PC.many simple

    simple =     P.try (NamedType <$> identifier)
             <|>       keywordType
             <|>       compoundType productKeyword ProductType
             <|>       compoundType sumKeyword     SumType
             <|>       (leftParenPunc *> type_ <* rightParenPunc)

    keywordType =     (PrimType ArrayType <$ arrayKeyword)
                  <|> (PrimType I32Type   <$ i32Keyword)
                  <|> (PrimType F64Type   <$ f64Keyword)
                  <|> (PrimType TextType  <$ textKeyword)

    compoundType kw c = kw *> leftBracePunc *> (c <$> fields) <* rightBracePunc
    fields = Array.fromFoldable <$> field `PC.sepEndBy` commaPunc
    field  = P.try $ (/\) <$> identifier <*> (colonPunc *> type_)

--------------------------------------------------------------------------------

module_ :: Parser Module
module_ = PC.many declaration <* PS.eof

declaration :: Parser Declaration
declaration = do
  typeKeyword
  name <- identifier
  colonPunc
  typeKind <- kind_
  equalsSignPunc
  original <- type_
  semicolonPunc
  pure $ TypeDeclaration name typeKind original

--------------------------------------------------------------------------------

lexeme :: forall a. Parser a -> Parser a
lexeme p = blank *> p <* blank
  where blank   = PS.whiteSpace *> PC.many (comment *> PS.whiteSpace)
        comment = void $ PS.string "/*" *> PS.anyChar `PC.manyTill` PS.string "*/"

identifier :: Parser String
identifier = lexeme do
  name <- String.fromCharArray <<< Array.fromFoldable <$> PC.many1 PS.alphaNum
  guard (name `Array.notElem` ["array", "f64", "i32", "product", "sum", "text", "type"])
  pure name

arrayKeyword :: Parser Unit
arrayKeyword = void $ lexeme $ PS.string "array"

f64Keyword :: Parser Unit
f64Keyword = void $ lexeme $ PS.string "f64"

i32Keyword :: Parser Unit
i32Keyword = void $ lexeme $ PS.string "i32"

productKeyword :: Parser Unit
productKeyword = void $ lexeme $ PS.string "product"

sumKeyword :: Parser Unit
sumKeyword = void $ lexeme $ PS.string "sum"

textKeyword :: Parser Unit
textKeyword = void $ lexeme $ PS.string "text"

typeKeyword :: Parser Unit
typeKeyword = void $ lexeme $ PS.string "type"

asteriskPunc :: Parser Unit
asteriskPunc = void $ lexeme $ PS.char '*'

commaPunc :: Parser Unit
commaPunc = void $ lexeme $ PS.char ','

colonPunc :: Parser Unit
colonPunc = void $ lexeme $ PS.char ':'

equalsSignPunc :: Parser Unit
equalsSignPunc = void $ lexeme $ PS.char '='

leftBracePunc :: Parser Unit
leftBracePunc = void $ lexeme $ PS.char '{'

leftParenPunc :: Parser Unit
leftParenPunc = void $ lexeme $ PS.char '('

rightArrowPunc :: Parser Unit
rightArrowPunc = void $ lexeme $ PS.string "->"

rightBracePunc :: Parser Unit
rightBracePunc = void $ lexeme $ PS.char '}'

rightParenPunc :: Parser Unit
rightParenPunc = void $ lexeme $ PS.char ')'

semicolonPunc :: Parser Unit
semicolonPunc = void $ lexeme $ PS.char ';'
