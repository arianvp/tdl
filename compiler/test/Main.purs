module Test.Main
  ( main
  ) where

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Data.Either (Either(..))
import Data.List ((:), List(Nil))
import Data.Tuple.Nested ((/\))
import Prelude
import Test.Assert (ASSERT, assert)
import TDL.Check (inferKind, inferModule, runCheck)
import TDL.Extraction.PureScript (pursModule, pursSerialize, pursTypeName)
import TDL.Syntax (Declaration(..), Doc(..), Kind(..), Module(..), PrimType(..), Type(..))

main :: forall eff. Eff (assert :: ASSERT, console :: CONSOLE | eff) Unit
main = do
  testKind (PrimType I32Type) SeriKind
  testKind (ProductType []) SeriKind
  testKind (ProductType ["x" /\ (PrimType I32Type), "y" /\ (PrimType I32Type)]) SeriKind
  testKind (SumType []) SeriKind
  testKind (SumType ["x" /\ (PrimType I32Type), "y" /\ (PrimType I32Type)]) SeriKind

  testModule $ Nil
  testModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type) : Nil
  testModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type)
             : TypeDeclaration "U" (Doc "") SeriKind (NamedType "T")
             : Nil

  exampleType $ PrimType I32Type
  exampleType $ ProductType []
  exampleType $ ProductType ["x" /\ (PrimType I32Type)]
  exampleType $ ProductType ["x" /\ (PrimType I32Type), "y" /\ ProductType []]

  exampleModule $ Nil
  exampleModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type) : Nil
  exampleModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type)
                : TypeDeclaration "U" (Doc "") SeriKind (NamedType "T")
                : Nil
  exampleModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type)
                : TypeDeclaration "U" (Doc "") SeriKind (ProductType ["x" /\ (PrimType I32Type), "y" /\ NamedType "T"])
                : Nil
  exampleModule $ TypeDeclaration "T" (Doc "") SeriKind (PrimType I32Type)
                : TypeDeclaration "U" (Doc "") SeriKind (SumType ["x" /\ (PrimType I32Type), "y" /\ ProductType []])
                : Nil

  where
    testKind t k = assert $ runCheck (inferKind t) == Right k
    testModule m = assert $ runCheck (inferModule (Module "M" (Doc "") m)) == Right unit
    exampleType t = do
      log $ pursTypeName t
      log $ pursSerialize t
    exampleModule m = log $ pursModule (Module "M" (Doc "") m)
