{-# LANGUAGE TypeFamilies #-}
module Generators
  ( source
  ) where

import Hedgehog
import qualified Hedgehog.Gen as Gen
import qualified Data.Source
import Data.Functor.Identity

source :: (GenBase m ~ Identity, MonadGen m) => Hedgehog.Range Int -> m Data.Source.Source
source r = Gen.frequency [ (1, empty), (20, nonEmpty) ]
  where empty    = pure mempty
        nonEmpty = Data.Source.fromUTF8 <$> Gen.utf8 r (Gen.frequency [ (1, pure '\r'), (1, pure '\n'), (20, Gen.unicode) ])
