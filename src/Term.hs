{-# LANGUAGE DataKinds, MultiParamTypeClasses, RankNTypes, TypeFamilies, TypeOperators #-}
module Term
( Term(..)
, TermF(..)
, SyntaxTerm
, SyntaxTermF
, termSize
, extract
, unwrap
, hoistTerm
, stripTerm
, liftPrettyUnion
) where

import Control.Comonad
import Control.Comonad.Cofree.Class
import Data.Aeson
import Data.Bifoldable
import Data.Bifunctor
import Data.Bitraversable
import Data.Functor.Classes
import Data.Functor.Classes.Pretty.Generic as Pretty
import Data.Functor.Foldable
import Data.JSON.Fields
import Data.Proxy
import Data.Record
import Data.Union
import Syntax
import Text.Show

-- | A Term with an abstract syntax tree and an annotation.
newtype Term syntax ann = Term { unTerm :: TermF syntax ann (Term syntax ann) }

infixr 5 :<
data TermF syntax ann recur = (:<) { termAnnotation :: ann, termSyntax :: syntax recur }
  deriving (Eq, Foldable, Functor, Show, Traversable)

-- | A Term with a Syntax leaf and a record of fields.
type SyntaxTerm fields = Term Syntax (Record fields)
type SyntaxTermF fields = TermF Syntax (Record fields)

-- | Return the node count of a term.
termSize :: (Foldable f, Functor f) => Term f annotation -> Int
termSize = cata size where
  size (_ :< syntax) = 1 + sum syntax


hoistTerm :: Functor f => (forall a. f a -> g a) -> Term f a -> Term g a
hoistTerm f = go where go (Term (a :< r)) = Term (a :< f (fmap go r))

-- | Strips the head annotation off a term annotated with non-empty records.
stripTerm :: Functor f => Term f (Record (h ': t)) -> Term f (Record t)
stripTerm = fmap rtail


liftPrettyUnion :: Apply1 Pretty1 fs => (a -> Doc ann) -> ([a] -> Doc ann) -> Union fs a -> Doc ann
liftPrettyUnion p pl = apply1 (Proxy :: Proxy Pretty1) (liftPretty p pl)


instance Apply1 Pretty1 fs => Pretty1 (Term (Union fs)) where
  liftPretty p pl = go where go = liftPretty2 p pl go (Pretty.list . map go) . unTerm

instance (Apply1 Pretty1 fs, Pretty a) => Pretty (Term (Union fs) a) where
  pretty = liftPretty pretty prettyList

type instance Base (Term f a) = TermF f a

instance Functor f => Recursive (Term f a) where project = unTerm
instance Functor f => Corecursive (Term f a) where embed = Term

instance Functor f => Comonad (Term f) where
  extract (Term (a :< _)) = a
  duplicate w = Term (w :< fmap duplicate (unwrap w))
  extend f = go where go w = Term (f w :< fmap go (unwrap w))

instance Functor f => Functor (Term f) where
  fmap f = go where go = Term . bimap f go . unTerm

instance Foldable f => Foldable (Term f) where
  foldMap f = go where go = bifoldMap f go . unTerm

instance Traversable f => Traversable (Term f) where
  traverse f = go where go = fmap Term . bitraverse f go . unTerm

instance Functor f => ComonadCofree f (Term f) where
  unwrap (Term (_ :< as)) = as
  {-# INLINE unwrap #-}

instance Eq1 f => Eq1 (Term f) where
  liftEq eqA = go where go t1 t2 = liftEq2 eqA go (unTerm t1) (unTerm t2)

instance (Eq1 f, Eq a) => Eq (Term f a) where
  (==) = eq1

instance Show1 f => Show1 (Term f) where
  liftShowsPrec spA slA = go where go d = showsUnaryWith (liftShowsPrec2 spA slA go (showListWith (go 0))) "Term" d . unTerm

instance (Show1 f, Show a) => Show (Term f a) where
  showsPrec = showsPrec1

instance Functor f => Bifunctor (TermF f) where
  bimap f g (a :< r) = f a :< fmap g r

instance Foldable f => Bifoldable (TermF f) where
  bifoldMap f g (a :< r) = f a `mappend` foldMap g r

instance Traversable f => Bitraversable (TermF f) where
  bitraverse f g (a :< r) = (:<) <$> f a <*> traverse g r


instance Eq1 f => Eq2 (TermF f) where
  liftEq2 eqA eqB (a1 :< f1) (a2 :< f2) = eqA a1 a2 && liftEq eqB f1 f2

instance (Eq1 f, Eq a) => Eq1 (TermF f a) where
  liftEq = liftEq2 (==)

instance Show1 f => Show2 (TermF f) where
  liftShowsPrec2 spA _ spB slB d (a :< f) = showParen (d > 5) $ spA 6 a . showString " :< " . liftShowsPrec spB slB 5 f

instance (Show1 f, Show a) => Show1 (TermF f a) where
  liftShowsPrec = liftShowsPrec2 showsPrec showList


instance Apply1 Pretty1 fs => Pretty2 (TermF (Union fs)) where
  liftPretty2 pA _ pB plB (a :< f) = pA a <+> liftPrettyUnion pB plB f

instance (Apply1 Pretty1 fs, Pretty a) => Pretty1 (TermF (Union fs) a) where
  liftPretty = liftPretty2 pretty prettyList

instance (Apply1 Pretty1 fs, Pretty a, Pretty b) => Pretty (TermF (Union fs) a b) where
  pretty = liftPretty pretty prettyList


instance (ToJSONFields a, ToJSONFields1 f) => ToJSON (Term f a) where
  toJSON = object . toJSONFields
  toEncoding = pairs . mconcat . toJSONFields

instance (ToJSONFields a, ToJSONFields1 f) => ToJSONFields (Term f a) where
  toJSONFields = toJSONFields . unTerm

instance (ToJSON b, ToJSONFields a, ToJSONFields1 f) => ToJSONFields (TermF f a b) where
  toJSONFields (a :< f) = toJSONFields a <> toJSONFields1 f
