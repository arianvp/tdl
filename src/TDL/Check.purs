module TDL.Check
  ( Check
  , Environment
  , Error(..)
  , runCheck

  , inferKind

  , inferModule
  , inferDeclaration
  ) where

import Control.Monad.Error.Class (throwError)
import Control.Monad.Except (Except, runExcept)
import Control.Monad.Reader.Class as Reader
import Control.Monad.Reader.Trans (ReaderT, runReaderT)
import Data.Either (Either)
import Data.Foldable (foldMap)
import Data.List ((:), List(Nil))
import Data.Map (Map)
import Data.Map as Map
import Data.Maybe (maybe)
import Data.Newtype (ala)
import Data.Traversable (traverse)
import Data.Tuple (snd)
import Prelude
import TDL.Syntax (Declaration(..), Kind(..), KindLUB(..), Module, Type(..))

--------------------------------------------------------------------------------

type Check = ReaderT Environment (Except Error)

type Environment = Map String Kind

data Error
  = NameError String

derive instance eqError :: Eq Error

runCheck :: forall a. Check a -> Either Error a
runCheck m = runExcept (runReaderT m Map.empty)

--------------------------------------------------------------------------------

inferKind :: Type -> Check Kind
inferKind (NamedType n) =
  Reader.asks (Map.lookup n)
  >>= maybe (throwError (NameError n)) pure
inferKind IntType = pure SeriKind
inferKind (ProductType ts) = ala KindLUB foldMap <$> traverse (inferKind <<< snd) ts
inferKind (SumType     ts) = ala KindLUB foldMap <$> traverse (inferKind <<< snd) ts
inferKind (FuncType a b) = TypeKind <$ inferKind a <* inferKind b

--------------------------------------------------------------------------------

inferModule :: Module -> Check Unit
inferModule Nil = pure unit
inferModule (d : ds) = do
  mappings <- inferDeclaration d
  Reader.local (Map.union mappings) $
    inferModule ds

inferDeclaration :: Declaration -> Check Environment
inferDeclaration (TypeDeclaration n t) =
  Map.singleton n <$> inferKind t
