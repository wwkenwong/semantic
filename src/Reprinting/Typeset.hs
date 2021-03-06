module Reprinting.Typeset
  ( typesetting
  , typesettingWithVisualWhitespace
  ) where

import Prologue

import Streaming
import qualified Streaming.Prelude as Streaming
import Data.Reprinting.Splice hiding (space)
import Data.Text.Prettyprint.Doc

typesetting :: Monad m => Stream (Of Splice) m x
                       -> Stream (Of (Doc a)) m x
typesetting = Streaming.map step

step :: Splice -> Doc a
step (Emit t)                   = pretty t
step (Layout SoftWrap)          = softline
step (Layout HardWrap)          = hardline
step (Layout Space)             = space
step (Layout (Indent 0 Spaces)) = mempty
step (Layout (Indent n Spaces)) = stimes n space
step (Layout (Indent 0 Tabs))   = mempty
step (Layout (Indent n Tabs))   = stimes n "\t"

-- | Typeset, but show whitespace with printable characters for debugging purposes.
typesettingWithVisualWhitespace :: Monad m
                                => Stream (Of Splice) m x
                                -> Stream (Of (Doc a)) m x
typesettingWithVisualWhitespace = Streaming.map step where
  step :: Splice -> Doc a
  step (Emit t)                   = pretty t
  step (Layout SoftWrap)          = softline
  step (Layout HardWrap)          = "\\n" <> hardline
  step (Layout Space)             = "."
  step (Layout (Indent 0 Spaces)) = mempty
  step (Layout (Indent n Spaces)) = stimes n "."
  step (Layout (Indent 0 Tabs))   = mempty
  step (Layout (Indent n Tabs))   = stimes n "\t"
